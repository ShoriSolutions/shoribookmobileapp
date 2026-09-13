import 'package:intl/intl.dart';

import 'currency_rates.dart';

/// THE single place the app formats money. Screens should never build a price
/// string by hand or hardcode a currency symbol.
///
/// Two rules matter here:
///
///  * **A price belongs to the provider.** A service is stored with the
///    currency the business charges in (`services.currency`, defaulting to the
///    business's `currency`), and a booking snapshots both price and currency
///    when it is made. The app has no live exchange rates, so a price is
///    always shown in the currency it was stored in -- never re-labelled into
///    the viewer's currency, which would misstate what they actually pay.
///  * **A service that costs nothing reads "Free"**, not "BBD 0.00".
///
/// Use [formatPrice] for what a service or booking costs, and [formatCurrency]
/// for money amounts (revenue, deposits, totals) where zero means "no money",
/// not "free".

/// The home currency, used when nothing else says otherwise. Businesses
/// default to this too (`businesses.currency`).
const String kDefaultCurrency = 'BBD';

/// What a zero-cost service is called.
const String kFreeLabel = 'Free';

/// Formats a money amount in [currencyCode] (defaults to [kDefaultCurrency]),
/// e.g. `BBD 30.00`. Zero formats as `BBD 0.00`; for a service price use
/// [formatPrice] so it reads "Free" instead.
String formatCurrency(num? amount, String? currencyCode) {
  final code = (currencyCode == null || currencyCode.trim().isEmpty)
      ? kDefaultCurrency
      : currencyCode.trim();
  final format = NumberFormat.currency(
    name: code,
    symbol: '$code ',
    decimalDigits: 2,
  );
  return format.format(amount ?? 0);
}

/// Formats what a service or booking costs. A price of exactly zero reads
/// "Free" in any currency; anything else formats like [formatCurrency].
///
/// A null price means "unknown", not "free", so it falls through to
/// [formatCurrency].
String formatPrice(num? amount, String? currencyCode,
        {String freeLabel = kFreeLabel}) =>
    isFreePrice(amount) ? freeLabel : formatCurrency(amount, currencyCode);

/// True when a service costs nothing (for badges and labels).
bool isFreePrice(num? amount) => amount != null && amount == 0;

/// The default currency for an ISO 3166-1 alpha-2 country, e.g. 'BB' -> 'BBD',
/// falling back to [kDefaultCurrency] when the country is missing or unknown.
///
/// DEFAULTS ONLY: this picks which currency to prefer where there is a genuine
/// choice (such as which currency to show subscription plans in). It never
/// converts or re-labels a provider's stored price. The country -> currency
/// table lives in [CurrencyRates] so there is one copy of it.
String currencyForCountry(String? countryCode) =>
    CurrencyRates.lookupCountryCurrency(countryCode) ?? kDefaultCurrency;
