import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// A single app-wide clock so every bubble surface (the splash and the auth
// headers) computes the same phase for a given instant and stays in sync.
final Stopwatch _clock = Stopwatch()..start();

/// One full wave cycle. Long, so the motion stays gentle.
const Duration bubbleWavePeriod = Duration(seconds: 28);

/// Bubbles drift on their own phase, ~3% faster than the wave (28000 /
/// 1.03). Its own wrapping phase stays continuous, so no jump on wrap.
const Duration _bubblePeriod = Duration(milliseconds: 27184);

double wavePhase() =>
    (_clock.elapsedMilliseconds % bubbleWavePeriod.inMilliseconds) /
    bubbleWavePeriod.inMilliseconds;

double bubblePhase() =>
    (_clock.elapsedMilliseconds % _bubblePeriod.inMilliseconds) /
    _bubblePeriod.inMilliseconds;

/// The brand beige backdrop behind the bubbles.
const Color kBubbleBeige = Color(0xFFE0D8C8);

/// A full-area animated background — a solid beige field with soft,
/// slowly-drifting colour "bubbles" (a frosted look). Fills its parent.
/// Reused on the splash; the auth header paints the same [BubblePainter]
/// under its wave clip.
class BubbleBackground extends StatefulWidget {
  const BubbleBackground({super.key});

  @override
  State<BubbleBackground> createState() => _BubbleBackgroundState();
}

class _BubbleBackgroundState extends State<BubbleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    // Repaints each frame; the phase itself comes from the shared clock.
    _ticker = AnimationController(vsync: this, duration: bubbleWavePeriod)
      ..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ticker,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: BubblePainter(bubblePhase()),
        ),
      ),
    );
  }
}

class _Bubble {
  const _Bubble({
    required this.color,
    required this.radius,
    required this.cx,
    required this.cy,
  });

  final Color color;
  final double radius; // fraction of width
  final double cx; // fraction of width
  final double cy; // fraction of height
}

/// Paints the beige field + drifting bubbles. [t] is the bubble phase
/// (0..1). Used directly by the auth header (clipped to a wave) and by
/// [BubbleBackground].
class BubblePainter extends CustomPainter {
  const BubblePainter(this.t);

  final double t;

  static const _deepBlue = Color(0xFF3E6E8E);
  static const _gold = Color(0xFFD9B45F);

  static const _bubbles = <_Bubble>[
    _Bubble(color: AppColors.sage, radius: 0.30, cx: 0.16, cy: 0.42),
    _Bubble(color: _deepBlue, radius: 0.26, cx: 0.74, cy: 0.30),
    _Bubble(color: _gold, radius: 0.18, cx: 0.50, cy: 0.66),
    _Bubble(color: AppColors.terracotta, radius: 0.16, cx: 0.87, cy: 0.68),
    _Bubble(color: AppColors.sage, radius: 0.14, cx: 0.09, cy: 0.78),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = kBubbleBeige);

    for (var i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      final ang = 2 * math.pi * (t + i / _bubbles.length);
      final cx = (b.cx + 0.03 * math.sin(ang)) * size.width;
      final cy = (b.cy + 0.02 * math.cos(ang)) * size.height;
      final center = Offset(cx, cy);
      final r = b.radius * size.width;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withValues(alpha: 0.48),
            b.color.withValues(alpha: 0.37),
            b.color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.80, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) =>
      oldDelegate.t != t;
}
