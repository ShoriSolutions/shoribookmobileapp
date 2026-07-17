/// The strong-password rules used when a NEW password is chosen
/// (registration and password reset). Login is exempt — you enter your
/// existing password there.
class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;
  static const int maxLength = 12;

  static bool _len(String p) => p.length >= minLength && p.length <= maxLength;
  static bool _upper(String p) => p.contains(RegExp(r'[A-Z]'));
  static bool _lower(String p) => p.contains(RegExp(r'[a-z]'));
  static bool _digit(String p) => p.contains(RegExp(r'[0-9]'));
  // Any non-alphanumeric, non-space character.
  static bool _special(String p) => p.contains(RegExp(r'[^A-Za-z0-9\s]'));

  static bool isValid(String p) =>
      _len(p) && _upper(p) && _lower(p) && _digit(p) && _special(p);

  /// Form-field validator: an error message, or null when valid.
  static String? validate(String? p) {
    final v = p ?? '';
    if (v.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (v.length > maxLength) {
      return 'Password must be $maxLength characters or fewer';
    }
    if (!_upper(v)) return 'Add an uppercase letter';
    if (!_lower(v)) return 'Add a lowercase letter';
    if (!_digit(v)) return 'Add a number';
    if (!_special(v)) return 'Add a special character';
    return null;
  }

  /// The requirements + whether each is currently met, for a live checklist.
  static List<({String label, bool met})> checklist(String p) => [
        (label: '$minLength–$maxLength characters', met: _len(p)),
        (label: 'An uppercase letter', met: _upper(p)),
        (label: 'A lowercase letter', met: _lower(p)),
        (label: 'A number', met: _digit(p)),
        (label: 'A special character', met: _special(p)),
      ];
}
