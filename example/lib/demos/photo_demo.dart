import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:image_picker/image_picker.dart';

import '../demo_glasses.dart';

/// Still-image try-on: pick a photo from the gallery and place glasses on
/// the detected face with [VirtualTryOnImage] — no live camera.
///
/// Unlike the other demos, this one needs a *real* face to detect, so it
/// picks a photo rather than generating synthetic artwork. The glasses
/// overlay is still generated at runtime (see demo_glasses.dart).
class PhotoDemo extends StatefulWidget {
  /// Creates the photo demo screen.
  const PhotoDemo({super.key});

  @override
  State<PhotoDemo> createState() => _PhotoDemoState();
}

class _PhotoDemoState extends State<PhotoDemo> {
  Uint8List? _photo;
  Uint8List? _glasses;
  String? _status;

  @override
  void initState() {
    super.initState();
    generateGlassesPng().then((bytes) {
      if (mounted) setState(() => _glasses = bytes);
    });
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final glasses = _glasses;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Try-On'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pick,
          ),
        ],
      ),
      body: Center(
        child: photo == null || glasses == null
            ? _EmptyState(onPick: _pick, waiting: glasses == null)
            : Padding(
                padding: const EdgeInsets.all(16),
                child: VirtualTryOnImage(
                  imageBytes: photo,
                  overlays: [GlassesOverlay(image: MemoryImage(glasses))],
                  loadingBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  noFaceBuilder: (_) => const Center(
                    child: Text(
                      "Couldn't find a face in that photo.\nTry another.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  onFaceDetected: (_) =>
                      setState(() => _status = 'Face detected'),
                  onError: (e) => setState(() => _status = e.message),
                ),
              ),
      ),
      bottomNavigationBar: _status == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_status!, textAlign: TextAlign.center),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick, required this.waiting});

  final VoidCallback onPick;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    if (waiting) return const CircularProgressIndicator();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.face_retouching_natural, size: 56),
        const SizedBox(height: 12),
        const Text('Pick a photo with a face to try frames on.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose photo'),
        ),
      ],
    );
  }
}
