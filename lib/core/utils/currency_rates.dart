/// Display-only currency conversion for subscription prices. Prices are
/// stored in BBD; this converts to a chosen currency for display. These are
/// approximate estimates — the real charge for a paid plan comes from the
/// App Store / Play in the store's own localized currency at purchase.
class CurrencyRates {
  const CurrencyRates._();

  /// Supported currencies: code → (label, symbol, USD→currency rate).
  /// [rate] is how many of this currency equal 1 USD, used as a cross-rate
  /// so any currency can convert to any other.
  static const Map<String, ({String label, String symbol, double rate})>
      currencies = {
    'USD': (label: 'US Dollar', symbol: r'$', rate: 1.0),
    'BBD': (label: 'Barbadian Dollar', symbol: r'Bds$', rate: 2.0),
    'XCD': (label: 'East Caribbean Dollar', symbol: r'EC$', rate: 2.70),
    'JMD': (label: 'Jamaican Dollar', symbol: r'J$', rate: 156.0),
    'TTD': (label: 'Trinidad & Tobago Dollar', symbol: r'TT$', rate: 6.78),
    'BSD': (label: 'Bahamian Dollar', symbol: r'B$', rate: 1.0),
    'GYD': (label: 'Guyanese Dollar', symbol: r'G$', rate: 209.0),
    'GBP': (label: 'British Pound', symbol: '£', rate: 0.79),
    'EUR': (label: 'Euro', symbol: '€', rate: 0.92),
    'CAD': (label: 'Canadian Dollar', symbol: r'CA$', rate: 1.37),
    'AUD': (label: 'Australian Dollar', symbol: r'A$', rate: 1.52),
  };

  /// ISO country code → its display currency (falls back to USD).
  static const Map<String, String> _countryCurrency = {
    'US': 'USD', 'BB': 'BBD', 'JM': 'JMD', 'TT': 'TTD', 'BS': 'BSD',
    'GY': 'GYD', 'GB': 'GBP', 'CA': 'CAD', 'AU': 'AUD',
    // East Caribbean Dollar countries
    'GD': 'XCD', 'LC': 'XCD', 'VC': 'XCD', 'AG': 'XCD', 'DM': 'XCD',
    'KN': 'XCD', 'AI': 'XCD', 'MS': 'XCD',
    // Eurozone (a few)
    'IE': 'EUR', 'FR': 'EUR', 'DE': 'EUR', 'ES': 'EUR', 'IT': 'EUR',
  };

  static String currencyForCountry(String? countryCode) =>
      _countryCurrency[(countryCode ?? '').toUpperCase()] ?? 'USD';

  static bool isSupported(String code) => currencies.containsKey(code);

  static double _rate(String code) => currencies[code]?.rate ?? 1.0;

  /// Converts [amount] from one currency to another via a USD cross-rate.
  static double convert(double amount, String from, String to) =>
      (amount / _rate(from)) * _rate(to);

  /// Formats [amount] (given in [from]) shown in [to], e.g. 10 BBD → "$5.00"
  /// (USD) or "£3.95" (GBP). Defaults the base to BBD.
  static String format(double amount, String to, {String from = 'BBD'}) {
    final v = convert(amount, from, to);
    final c = currencies[to] ?? currencies['BBD']!;
    final whole = v >= 1000 || to == 'JMD' || to == 'GYD';
    final n = whole ? _withCommas(v.round()) : v.toStringAsFixed(2);
    return '${c.symbol}$n';
  }

  static String _withCommas(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}
