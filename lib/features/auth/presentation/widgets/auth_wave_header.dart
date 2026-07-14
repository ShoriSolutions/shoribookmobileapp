import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shori_logo.dart';

/// Text-free header for the auth screens: clear, translucent colour
/// "bubbles" (seafoam / deep blue / gold / terracotta) sit still over a
/// dark gradient, while the wave line along the bottom edge flows
/// continuously. Purely decorative — no logo, no copy — so it reads as
/// one continuous motif as the user moves between login / register
/// sections.
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

  /// The white ShoriBooks mark + wordmark, centred over the header.
  final bool showLogo;

  @override
  State<AuthWaveHeader> createState() => _AuthWaveHeaderState();
}

class _AuthWaveHeaderState extends State<AuthWaveHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // One slow, continuously-repeating cycle scrolls the wave's phase.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
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
                animation: _controller,
                builder: (context, _) => ClipPath(
                  // The moving part: the wave edge is re-cut each frame.
                  clipper: _WaveClipper(_controller.value),
                  // The still part: bubbles + gradient don't animate.
                  child: const CustomPaint(painter: _BubblePainter()),
                ),
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
                  markSize: (widget.height * 0.36).clamp(40, 64),
                  color: Colors.white,
                ),
              ),
            ),
          if (widget.showBack)
            Positioned(
              top: topInset + 2,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
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
  const _BubblePainter();

  // Muted, complementary washes — brand sage/terracotta plus a deep blue
  // and a soft gold to match the reference's colour story.
  static const _deepBlue = Color(0xFF3E6E8E);
  static const _gold = Color(0xFFD9B45F);

  static const _bubbles = <_Bubble>[
    _Bubble(color: AppColors.sage, radius: 0.30, cx: 0.16, cy: 0.42),
    _Bubble(color: _deepBlue, radius: 0.26, cx: 0.74, cy: 0.30),
    _Bubble(color: _gold, radius: 0.18, cx: 0.50, cy: 0.66),
    _Bubble(color: AppColors.terracotta, radius: 0.16, cx: 0.87, cy: 0.68),
    _Bubble(color: AppColors.sageLight, radius: 0.14, cx: 0.09, cy: 0.78),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);

    // Dark, slightly green-teal gradient backdrop.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25332F), Color(0xFF181D1B)],
        ).createShader(rect),
    );

    for (final b in _bubbles) {
      final center = Offset(b.cx * size.width, b.cy * size.height);
      final r = b.radius * size.width;
      // Clear orb: a defined core held most of the way out, then a quick
      // fade to transparent at the rim. A tiny blur softens the edge.
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withValues(alpha: 0.50),
            b.color.withValues(alpha: 0.40),
            b.color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.80, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) => false;
}
