import 'package:flutter/widgets.dart';

/// ShoriBooks's actual shipping brand palette (matched from the web
/// app's source, not the generic teal/navy direction in the original
/// brief) — a warm sage/terracotta boutique look, kept identical across
/// web and mobile.
class AppColors {
  const AppColors._();

  static const Color sage = Color(0xFF7A9E8C);
  static const Color sageDark = Color(0xFF5C8070);
  static const Color sageLight = Color(0xFFEDF3F0);

  static const Color terracotta = Color(0xFFD97A4F);

  static const Color ink = Color(0xFF1E1B16);
  static const Color cream = Color(0xFFF8F6F2);
  static const Color muted = Color(0xFF78746D);
  static const Color parchment = Color(0xFFE8E4DC);

  /// No explicit "danger" tone exists in the brand — a desaturated rust
  /// in the terracotta family, used for destructive/no-show actions.
  static const Color danger = Color(0xFFB3543E);

  static const Color white = Color(0xFFFFFFFF);

  /// ShoriBooks brand blue — the "S" mark and wordmark colour.
  static const Color shoriBlue = Color(0xFFA3D0E6);

  static const Map<String, Color> roleColors = {
    'OWNER': sage,
    'ADMIN': terracotta,
    'STAFF': muted,
  };
}
