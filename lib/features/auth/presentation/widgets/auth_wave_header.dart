import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shori_logo.dart';

/// A single app-wide clock so every [AuthWaveHeader] computes the same
/// wave/bubble phase for a given instant. Because the login and register
/// headers read the same clock (rather than each starting its own
/// animation at 0), they stay perfectly in sync through the cross-fade.
final Stopwatch _authWaveClock = Stopwatch()..start();

/// One full wave cycle. Long, so the motion stays gentle.
const Duration _wavePeriod = Duration(seconds: 28);

/// Bubbles drift on their own phase, ~3% faster than the wave (28000 /
/// 1.03). Its own wrapping phase stays continuous, so no jump on wrap.
const Duration _bubblePeriod = Duration(milliseconds: 27184);

double _wavePhase() =>
    (_authWaveClock.elapsedMilliseconds % _wavePeriod.inMilliseconds) /
    _wavePeriod.inMilliseconds;

double _bubblePhase() =>
    (_authWaveClock.elapsedMilliseconds % _bubblePeriod.inMilliseconds) /
    _bubblePeriod.inMilliseconds;

/// Header for the auth screens: soft colour "bubbles" drift slowly over a
/// solid beige backdrop, while the wave line along the bottom edge flows.
/// The ShoriBooks mark sits centred on top. The motion is driven by a
/// shared clock, so login ↔ register read as one continuous motif.
class AuthWaveHeader extends StatefulWidget {
  const AuthWaveHeader({
    super.key,
    this.height = 160,
    this.showBack = false,
    this.onBack,
    this.showLogo = true,
  });

  /// Height of the coloured area, *excluding* the status-bar inset which
  /// the widget adds on top so bubbles bleed under the notch.
  final double height;
  final bool showBack;
  final VoidCallback? onBack;

  /// The ShoriBooks mark, centred over the header.
  final bool showLogo;

  @override
  State<AuthWaveHeader> createState() => _AuthWaveHeaderState();
}

class _AuthWaveHeaderState extends State<AuthWaveHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    // Drives a repaint every frame; the actual phase comes from the
    // shared clock so all header instances stay in lock-step.
    _ticker = AnimationController(vsync: this, duration: _wavePeriod)..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: widget.height + topInset,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ticker,
                builder: (context, _) {
                  return ClipPath(
                    // The moving wave edge, re-cut each frame.
                    clipper: _WaveClipper(_wavePhase()),
                    // Beige backdrop + slowly drifting bubbles (own phase).
                    child: CustomPaint(painter: _BubblePainter(_bubblePhase())),
                  );
                },
              ),
            ),
          ),
          if (widget.showLogo)
            Positioned(
              top: topInset,
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: ShoriLogo(
                  markSize: (widget.height * 0.40).clamp(44, 72),
                  showWordmark: false,
                  // Deeper than the pale brand blue so the mark reads on
                  // the light beige backdrop.
                  color: const Color(0xFF66A9CE),
                ),
              ),
            ),
          if (widget.showBack)
            Positioned(
              top: topInset + 2,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                onPressed:
                    widget.onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated wavy bottom edge — a sine wave whose phase scrolls with [t],
/// so the line appears to flow horizontally. Clips to the region *above*
/// the wave, i.e. the coloured header area.
class _WaveClipper extends CustomClipper<Path> {
  const _WaveClipper(this.t);

  /// Animation progress, 0..1.
  final double t;

  static const double _amplitude = 15;
  static const double _cycles = 1.3; // wave humps across the width

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final base = h - _amplitude - 4;
    final phase = t * 2 * math.pi;

    final path = Path()..moveTo(0, base);
    for (double x = 0; x <= w; x += 3) {
      final y = base +
          _amplitude *
              math.sin((x / w) * _cycles * 2 * math.pi + phase);
      path.lineTo(x, y);
    }
    return path
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WaveClipper oldClipper) => oldClipper.t != t;
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

class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.t);

  /// Animation progress, 0..1 — drives the slow bubble drift.
  final double t;

  /// Solid beige backdrop behind the bubbles.
  static const _beige = Color(0xFFE0D8C8);

  // Muted, complementary washes — brand sage/terracotta plus a deep blue
  // and a soft gold to match the reference's colour story.
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

    // Solid beige background.
    canvas.drawRect(rect, Paint()..color = _beige);

    for (var i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      // Each bubble drifts along its own gentle ellipse, offset in phase so
      // they don't move in unison.
      final ang = 2 * math.pi * (t + i / _bubbles.length);
      final cx = (b.cx + 0.03 * math.sin(ang)) * size.width;
      final cy = (b.cy + 0.02 * math.cos(ang)) * size.height;
      final center = Offset(cx, cy);
      final r = b.radius * size.width;
      // Clear orb: a defined core held most of the way out, then a quick
      // fade to transparent at the rim. A tiny blur softens the edge.
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
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.t != t;
}
