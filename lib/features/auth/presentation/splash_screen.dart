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
  // One-shot intro timeline (ms). Slowed so the full sequence plays out.
  static const int _introMs = 3800;
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

          // ── one-shot values (slowed timeline) ──────────────────────────
          final spark = _clamp01((tm - 600) / 1100);
          final reveal = _clamp01((tm - 500) / 1500);
          final logoOpacity = _clamp01(reveal / 0.6);
          final logoScale = reveal < 0.6
              ? _lerp(0.6, 1.06, reveal / 0.6)
              : _lerp(1.06, 1.0, (reveal - 0.6) / 0.4);
          final word = Curves.easeOut.transform(_clamp01((tm - 1800) / 1100));
          final kick = Curves.easeOut.transform(_clamp01((tm - 2200) / 1000));

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

              // Floating circles
              Positioned.fill(child: CustomPaint(painter: _CirclesPainter(t))),

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
                  opacity: Curves.easeOut.transform(_clamp01((tm - 2600) / 1000)),
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

/// A single floating circle. [x]/[y] are 0..1 fractions of its resting
/// position; [size] is the diameter in px.
class _Bubble {
  final double x, y, size, opacity, period, phase;
  final int color; // index into _CirclesPainter._colors
  const _Bubble(
    this.x,
    this.y,
    this.size,
    this.color,
    this.opacity,
    this.period,
    this.phase,
  );
}

/// Draws large solid circles in the darker brand palette (deep sage /
/// terracotta / blue / taupe) that float gently in place — a slow sinusoidal
/// drift around a fixed position, no rising.
class _CirclesPainter extends CustomPainter {
  final double t;
  const _CirclesPainter(this.t);

  static const _colors = [
    Color(0xFF5C8070), // sage dark
    Color(0xFF3F5F52), // deep sage
    Color(0xFFB3673A), // terracotta deep
    Color(0xFF8F4E28), // deeper terracotta
    Color(0xFF5F92B0), // deeper brand blue
    Color(0xFF8A8377), // taupe
  ];

  // (x, y, diameterPx, colorIdx, opacity, periodSec, phase) — large circles
  // resting at fixed positions; some peek in from the edges.
  static const _circles = <_Bubble>[
    _Bubble(0.14, 0.16, 240, 0, 0.30, 20, 0.4),
    _Bubble(0.90, 0.08, 190, 4, 0.28, 17, 1.1),
    _Bubble(0.50, 0.60, 160, 2, 0.24, 15, 2.6),
    _Bubble(0.08, 0.74, 210, 3, 0.28, 18, 0.7),
    _Bubble(0.84, 0.54, 280, 1, 0.26, 22, 3.6),
    _Bubble(0.96, 0.86, 180, 0, 0.28, 16, 2.0),
    _Bubble(0.28, 0.94, 200, 4, 0.26, 19, 0.2),
    _Bubble(0.70, 0.26, 150, 2, 0.24, 14, 1.4),
    _Bubble(0.04, 0.42, 170, 5, 0.26, 15.5, 2.3),
    _Bubble(0.44, 0.06, 150, 3, 0.26, 13.5, 4.0),
    _Bubble(0.74, 0.92, 160, 0, 0.26, 17.5, 0.9),
    _Bubble(0.20, 0.48, 130, 2, 0.22, 12.5, 3.1),
    _Bubble(0.62, 0.76, 220, 4, 0.26, 20.5, 1.7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _circles) {
      // Gentle in-place float: a slow sinusoidal drift around the rest point.
      final cx = size.width * b.x +
          14 * math.sin(2 * math.pi * (t / b.period) + b.phase);
      final cy = size.height * b.y +
          12 * math.cos(2 * math.pi * (t / b.period) * 0.9 + b.phase);
      // Subtle opacity breathing so they feel alive.
      final pulse =
          0.88 + 0.12 * math.sin(2 * math.pi * (t / b.period) + b.phase * 1.3);
      canvas.drawCircle(
        Offset(cx, cy),
        b.size / 2,
        Paint()..color = _colors[b.color].withValues(alpha: b.opacity * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_CirclesPainter old) => old.t != t;
}
