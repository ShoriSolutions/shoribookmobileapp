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

/// E.164 dialling prefix for a country (ISO 3166-1 alpha-2), e.g. 'BB' ->
/// '+1246'. NANP territories carry their specific area code so the number is
/// dialable as-is. Returns null for regions we don't have a code for (no
/// prefill then). Centralised so every phone field can prefill the same way.
const Map<String, String> _dialCodes = {
  // NANP (+1) — each Caribbean territory has its own area code.
  'US': '+1', 'CA': '+1',
  'BB': '+1246', 'JM': '+1876', 'TT': '+1868', 'BS': '+1242', 'AG': '+1268',
  'LC': '+1758', 'VC': '+1784', 'GD': '+1473', 'DM': '+1767', 'KN': '+1869',
  'AI': '+1264', 'VG': '+1284', 'KY': '+1345', 'TC': '+1649', 'MS': '+1664',
  'BM': '+1441', 'PR': '+1787', 'DO': '+1809', 'SX': '+1721',
  // Non-NANP neighbours + common regions.
  'GP': '+590', 'MF': '+590', 'GY': '+592', 'SR': '+597', 'HT': '+509',
  'GB': '+44',
};

String? dialCodeForCountry(String? countryCode) =>
    _dialCodes[(countryCode ?? '').toUpperCase()];

/// The initial text for an empty phone field: the country's dial code plus a
/// trailing space so the user types straight into the local number. Falls back
/// to an empty string when the region has no known code.
String phonePrefill(String? countryCode) {
  final code = dialCodeForCountry(countryCode);
  return code == null ? '' : '$code ';
}

/// A phone field's value ready to persist: null when it's empty or contains
/// nothing beyond the dial code (i.e. the prefill was left untouched), so we
/// never store a bare '+1246'.
String? phoneForSave(String value, String? countryCode) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  final codeDigits =
      (dialCodeForCountry(countryCode) ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  // Only the dial code (or fewer digits) => the user never entered a number.
  if (digits.length <= codeDigits.length) return null;
  return trimmed;
}

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
