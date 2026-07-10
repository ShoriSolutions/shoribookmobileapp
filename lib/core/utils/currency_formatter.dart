import 'package:intl/intl.dart';

/// Formats a numeric amount using the business's own currency code
/// (default BBD), never a hardcoded symbol — matches the multi-currency
/// support already present in the `businesses`/`services` schema.
String formatCurrency(num? amount, String? currencyCode) {
  final code = (currencyCode == null || currencyCode.isEmpty)
      ? 'BBD'
      : currencyCode;
  final format = NumberFormat.currency(
    name: code,
    symbol: '$code ',
    decimalDigits: 2,
  );
  return format.format(amount ?? 0);
}
