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

  /// Border on sage tints (chips, icon tiles).
  static const Color sageTintBorder = Color(0xFFCFE0D8);

  static const Color terracotta = Color(0xFFD97A4F);

  /// Terracotta text on tint / pressed states.
  static const Color terracottaDeep = Color(0xFFB3673A);

  /// Warning / pending / trial backgrounds and their border.
  static const Color terracottaTint = Color(0xFFFCEBDD);
  static const Color terracottaTintBorder = Color(0xFFF2D9C6);

  static const Color ink = Color(0xFF1E1B16);
  static const Color cream = Color(0xFFF8F6F2);
  static const Color muted = Color(0xFF78746D);
  static const Color parchment = Color(0xFFE8E4DC);

  /// Tertiary labels, inactive nav.
  static const Color faint = Color(0xFFA49D92);

  /// In-card row dividers (lighter than [parchment]).
  static const Color divider = Color(0xFFF0ECE3);

  /// Disabled / secondary tile fill.
  static const Color fieldMuted = Color(0xFFF2EFE8);

  /// No explicit "danger" tone exists in the brand — a desaturated rust
  /// in the terracotta family, used for destructive/no-show actions.
  static const Color danger = Color(0xFFB3543E);

  static const Color white = Color(0xFFFFFFFF);

  /// ShoriBooks brand blue — the "S" mark and wordmark colour.
  static const Color shoriBlue = Color(0xFFA3D0E6);

  // ── Semantic status (text on tint) ─────────────────────────────────────
  static const Color successText = Color(0xFF15803D);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color closedText = Color(0xFF374151);
  static const Color closedBg = Color(0xFFF3F4F6);

  /// WhatsApp action buttons.
  static const Color whatsapp = Color(0xFF25D366);

  static const Map<String, Color> roleColors = {
    'OWNER': sage,
    'ADMIN': terracotta,
    'STAFF': muted,
  };
}
