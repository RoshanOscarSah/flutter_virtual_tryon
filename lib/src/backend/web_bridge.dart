// INTERNAL — not exported, web-only (dart:js_interop). Loads and calls the
// MediaPipe Face Landmarker running in-browser.
//
// Unlike Kalo Chasma's own web/index.html snippet (see doc/HANDOVER.md),
// this package injects its bridge script itself at runtime instead of
// requiring consumers to hand-edit index.html — see doc/DECISIONS.md #021
// for why. The bridge is loaded once per page (guarded by a global check)
// and returns raw, normalized face-mesh landmarks; all the "which index
// means what" math lives in Dart (media_pipe_conversion.dart) where it's
// unit-testable, not duplicated in JS.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// Pinned to the same MediaPipe Tasks Vision version and model proven in
// production by Kalo Chasma's own Vision Mirror feature.
const _bridgeSource = '''
import { FaceLandmarker, FilesetResolver } from "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/vision_bundle.mjs";

let landmarkerPromise = null;

function createLandmarker() {
  return FilesetResolver.forVisionTasks(
    "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm"
  ).then((files) =>
    FaceLandmarker.createFromOptions(files, {
      baseOptions: {
        modelAssetPath:
          "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task",
        delegate: "GPU",
      },
      outputFaceBlendshapes: false,
      runningMode: "IMAGE",
      numFaces: 1,
    })
  );
}

async function init() {
  try {
    if (!landmarkerPromise) landmarkerPromise = createLandmarker();
    await landmarkerPromise;
    return true;
  } catch (e) {
    console.warn("flutter_virtual_tryon: MediaPipe failed to load", e);
    landmarkerPromise = null;
    return false;
  }
}

async function detect(blobUrl) {
  try {
    if (!landmarkerPromise) landmarkerPromise = createLandmarker();
    const detector = await landmarkerPromise;
    const img = await new Promise((resolve, reject) => {
      const el = new Image();
      el.onload = () => resolve(el);
      el.onerror = reject;
      el.src = blobUrl;
    });
    const result = detector.detect(img);
    if (!result || !result.faceLandmarks || result.faceLandmarks.length === 0) {
      return null;
    }
    const points = result.faceLandmarks[0];
    const flat = new Array(points.length * 2);
    for (let i = 0; i < points.length; i++) {
      flat[i * 2] = points[i].x;
      flat[i * 2 + 1] = points[i].y;
    }
    return flat;
  } catch (e) {
    console.warn("flutter_virtual_tryon: detect failed", e);
    return null;
  }
}

window.__flutterVirtualTryonBridge = { init, detect };
''';

@JS('__flutterVirtualTryonBridge')
external _Bridge? get _bridgeGlobal;

extension type _Bridge._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> init();
  external JSPromise<JSArray<JSNumber>?> detect(JSString blobUrl);
}

Future<void>? _injection;

/// Injects the bridge script into the page if it isn't already there.
/// Safe to call repeatedly and from multiple [MediaPipeVisionBackendEngine]
/// instances — the work happens at most once per page load.
Future<void> ensureWebBridgeLoaded() {
  if (_bridgeGlobal != null) return Future.value();
  return _injection ??= _inject();
}

Future<void> _inject() {
  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..type = 'module'
    ..textContent = _bridgeSource;
  script.addEventListener(
    'load',
    (web.Event event) {
      if (!completer.isCompleted) completer.complete();
    }.toJS,
  );
  script.addEventListener(
    'error',
    (web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('failed to load MediaPipe bridge script'));
      }
    }.toJS,
  );
  web.document.head!.append(script);
  return completer.future;
}

/// Calls the bridge's `init()`, loading the MediaPipe model. Returns false
/// if loading failed (network error, unsupported browser, ...).
Future<bool> webBridgeInit() async {
  await ensureWebBridgeLoaded();
  final bridge = _bridgeGlobal;
  if (bridge == null) return false;
  final ok = await bridge.init().toDart;
  return ok.toDart;
}

/// Runs detection against an image blob and returns its raw, normalized
/// face-mesh landmarks as a flat `[x0, y0, x1, y1, ...]` list — see
/// `media_pipe_conversion.dart` for what the indices mean. Null when no
/// face was found or the bridge isn't ready.
Future<List<double>?> webBridgeDetect(Uint8List imageBytes) async {
  final bridge = _bridgeGlobal;
  if (bridge == null) return null;

  final blob = web.Blob(
    [imageBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/jpeg'),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    final result = await bridge.detect(url.toJS).toDart;
    if (result == null) return null;
    final list = result.toDart;
    return [for (final n in list) n.toDartDouble];
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
