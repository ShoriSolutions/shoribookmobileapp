/// Display-only currency conversion for subscription prices. Prices are
/// stored in USD; this converts to a chosen currency for display. These are
/// approximate estimates — the real charge for a paid plan comes from the
/// App Store / Play in the store's own localized currency at purchase.
class CurrencyRates {
  const CurrencyRates._();

  /// Supported display currencies: code → (label, symbol, USD→currency rate).
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

  /// Formats a USD amount in [currency], e.g. 10.0 → "$10.00" / "Bds$20.00".
  static String format(double usdAmount, String currency) {
    final c = currencies[currency] ?? currencies['USD']!;
    final v = usdAmount * c.rate;
    final whole = v >= 1000 || currency == 'JMD' || currency == 'GYD';
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
