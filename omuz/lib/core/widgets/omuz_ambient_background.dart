import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft drifting gradients behind the whole app (wired in [MaterialApp.builder]).
class OmuzAmbientShell extends StatefulWidget {
  const OmuzAmbientShell({super.key, required this.child});

  final Widget? child;

  @override
  State<OmuzAmbientShell> createState() => _OmuzAmbientShellState();
}

class _OmuzAmbientShellState extends State<OmuzAmbientShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return SizedBox.expand(
                child: CustomPaint(
                  painter: _OmuzAmbientPainter(_controller.value),
                ),
              );
            },
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _OmuzAmbientPainter extends CustomPainter {
  _OmuzAmbientPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.drawRect(Offset.zero & size, Paint()..color = AppTheme.background);

    final w = size.width;
    final h = size.height;
    final dim = w < h ? w : h;

    void orb(double phase, List<Color> colors, List<double> stops) {
      final ang = t * 2 * math.pi + phase;
      final cx = w * 0.5 + w * 0.38 * math.cos(ang * 0.85);
      final cy = h * 0.42 + h * 0.32 * math.sin(ang * 1.05);
      final r = dim * 0.92;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final paint = Paint()
        ..shader = RadialGradient(colors: colors, stops: stops).createShader(rect);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    orb(0.0, [
      AppTheme.gradientStart.withValues(alpha: 0.30),
      AppTheme.gradientEnd.withValues(alpha: 0.11),
      Colors.transparent,
    ], const [0.0, 0.42, 1.0]);

    orb(2.15, [
      AppTheme.gradientEnd.withValues(alpha: 0.22),
      AppTheme.accentPink.withValues(alpha: 0.10),
      Colors.transparent,
    ], const [0.0, 0.48, 1.0]);

    orb(4.3, [
      AppTheme.accentPink.withValues(alpha: 0.14),
      AppTheme.gradientStart.withValues(alpha: 0.08),
      Colors.transparent,
    ], const [0.0, 0.55, 1.0]);
  }

  @override
  bool shouldRepaint(covariant _OmuzAmbientPainter oldDelegate) =>
      oldDelegate.t != t;
}
