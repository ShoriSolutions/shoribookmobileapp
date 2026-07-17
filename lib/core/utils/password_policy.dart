/// The strong-password rules used when a NEW password is chosen
/// (registration and password reset). Login is exempt — you enter your
/// existing password there.
class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;
  static const int maxLength = 12;

  static bool _len(String p) => p.length >= minLength && p.length <= maxLength;

  // At least one letter, number, or special character.
  static bool _hasChar(String p) =>
      p.contains(RegExp(r'[A-Za-z]')) ||
      p.contains(RegExp(r'[0-9]')) ||
      p.contains(RegExp(r'[^A-Za-z0-9\s]'));

  static bool isValid(String p) => _len(p) && _hasChar(p);

  /// Form-field validator: an error message, or null when valid.
  static String? validate(String? p) {
    final v = p ?? '';
    if (v.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (v.length > maxLength) {
      return 'Password must be $maxLength characters or fewer';
    }
    if (!_hasChar(v)) return 'Add a letter, number, or special character';
    return null;
  }

  /// The requirements + whether each is currently met, for a live checklist.
  static List<({String label, bool met})> checklist(String p) => [
        (label: '$minLength–$maxLength characters', met: _len(p)),
        (
          label: 'A letter, number, or special character',
          met: _hasChar(p),
        ),
      ];
}
