import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final spotlightOverlayControllerProvider = Provider<SpotlightOverlayController>(
  (ref) {
    final controller = SpotlightOverlayController();
    ref.onDispose(controller.hide);
    return controller;
  },
);

class SpotlightOverlayController {
  OverlayEntry? _entry;

  void show(
    BuildContext context, {
    required Rect spotlightRect,
    double opacity = 0.7,
  }) {
    hide();

    _entry = OverlayEntry(
      builder: (_) {
        return _SpotlightLayer(spotlightRect: spotlightRect, opacity: opacity);
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _SpotlightLayer extends StatelessWidget {
  const _SpotlightLayer({required this.spotlightRect, required this.opacity});

  final Rect spotlightRect;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipPath(
        clipper: _SpotlightClipper(spotlightRect),
        child: Container(color: Colors.black.withValues(alpha: opacity)),
      ),
    );
  }
}

class _SpotlightClipper extends CustomClipper<Path> {
  const _SpotlightClipper(this.rect);

  final Rect rect;

  @override
  Path getClip(Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));

    return Path.combine(PathOperation.difference, screen, hole);
  }

  @override
  bool shouldReclip(covariant _SpotlightClipper oldClipper) {
    return oldClipper.rect != rect;
  }
}
