import 'package:flutter_test/flutter_test.dart';
import 'package:shorivo/core/utils/currency_formatter.dart';

void main() {
  group('formatPrice — what a customer sees for a service price', () {
    test('a zero price reads "Free", in any currency', () {
      expect(formatPrice(0, 'BBD'), 'Free');
      expect(formatPrice(0, 'USD'), 'Free');
      expect(formatPrice(0.0, 'GBP'), 'Free');
      expect(formatPrice(0, null), 'Free');
    });

    test('a normal price is unchanged, in the currency it is stored in', () {
      expect(formatPrice(30, 'BBD'), 'BBD 30.00');
      expect(formatPrice(30, 'USD'), 'USD 30.00');
      expect(formatPrice(12.5, 'BBD'), 'BBD 12.50');
    });

    test('no currency falls back to the home currency', () {
      expect(formatPrice(30, null), 'BBD 30.00');
      expect(formatPrice(30, ''), 'BBD 30.00');
    });

    test('an unknown price is not called "Free"', () {
      // null means "we do not know", which is different from "costs nothing".
      expect(formatPrice(null, 'BBD'), 'BBD 0.00');
    });

    test('a tiny price is not rounded down to Free', () {
      expect(formatPrice(0.01, 'BBD'), 'BBD 0.01');
    });
  });

  group('formatCurrency — money amounts (revenue, deposits, totals)', () {
    test('zero stays numeric: "no revenue" is not "Free"', () {
      expect(formatCurrency(0, 'BBD'), 'BBD 0.00');
      expect(formatCurrency(null, 'BBD'), 'BBD 0.00');
    });

    test('formats normally', () {
      expect(formatCurrency(1234.5, 'BBD'), 'BBD 1,234.50');
      expect(formatCurrency(30, 'USD'), 'USD 30.00');
    });
  });

  group('currencyForCountry — defaults only, never a conversion', () {
    test('maps the countries the app serves', () {
      expect(currencyForCountry('BB'), 'BBD');
      expect(currencyForCountry('US'), 'USD');
      expect(currencyForCountry('GB'), 'GBP');
      expect(currencyForCountry('CA'), 'CAD');
      expect(currencyForCountry('bb'), 'BBD'); // case-insensitive
    });

    test('missing or unknown country falls back to the home currency', () {
      expect(currencyForCountry(null), kDefaultCurrency);
      expect(currencyForCountry(''), kDefaultCurrency);
      expect(currencyForCountry('ZZ'), kDefaultCurrency);
      expect(kDefaultCurrency, 'BBD');
    });
  });
}
