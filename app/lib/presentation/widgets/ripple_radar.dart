// Presentation widget: RippleRadarView.
//
// CustomPainter-based pulsating concentric circles. Active state
// loops three rings outward; idle state shows only the centre icon.
// Uses the spec.md palette (Primary #1DB954, Accent #FF6B6B).

import 'package:flutter/material.dart';

class RippleRadarView extends StatefulWidget {
  const RippleRadarView({super.key, required this.active, this.size = 200});

  final bool active;
  final double size;

  @override
  State<RippleRadarView> createState() => _RippleRadarViewState();
}

class _RippleRadarViewState extends State<RippleRadarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RippleRadarView old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RipplePainter(
              progress: _controller.value,
              active: widget.active,
            ),
            child: Center(
              child: Icon(
                Icons.radar,
                color: const Color(0xFF1DB954),
                size: widget.size / 4,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress, required this.active});

  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2;

    if (!active) {
      // Idle — single faint static circle.
      final paint = Paint()
        ..color = const Color(0xFF1DB954).withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(centre, maxRadius * 0.7, paint);
      return;
    }

    // Three rings, each phase-shifted by 1/3 of the cycle.
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final radius = phase * maxRadius;
      final alpha = (1.0 - phase).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = (i == 1 ? const Color(0xFFFF6B6B) : const Color(0xFF1DB954))
            .withOpacity(0.3 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(centre, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.progress != progress || old.active != active;
}
