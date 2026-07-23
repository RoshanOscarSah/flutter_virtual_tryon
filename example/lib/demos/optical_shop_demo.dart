import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

import '../demo_glasses.dart';

class _Product {
  const _Product(this.name, this.color);
  final String name;
  final Color color;
}

const _products = [
  _Product('Classic Black', Color(0xFF1A1A1A)),
  _Product('Tortoise', Color(0xFF6D4C41)),
  _Product('Rose Gold', Color(0xFFB76E79)),
  _Product('Ocean Blue', Color(0xFF1565C0)),
];

/// A shape closer to what an optical shop or e-commerce app would build:
/// a product grid up top, live try-on preview below, switching overlays
/// as the shopper taps a different frame. The primary target audience
/// for this package (see doc/PRODUCT_REQUIREMENTS.md "Target
/// Developers") is exactly this kind of app.
class OpticalShopDemo extends StatefulWidget {
  /// Creates the optical-shop demo screen.
  const OpticalShopDemo({super.key});

  @override
  State<OpticalShopDemo> createState() => _OpticalShopDemoState();
}

class _OpticalShopDemoState extends State<OpticalShopDemo> {
  int _selected = 0;
  final _images = <int, Uint8List>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadProduct(0));
  }

  Future<void> _loadProduct(int index) async {
    if (_images.containsKey(index)) return;
    final bytes = await generateGlassesPng(color: _products[index].color);
    if (!mounted) return;
    setState(() => _images[index] = bytes);
  }

  void _select(int index) {
    setState(() => _selected = index);
    unawaited(_loadProduct(index));
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _images[_selected];
    return Scaffold(
      appBar: AppBar(title: const Text('Optical Shop')),
      body: Column(
        children: [
          Expanded(
            child: bytes == null
                ? const Center(child: CircularProgressIndicator())
                : VirtualTryOn(
                    overlays: [GlassesOverlay(image: MemoryImage(bytes))],
                  ),
          ),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: _products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = _products[index];
                final isSelected = index == _selected;
                return GestureDetector(
                  onTap: () => _select(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: product.color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
