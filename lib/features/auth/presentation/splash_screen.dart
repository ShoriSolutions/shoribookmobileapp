import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Branded loading splash — a barber-shop themed animation shown while the
/// router resolves the auth/session state. It has NO navigation logic of its
/// own; the router redirects away when ready. Recreated from the "shorivo
/// Splash" design: a Midnight ocean-blue radial backdrop, drifting barber
/// tools, a pulsing bloom, a scissors that snips then rises to reveal the logo,
/// and the wordmark.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // One-shot intro timeline (ms values below map to the design's CSS delays).
  static const int _introMs = 2100;
  late final AnimationController _intro;
  // Long, seamless loop that drives the ambient motion (bloom / breath / drift).
  // 60s never wraps during a real splash, so no visible discontinuity.
  late final AnimationController _loop;

  // Palette (Midnight ocean theme — matches the Shorivo brand blue).
  static const _bg = [Color(0xFF1A3A4A), Color(0xFF0E2029), Color(0xFF060F15)];
  static const _accent = Color(0xFF6FB6D8);
  static const _text = Color(0xFFE8F4FA);
  static const _kicker = _accent;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _introMs),
    )..forward();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, _) {
          final tm = _intro.value * _introMs; // intro time, ms
          final t = _loop.value * 60.0; // ambient time, seconds

          // ── one-shot values ────────────────────────────────────────────
          final spark = _clamp01((tm - 400) / 700);
          final reveal = _clamp01((tm - 400) / 800);
          final logoOpacity = _clamp01(reveal / 0.6);
          final logoScale = reveal < 0.6
              ? _lerp(0.5, 1.08, reveal / 0.6)
              : _lerp(1.08, 1.0, (reveal - 0.6) / 0.4);
          final word = Curves.easeOut.transform(_clamp01((tm - 1000) / 700));
          final kick = Curves.easeOut.transform(_clamp01((tm - 1200) / 700));

          // ── ambient values ─────────────────────────────────────────────
          final bloomWave = (1 - math.cos(2 * math.pi * t / 3.2)) / 2;
          final bloomOpacity = 0.5 + 0.42 * bloomWave;
          final bloomScale = 1 + 0.14 * bloomWave;
          final breathT = t - 1.6;
          final breath = breathT <= 0
              ? 1.0
              : 1 + 0.025 * (1 - math.cos(2 * math.pi * breathT / 3.0));

          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.24),
                    radius: 1.15,
                    colors: _bg,
                    stops: [0, 0.47, 1],
                  ),
                ),
              ),

              // Drifting barber tools
              Positioned.fill(child: _tools(t)),

              // Frosted glass -- a light blur that softens the backdrop while
              // keeping the drifting tools visible behind it. The center
              // logo/wordmark below are painted on top and stay crisp.
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x12FFFFFF), Color(0x05FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ),

              // Vignette
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.16),
                    radius: 1.0,
                    colors: [Colors.transparent, Color(0x52000000)],
                    stops: [0.42, 1.0],
                  ),
                ),
              ),

              // Center stack
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Bloom
                          Opacity(
                            opacity: bloomOpacity,
                            child: Transform.scale(
                              scale: bloomScale,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [Color(0x666FB6D8), Colors.transparent],
                                    stops: [0.0, 0.72],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Spark burst
                          if (spark > 0 && spark < 1)
                            Opacity(
                              opacity: (spark < 0.28
                                      ? spark / 0.28
                                      : 1 - (spark - 0.28) / 0.72) *
                                  0.85,
                              child: Transform.scale(
                                scale: _lerp(0.35, 1.9, spark),
                                child: Container(
                                  width: 135,
                                  height: 135,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [Color(0x8C6FB6D8), Colors.transparent],
                                      stops: [0.0, 0.6],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Logo (reveal-pop then breath)
                          Opacity(
                            opacity: logoOpacity,
                            child: Transform.scale(
                              scale: logoScale * breath,
                              child: Image.asset(
                                'assets/branding/shorivo-brand.png',
                                width: 118,
                                height: 118,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Wordmark
                    Transform.translate(
                      offset: Offset(0, 16 * (1 - word)),
                      child: Opacity(
                        opacity: word,
                        child: const Text(
                          'shorivo',
                          style: TextStyle(
                            fontFamily: 'Fraunces',
                            fontWeight: FontWeight.w600,
                            fontSize: 48,
                            height: 1,
                            color: _text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Kicker
                    Transform.translate(
                      offset: Offset(0, 16 * (1 - kick)),
                      child: Opacity(
                        opacity: kick,
                        child: const Text(
                          'BOOK YOUR CHAIR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3.4,
                            color: _kicker,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footnote
              Positioned(
                left: 0,
                right: 0,
                bottom: 38,
                child: Opacity(
                  opacity: Curves.easeOut.transform(_clamp01((tm - 1400) / 700)),
                  child: const Text(
                    'BOOKING FOR PROFESSIONALS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 2.5,
                      color: Color(0x70E8F4FA),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tools(double t) {
    // (leftFrac, topFrac, size, opacity, type, periodSec, phase)
    // Scattered across the whole canvas; the center band (~0.35-0.65 x,
    // 0.30-0.60 y) is left clear for the logo + wordmark.
    const specs = <_ToolSpec>[
      _ToolSpec(0.06, 0.08, 50, 0.50, _Tool.scissors, 12, 0.4),
      _ToolSpec(0.90, 0.05, 42, 0.42, _Tool.comb, 14, 1.1),
      _ToolSpec(0.40, 0.04, 30, 0.34, _Tool.clippers, 11, 2.6),
      _ToolSpec(0.64, 0.11, 34, 0.36, _Tool.razor, 13, 0.2),
      _ToolSpec(0.03, 0.28, 52, 0.46, _Tool.razor, 13, 2.0),
      _ToolSpec(0.93, 0.26, 40, 0.44, _Tool.clippers, 15, 0.7),
      _ToolSpec(0.73, 0.34, 30, 0.32, _Tool.scissors, 11.5, 3.6),
      _ToolSpec(0.15, 0.50, 46, 0.42, _Tool.comb, 14.5, 2.9),
      _ToolSpec(0.91, 0.52, 44, 0.46, _Tool.scissors, 13.5, 1.7),
      _ToolSpec(0.04, 0.70, 54, 0.44, _Tool.razor, 12.5, 3.1),
      _ToolSpec(0.85, 0.72, 46, 0.42, _Tool.clippers, 15, 0.9),
      _ToolSpec(0.10, 0.90, 34, 0.36, _Tool.scissors, 12, 4.0),
      _ToolSpec(0.36, 0.93, 32, 0.34, _Tool.comb, 12.5, 1.4),
      _ToolSpec(0.66, 0.90, 36, 0.38, _Tool.scissors, 14, 2.3),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            for (final s in specs)
              _driftingTool(s, c.maxWidth, c.maxHeight, t),
          ],
        );
      },
    );
  }

  Widget _driftingTool(_ToolSpec s, double w, double h, double t) {
    final phase = 2 * math.pi * (t / s.period) + s.phase;
    final dx = 18 * math.sin(phase);
    final dy = 20 * math.cos(phase * 0.9);
    final rot = 0.12 * math.sin(phase);
    return Positioned(
      left: s.left * w - s.size / 2 + dx,
      top: s.top * h - s.size / 2 + dy,
      child: Transform.rotate(
        angle: rot,
        child: Opacity(
          opacity: s.opacity * 0.78,
          child: CustomPaint(
            size: Size(s.size, s.size),
            painter: _ToolPainter(s.type, _text),
          ),
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

enum _Tool { scissors, comb, razor, clippers }

class _ToolSpec {
  final double left, top, size, opacity;
  final _Tool type;
  final double period, phase;
  const _ToolSpec(this.left, this.top, this.size, this.opacity, this.type,
      this.period, this.phase);
}

/// Draws a barber tool in a 24x24 space scaled to [size], line-art style.
class _ToolPainter extends CustomPainter {
  final _Tool tool;
  final Color color;
  const _ToolPainter(this.tool, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (tool) {
      case _Tool.scissors:
        canvas.drawCircle(const Offset(6, 6), 3, p);
        canvas.drawCircle(const Offset(6, 18), 3, p);
        canvas.drawLine(const Offset(20, 4), const Offset(8.12, 15.88), p);
        canvas.drawLine(const Offset(14.47, 14.48), const Offset(20, 20), p);
        canvas.drawLine(const Offset(8.12, 8.12), const Offset(12, 12), p);
      case _Tool.comb:
        canvas.drawLine(const Offset(3, 7), const Offset(21, 7), p);
        for (final x in const [5.0, 11.4, 17.8]) {
          canvas.drawLine(Offset(x, 7), Offset(x, 13), p);
        }
        for (final x in const [8.2, 14.6, 21.0]) {
          canvas.drawLine(Offset(x, 7), Offset(x, 17), p);
        }
      case _Tool.razor:
        canvas.drawLine(const Offset(4, 20), const Offset(14.2, 9.8), p);
        final blade = Path()
          ..moveTo(14.2, 9.8)
          ..arcToPoint(const Offset(19.9, 15.5),
              radius: const Radius.circular(4), clockwise: true);
        canvas.drawPath(blade, p);
        canvas.drawLine(const Offset(4, 20), const Offset(2.6, 18.6), p);
      case _Tool.clippers:
        final r = RRect.fromRectAndRadius(
            const Rect.fromLTWH(9, 3.5, 6, 15), const Radius.circular(3));
        canvas.drawRRect(r, p);
        canvas.drawLine(const Offset(9.4, 7.5), const Offset(14.6, 4.5), p);
        canvas.drawLine(const Offset(9.4, 11), const Offset(14.6, 8), p);
        canvas.drawLine(const Offset(9.4, 14.5), const Offset(14.6, 11.5), p);
        canvas.drawLine(const Offset(10, 18.5), const Offset(10, 21), p);
        canvas.drawLine(const Offset(14, 18.5), const Offset(14, 21), p);
    }
  }

  @override
  bool shouldRepaint(_ToolPainter old) => old.tool != tool || old.color != color;
}
