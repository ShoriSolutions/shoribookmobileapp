import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Branded loading splash shown while the router resolves the auth/session
/// state. It has NO navigation logic of its own; the router redirects away
/// when ready. Themed to match the Shorivo app + website palette (warm cream
/// background, sage + terracotta accents) with softly rising bubbles behind
/// the logo tile and wordmark.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // One-shot intro timeline (ms).
  static const int _introMs = 2100;
  late final AnimationController _intro;
  // Long, seamless loop for the ambient motion (bubbles / bloom / breath).
  late final AnimationController _loop;

  // Brand palette (matches app_colors.dart + shorivo.com).
  static const _bg = [
    Color(0xFFFCFBF9), // near-white warm center
    Color(0xFFF3F1EA), // cream
    Color(0xFFE9F0EC), // sage-tinted edge
  ];
  static const _sage = Color(0xFF7A9E8C);
  static const _ink = Color(0xFF1E1B16);
  static const _muted = Color(0xFF78746D);

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
          final reveal = _clamp01((tm - 300) / 900);
          final logoOpacity = _clamp01(reveal / 0.6);
          final logoScale = reveal < 0.6
              ? _lerp(0.6, 1.06, reveal / 0.6)
              : _lerp(1.06, 1.0, (reveal - 0.6) / 0.4);
          final word = Curves.easeOut.transform(_clamp01((tm - 1000) / 700));
          final kick = Curves.easeOut.transform(_clamp01((tm - 1200) / 700));

          // ── ambient values ─────────────────────────────────────────────
          final bloomWave = (1 - math.cos(2 * math.pi * t / 3.2)) / 2;
          final bloomOpacity = 0.4 + 0.35 * bloomWave;
          final bloomScale = 1 + 0.12 * bloomWave;
          final breathT = t - 1.6;
          final breath = breathT <= 0
              ? 1.0
              : 1 + 0.02 * (1 - math.cos(2 * math.pi * breathT / 3.0));

          return Stack(
            fit: StackFit.expand,
            children: [
              // Warm cream backdrop
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.22),
                    radius: 1.2,
                    colors: _bg,
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),

              // Rising bubbles
              Positioned.fill(child: CustomPaint(painter: _BubblesPainter(t))),

              // Whisper of frosted glass to tie it together (kept very light
              // so the bubbles stay crisp).
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0AFFFFFF), Color(0x03FFFFFF)],
                      ),
                    ),
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
                          // Sage bloom behind the tile
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
                                    colors: [Color(0x4D7A9E8C), Colors.transparent],
                                    stops: [0.0, 0.72],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Spark burst on reveal (sage)
                          if (spark > 0 && spark < 1)
                            Opacity(
                              opacity: (spark < 0.28
                                      ? spark / 0.28
                                      : 1 - (spark - 0.28) / 0.72) *
                                  0.7,
                              child: Transform.scale(
                                scale: _lerp(0.4, 1.9, spark),
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [Color(0x807A9E8C), Colors.transparent],
                                      stops: [0.0, 0.6],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Logo on a white tile (so the blue mark reads on
                          // the cream backdrop) — reveal-pop then gentle breath.
                          Opacity(
                            opacity: logoOpacity,
                            child: Transform.scale(
                              scale: logoScale * breath,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _sage.withValues(alpha: 0.22),
                                      blurRadius: 34,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/branding/shorivo-brand.png',
                                  width: 92,
                                  height: 92,
                                  filterQuality: FilterQuality.medium,
                                ),
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
                            color: _ink,
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
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.4,
                            color: _sage,
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
                      color: _muted,
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
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A single rising bubble. [x]/[startY] are 0..1 fractions; [size] is in px.
class _Bubble {
  final double x, startY, size, opacity, period, phase;
  final int color; // index into _BubblesPainter._colors
  const _Bubble(
    this.x,
    this.startY,
    this.size,
    this.color,
    this.opacity,
    this.period,
    this.phase,
  );
}

/// Draws softly rising, swaying bubbles across the whole canvas in the brand
/// palette (sage / terracotta / brand blue).
class _BubblesPainter extends CustomPainter {
  final double t;
  const _BubblesPainter(this.t);

  static const _colors = [
    Color(0xFF7A9E8C), // sage
    Color(0xFFD97A4F), // terracotta
    Color(0xFFA3D0E6), // brand blue
  ];

  // (x, startY, sizePx, colorIdx, opacity, periodSec, phase) — scattered.
  static const _bubbles = <_Bubble>[
    _Bubble(0.10, 0.20, 58, 0, 0.45, 17, 0.4),
    _Bubble(0.86, 0.05, 40, 1, 0.40, 14, 1.1),
    _Bubble(0.50, 0.55, 30, 2, 0.38, 12, 2.6),
    _Bubble(0.22, 0.78, 46, 1, 0.42, 15, 0.7),
    _Bubble(0.72, 0.35, 26, 0, 0.36, 11, 3.6),
    _Bubble(0.05, 0.50, 34, 2, 0.40, 13, 2.0),
    _Bubble(0.93, 0.62, 52, 0, 0.44, 18, 0.2),
    _Bubble(0.38, 0.12, 22, 1, 0.34, 10, 1.4),
    _Bubble(0.63, 0.88, 44, 2, 0.42, 16, 2.3),
    _Bubble(0.15, 0.95, 30, 0, 0.38, 12.5, 4.0),
    _Bubble(0.80, 0.82, 34, 0, 0.40, 14.5, 0.9),
    _Bubble(0.44, 0.30, 40, 2, 0.36, 13.5, 1.7),
    _Bubble(0.30, 0.45, 24, 1, 0.34, 11.5, 3.1),
    _Bubble(0.68, 0.10, 48, 0, 0.42, 16.5, 2.9),
    _Bubble(0.90, 0.40, 20, 1, 0.32, 10.5, 0.6),
    _Bubble(0.55, 0.72, 28, 0, 0.38, 12, 3.9),
    _Bubble(0.08, 0.72, 22, 2, 0.34, 11, 1.9),
    _Bubble(0.48, 0.02, 36, 0, 0.40, 15.5, 2.2),
  ];

  double _fade(double yf) {
    const edge = 0.14;
    final top = (yf / edge).clamp(0.0, 1.0);
    final bot = ((1 - yf) / edge).clamp(0.0, 1.0);
    return math.min(top, bot);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _bubbles) {
      // Rise: yf decreases over time (bottom -> top), wrapping seamlessly.
      var yf = (b.startY - t / b.period) % 1.0;
      if (yf < 0) yf += 1.0;
      final fade = _fade(yf);
      if (fade <= 0) continue;

      final sway = 0.025 * math.sin(2 * math.pi * (t / b.period) + b.phase);
      final cx = size.width * (b.x + sway);
      final cy = size.height * (yf * 1.2 - 0.1);
      final r = b.size / 2;
      final base = _colors[b.color];
      final o = b.opacity * fade;
      final center = Offset(cx, cy);

      // Soft fill
      canvas.drawCircle(
        center,
        r,
        Paint()..color = base.withValues(alpha: 0.13 * fade),
      );
      // Ring
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = base.withValues(alpha: 0.55 * o),
      );
      // Highlight
      canvas.drawCircle(
        Offset(cx - r * 0.32, cy - r * 0.32),
        r * 0.15,
        Paint()..color = Colors.white.withValues(alpha: 0.6 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.t != t;
}
