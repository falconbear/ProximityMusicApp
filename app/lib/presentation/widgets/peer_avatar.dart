// Presentation widget: PeerAvatar.
//
// Renders a deterministic geometric avatar from Peer.avatarSeed.
// 6 colours x 6 shapes = 36 unique combinations. CustomPainter only —
// no raster / network image sources are used (spec.md Anti-Slop).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:proximity_music_app/domain/entities/peer.dart';

class PeerAvatar extends StatelessWidget {
  const PeerAvatar({super.key, required this.peer, this.size = 48});

  final Peer peer;
  final double size;

  static const List<Color> _palette = [
    Color(0xFF1DB954), // Primary
    Color(0xFFFF6B6B), // Accent
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFFA374D5),
    Color(0xFF45B7D1),
  ];

  static const List<_AvatarShape> _shapes = [
    _AvatarShape.circle,
    _AvatarShape.square,
    _AvatarShape.triangle,
    _AvatarShape.hexagon,
    _AvatarShape.diamond,
    _AvatarShape.star,
  ];

  @override
  Widget build(BuildContext context) {
    final colour = _palette[peer.avatarSeed.abs() % _palette.length];
    final shape =
        _shapes[(peer.avatarSeed.abs() ~/ _palette.length) % _shapes.length];
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PeerAvatarPainter(colour: colour, shape: shape),
      ),
    );
  }
}

enum _AvatarShape { circle, square, triangle, hexagon, diamond, star }

class _PeerAvatarPainter extends CustomPainter {
  _PeerAvatarPainter({required this.colour, required this.shape});

  final Color colour;
  final _AvatarShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = colour
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = colour.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;

    switch (shape) {
      case _AvatarShape.circle:
        canvas.drawCircle(centre, radius, fill);
        canvas.drawCircle(centre, radius, stroke);
        break;
      case _AvatarShape.square:
        final rect = Rect.fromCenter(
          center: centre,
          width: radius * 1.6,
          height: radius * 1.6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          fill,
        );
        break;
      case _AvatarShape.triangle:
        final path = Path()
          ..moveTo(centre.dx, centre.dy - radius)
          ..lineTo(centre.dx - radius, centre.dy + radius * 0.6)
          ..lineTo(centre.dx + radius, centre.dy + radius * 0.6)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case _AvatarShape.hexagon:
        canvas.drawPath(_polygonPath(centre, radius, 6), fill);
        break;
      case _AvatarShape.diamond:
        final path = Path()
          ..moveTo(centre.dx, centre.dy - radius)
          ..lineTo(centre.dx + radius, centre.dy)
          ..lineTo(centre.dx, centre.dy + radius)
          ..lineTo(centre.dx - radius, centre.dy)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case _AvatarShape.star:
        canvas.drawPath(_starPath(centre, radius), fill);
        break;
    }
  }

  Path _polygonPath(Offset c, double r, int sides) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = (i / sides) * 2 * math.pi - math.pi / 2;
      final dx = c.dx + r * math.cos(angle);
      final dy = c.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    path.close();
    return path;
  }

  Path _starPath(Offset c, double r) {
    final path = Path();
    const points = 5;
    final inner = r * 0.45;
    for (var i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final radius = isOuter ? r : inner;
      final angle = (i / (points * 2)) * 2 * math.pi - math.pi / 2;
      final dx = c.dx + radius * math.cos(angle);
      final dy = c.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PeerAvatarPainter old) =>
      old.colour != colour || old.shape != shape;
}
