/// Time-of-day greetings, reused across the app (dashboard, etc.).
///
/// Bands (local time):
///  - 05:00–11:59  Good morning
///  - 12:00–16:59  Good afternoon
///  - 17:00–21:59  Good evening
///  - 22:00–04:59  Working late? (late-night)
class Greeting {
  const Greeting._();

  /// The bare greeting phrase for [at] (defaults to now), no name/emoji.
  /// e.g. "Good morning" or "Working late?".
  static String phrase([DateTime? at]) {
    final h = (at ?? DateTime.now()).hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    if (h >= 17 && h < 22) return 'Good evening';
    return 'Working late?';
  }

  /// The trailing emoji that pairs with the current band — 🌙 late at
  /// night, 👋 otherwise.
  static String emoji([DateTime? at]) {
    final h = (at ?? DateTime.now()).hour;
    return (h >= 22 || h < 5) ? '🌙' : '👋';
  }

  /// A full greeting line, optionally personalised: "Good morning, Sarah 👋"
  /// or, late at night, "Working late, Sarah? 🌙". Pass [withEmoji] false to
  /// omit the emoji.
  static String full({String? name, DateTime? at, bool withEmoji = true}) {
    final trimmed = name?.trim();
    final e = withEmoji ? ' ${emoji(at)}' : '';
    if (trimmed == null || trimmed.isEmpty) {
      return '${phrase(at)}$e';
    }
    // "Working late?" reads best as "Working late, Sarah?".
    final p = phrase(at);
    if (p.endsWith('?')) {
      return '${p.substring(0, p.length - 1)}, $trimmed?$e';
    }
    return '$p, $trimmed$e';
  }
}
