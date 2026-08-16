import 'package:flutter/widgets.dart';

/// The single source of truth for spacing across Shorivo.
///
/// Use these instead of scattering raw pixel values. The scale is a 4-based
/// step system (4 / 8 / 12 / 16 / 24 / 32) that matches the values already most
/// common in the app, so adopting it is a like-for-like swap, not a redesign.
///
/// `screenGutter` is the standard left/right padding for a screen's body —
/// prefer it for new screens so horizontal gutters stay consistent.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard screen body side padding.
  static const double screenGutter = 16;

  // Ready-made SizedBoxes for column/row gaps (avoids re-instantiating).
  static const gapXs = SizedBox(height: xs, width: xs);
  static const gapSm = SizedBox(height: sm, width: sm);
  static const gapMd = SizedBox(height: md, width: md);
  static const gapLg = SizedBox(height: lg, width: lg);
  static const gapXl = SizedBox(height: xl, width: xl);

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: screenGutter);
}

/// Corner radii used across Shorivo. These match the values already baked into
/// the theme (controls 12, cards 16, pills 999) — centralised so a component
/// never drifts to an off-system radius.
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double control = 12; // buttons, inputs
  static const double card = 16; // cards, tiles, sheets' inner surfaces
  static const double pill = 999; // chips, circular buttons

  static BorderRadius get controlBr => BorderRadius.circular(control);
  static BorderRadius get cardBr => BorderRadius.circular(card);
  static BorderRadius get pillBr => BorderRadius.circular(pill);
}
