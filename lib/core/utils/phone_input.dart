import 'package:flutter/services.dart';

/// Region-aware phone input helpers. Keeps a phone field from growing
/// forever: input is restricted to phone characters and the *digit* count is
/// capped for the region. Centralised so every phone field behaves the same.

// NANP (+1) territories share a 10-digit national number (3-digit area code +
// 7). Most of the Caribbean, US and Canada. 11 digits allows an optional
// leading country-code "1".
const Set<String> _nanpCodes = {
  'BB', 'US', 'CA', 'JM', 'TT', 'BS', 'AG', 'LC', 'VC', 'GD', 'DM', 'KN',
  'AI', 'VG', 'KY', 'TC', 'MS', 'BM', 'PR', 'DO', 'SX', 'GP', 'MF',
};

/// The most digits a phone number should have for [countryCode]. Defaults to
/// the E.164 maximum (15) when the region is unknown or non-NANP.
int phoneMaxDigits(String? countryCode) {
  final cc = (countryCode ?? '').toUpperCase();
  if (_nanpCodes.contains(cc)) return 11;
  return 15; // E.164 maximum
}

/// Input formatters for a phone field: allow digits and common separators,
/// and cap the digit count for the region so it can't grow indefinitely.
List<TextInputFormatter> phoneInputFormatters(String? countryCode) => [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
      MaxPhoneDigitsFormatter(phoneMaxDigits(countryCode)),
    ];

/// Rejects any edit that would push the number past [maxDigits] actual
/// digits (formatting characters like spaces/dashes don't count).
class MaxPhoneDigitsFormatter extends TextInputFormatter {
  const MaxPhoneDigitsFormatter(this.maxDigits);
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > maxDigits ? oldValue : newValue;
  }
}

/// True when [value] has a plausible number of digits for the region — at
/// least 7 (shortest sensible local number) and no more than the region cap.
bool isPlausiblePhone(String value, String? countryCode) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 7 && digits.length <= phoneMaxDigits(countryCode);
}
