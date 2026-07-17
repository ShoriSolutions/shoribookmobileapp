import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubble_background.dart';
import '../../../../core/widgets/shori_logo.dart';

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
                    clipper: _WaveClipper(wavePhase()),
                    // Beige backdrop + slowly drifting bubbles (own phase),
                    // shared with the splash so they read as one motif.
                    child: CustomPaint(painter: BubblePainter(bubblePhase())),
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

