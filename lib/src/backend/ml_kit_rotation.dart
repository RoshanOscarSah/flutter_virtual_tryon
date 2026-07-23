// INTERNAL — not exported. CameraImage -> InputImage and raw-sensor ->
// upright coordinate rotation for the live ML Kit stream path.
//
// This follows Google's own documented recipe for the Android/iOS camera
// rotation-compensation dance (the same pattern used across every
// google_mlkit_face_detection example project) rather than improvising one,
// since getting the sign/axis wrong here is the single easiest way to place
// overlays in the wrong spot on some devices. Ported verbatim from the
// proven implementation in Kalo Chasma (see doc/HANDOVER.md).

import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

const _orientations = <DeviceOrientation, int>{
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Computes the [InputImageRotation] ML Kit needs to interpret one raw
/// camera frame correctly. Returns null for an orientation this recipe
/// can't handle (Android only — an unknown [deviceOrientation]).
///
/// Follows Google's own documented recipe exactly, which is deliberately
/// *asymmetric* by platform — not a bug, a real platform difference:
///
///  - **iOS**: the `camera` plugin delivers frames already rotated to the
///    display orientation, so the fixed [sensorOrientation] alone tells ML
///    Kit which way is up. (A consequence, handled in ml_kit_conversion.dart:
///    iOS detections come back *already upright*, so they must NOT be run
///    through [mlKitUprightPoint].)
///  - **Android**: frames arrive in the raw sensor buffer orientation, so
///    the rotation combines [sensorOrientation] with the device's current
///    [deviceOrientation] (sign depending on front/back lens), and the
///    returned coordinates are in raw buffer space (rotated upright by
///    [mlKitUprightPoint]).
///
/// Pulled out as a pure function (no [CameraImage]/[CameraController]) so
/// it's unit-testable without a real camera.
@visibleForTesting
InputImageRotation? mlKitRotationForCamera({
  required TargetPlatform platform,
  required int sensorOrientation,
  required CameraLensDirection lensDirection,
  required DeviceOrientation? deviceOrientation,
}) {
  if (platform == TargetPlatform.iOS) {
    return InputImageRotationValue.fromRawValue(sensorOrientation);
  }
  final rotationCompensation = _orientations[deviceOrientation];
  if (rotationCompensation == null) return null;
  final combined = lensDirection == CameraLensDirection.front
      ? (sensorOrientation + rotationCompensation) % 360
      : (sensorOrientation - rotationCompensation + 360) % 360;
  return InputImageRotationValue.fromRawValue(combined);
}

/// Builds an [InputImage] from one raw camera frame, computing the rotation
/// ML Kit needs to interpret sensor-space pixels correctly. Returns null for
/// a frame this recipe can't handle (unknown device orientation, multi-plane
/// format) — callers should skip that frame, not throw.
InputImage? mlKitInputImageFromCameraImage(
  CameraImage image,
  CameraController controller,
) {
  final camera = controller.description;
  final rotation = mlKitRotationForCamera(
    platform: defaultTargetPlatform,
    sensorOrientation: camera.sensorOrientation,
    lensDirection: camera.lensDirection,
    deviceOrientation: controller.value.deviceOrientation,
  );
  if (rotation == null) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  // Single-plane formats only (nv21 on Android, bgra8888 on iOS) — the
  // engine requests exactly these via imageFormatGroup, so this always
  // matches on a real device.
  if (format == null || image.planes.length != 1) return null;
  final plane = image.planes.first;

  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

/// Rotates a point from the raw sensor buffer's coordinate space into
/// upright image space — ML Kit's live-stream detections are reported in
/// the former, but [mlKitFaceToTrackingData] (and every other consumer)
/// expects the latter, matching what file-path detection already returns.
Offset mlKitUprightPoint(Offset p, Size rawSize, InputImageRotation rotation) {
  final w = rawSize.width;
  final h = rawSize.height;
  return switch (rotation) {
    InputImageRotation.rotation90deg => Offset(h - p.dy, p.dx),
    InputImageRotation.rotation180deg => Offset(w - p.dx, h - p.dy),
    InputImageRotation.rotation270deg => Offset(p.dy, w - p.dx),
    InputImageRotation.rotation0deg => p,
  };
}

/// The upright equivalent of a raw sensor-space size — width/height swap
/// for a 90/270 degree rotation.
Size mlKitUprightSize(Size rawSize, InputImageRotation rotation) =>
    (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg)
        ? Size(rawSize.height, rawSize.width)
        : rawSize;
