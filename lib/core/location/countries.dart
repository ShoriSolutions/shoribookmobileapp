// ISO 3166-1 country data + per-country address conventions. Caribbean
// countries are listed first for convenience; the rest follow for
// worldwide expansion. Flags are derived from the ISO code (regional
// indicator symbols), so only code + name are stored here.

/// A country by ISO 3166-1 alpha-2 code.
class Country {
  final String code; // e.g. 'BB'
  final String name; // e.g. 'Barbados'
  const Country(this.code, this.name);

  /// 🇧🇧 — built from the alpha-2 code's regional indicator symbols.
  String get flag => code.toUpperCase().codeUnits
      .map((c) => String.fromCharCode(0x1F1E6 + (c - 65)))
      .join();
}

/// How an address is worded/validated in a given country. Falls back to a
/// neutral default so unlisted countries still work (worldwide-ready).
class AddressConfig {
  /// Label for the top administrative division (Parish/State/Province/…).
  final String adminLabel;

  /// Whether a postal/ZIP code is used. When false, the field is hidden.
  final bool usesPostalCode;

  /// Label for the postal field (Postal code / ZIP code / Postcode).
  final String postalLabel;

  const AddressConfig({
    required this.adminLabel,
    this.usesPostalCode = true,
    this.postalLabel = 'Postal code',
  });
}

const AddressConfig _defaultConfig = AddressConfig(
  adminLabel: 'State / Province / Region',
  usesPostalCode: true,
);

/// Per-country overrides. Anything not listed uses [_defaultConfig].
const Map<String, AddressConfig> _configs = {
  // Caribbean
  'BB': AddressConfig(adminLabel: 'Parish', usesPostalCode: true),
  'JM': AddressConfig(adminLabel: 'Parish', usesPostalCode: false),
  'TT': AddressConfig(adminLabel: 'Region', usesPostalCode: false),
  'GD': AddressConfig(adminLabel: 'Parish', usesPostalCode: false),
  'LC': AddressConfig(adminLabel: 'Quarter', usesPostalCode: false),
  'VC': AddressConfig(adminLabel: 'Parish', usesPostalCode: false),
  'AG': AddressConfig(adminLabel: 'Parish', usesPostalCode: false),
  'DM': AddressConfig(adminLabel: 'Parish', usesPostalCode: false),
  'KN': AddressConfig(adminLabel: 'Parish', usesPostalCode: false),
  'BS': AddressConfig(adminLabel: 'Island / District', usesPostalCode: false),
  'GY': AddressConfig(adminLabel: 'Region', usesPostalCode: false),
  'SR': AddressConfig(adminLabel: 'District', usesPostalCode: false),
  'BZ': AddressConfig(adminLabel: 'District', usesPostalCode: false),
  'HT': AddressConfig(adminLabel: 'Department', usesPostalCode: true),
  'DO': AddressConfig(adminLabel: 'Province', usesPostalCode: true),
  'PR': AddressConfig(adminLabel: 'Municipality', usesPostalCode: true, postalLabel: 'ZIP code'),
  // Majors with distinct conventions
  'US': AddressConfig(adminLabel: 'State', usesPostalCode: true, postalLabel: 'ZIP code'),
  'CA': AddressConfig(adminLabel: 'Province', usesPostalCode: true),
  'GB': AddressConfig(adminLabel: 'County', usesPostalCode: true, postalLabel: 'Postcode'),
  'AU': AddressConfig(adminLabel: 'State / Territory', usesPostalCode: true, postalLabel: 'Postcode'),
  'IE': AddressConfig(adminLabel: 'County', usesPostalCode: true, postalLabel: 'Eircode'),
  'IN': AddressConfig(adminLabel: 'State', usesPostalCode: true, postalLabel: 'PIN code'),
};

/// Address conventions for [code] (case-insensitive), or the default.
AddressConfig addressConfigFor(String? code) =>
    _configs[(code ?? '').toUpperCase()] ?? _defaultConfig;

/// Caribbean countries, shown first in pickers.
const List<Country> kCaribbeanCountries = [
  Country('BB', 'Barbados'),
  Country('JM', 'Jamaica'),
  Country('TT', 'Trinidad & Tobago'),
  Country('GD', 'Grenada'),
  Country('LC', 'Saint Lucia'),
  Country('VC', 'Saint Vincent & the Grenadines'),
  Country('AG', 'Antigua & Barbuda'),
  Country('DM', 'Dominica'),
  Country('KN', 'Saint Kitts & Nevis'),
  Country('BS', 'Bahamas'),
  Country('GY', 'Guyana'),
  Country('SR', 'Suriname'),
  Country('BZ', 'Belize'),
  Country('HT', 'Haiti'),
  Country('DO', 'Dominican Republic'),
  Country('CU', 'Cuba'),
  Country('PR', 'Puerto Rico'),
  Country('KY', 'Cayman Islands'),
  Country('VG', 'British Virgin Islands'),
  Country('VI', 'US Virgin Islands'),
  Country('AI', 'Anguilla'),
  Country('MS', 'Montserrat'),
  Country('TC', 'Turks & Caicos Islands'),
  Country('AW', 'Aruba'),
  Country('CW', 'Curaçao'),
  Country('SX', 'Sint Maarten'),
];

/// Everything else, alphabetical. Not exhaustive of all 249 ISO entries,
/// but broad; add rows here to expand — no other code changes needed.
const List<Country> kOtherCountries = [
  Country('AF', 'Afghanistan'),
  Country('AL', 'Albania'),
  Country('DZ', 'Algeria'),
  Country('AR', 'Argentina'),
  Country('AM', 'Armenia'),
  Country('AT', 'Austria'),
  Country('AU', 'Australia'),
  Country('AZ', 'Azerbaijan'),
  Country('BH', 'Bahrain'),
  Country('BD', 'Bangladesh'),
  Country('BE', 'Belgium'),
  Country('BJ', 'Benin'),
  Country('BO', 'Bolivia'),
  Country('BA', 'Bosnia & Herzegovina'),
  Country('BW', 'Botswana'),
  Country('BR', 'Brazil'),
  Country('BG', 'Bulgaria'),
  Country('BF', 'Burkina Faso'),
  Country('KH', 'Cambodia'),
  Country('CM', 'Cameroon'),
  Country('CA', 'Canada'),
  Country('CL', 'Chile'),
  Country('CN', 'China'),
  Country('CO', 'Colombia'),
  Country('CR', 'Costa Rica'),
  Country('HR', 'Croatia'),
  Country('CY', 'Cyprus'),
  Country('CZ', 'Czechia'),
  Country('DK', 'Denmark'),
  Country('EC', 'Ecuador'),
  Country('EG', 'Egypt'),
  Country('SV', 'El Salvador'),
  Country('EE', 'Estonia'),
  Country('ET', 'Ethiopia'),
  Country('FI', 'Finland'),
  Country('FR', 'France'),
  Country('GE', 'Georgia'),
  Country('DE', 'Germany'),
  Country('GH', 'Ghana'),
  Country('GR', 'Greece'),
  Country('GT', 'Guatemala'),
  Country('HN', 'Honduras'),
  Country('HK', 'Hong Kong'),
  Country('HU', 'Hungary'),
  Country('IS', 'Iceland'),
  Country('IN', 'India'),
  Country('ID', 'Indonesia'),
  Country('IE', 'Ireland'),
  Country('IL', 'Israel'),
  Country('IT', 'Italy'),
  Country('CI', "Côte d'Ivoire"),
  Country('JP', 'Japan'),
  Country('JO', 'Jordan'),
  Country('KZ', 'Kazakhstan'),
  Country('KE', 'Kenya'),
  Country('KW', 'Kuwait'),
  Country('LV', 'Latvia'),
  Country('LB', 'Lebanon'),
  Country('LT', 'Lithuania'),
  Country('LU', 'Luxembourg'),
  Country('MY', 'Malaysia'),
  Country('MT', 'Malta'),
  Country('MX', 'Mexico'),
  Country('MA', 'Morocco'),
  Country('NL', 'Netherlands'),
  Country('NZ', 'New Zealand'),
  Country('NI', 'Nicaragua'),
  Country('NG', 'Nigeria'),
  Country('NO', 'Norway'),
  Country('OM', 'Oman'),
  Country('PK', 'Pakistan'),
  Country('PA', 'Panama'),
  Country('PY', 'Paraguay'),
  Country('PE', 'Peru'),
  Country('PH', 'Philippines'),
  Country('PL', 'Poland'),
  Country('PT', 'Portugal'),
  Country('QA', 'Qatar'),
  Country('RO', 'Romania'),
  Country('RU', 'Russia'),
  Country('RW', 'Rwanda'),
  Country('SA', 'Saudi Arabia'),
  Country('SN', 'Senegal'),
  Country('RS', 'Serbia'),
  Country('SG', 'Singapore'),
  Country('SK', 'Slovakia'),
  Country('SI', 'Slovenia'),
  Country('ZA', 'South Africa'),
  Country('KR', 'South Korea'),
  Country('ES', 'Spain'),
  Country('LK', 'Sri Lanka'),
  Country('SE', 'Sweden'),
  Country('CH', 'Switzerland'),
  Country('TW', 'Taiwan'),
  Country('TZ', 'Tanzania'),
  Country('TH', 'Thailand'),
  Country('TN', 'Tunisia'),
  Country('TR', 'Türkiye'),
  Country('UG', 'Uganda'),
  Country('UA', 'Ukraine'),
  Country('AE', 'United Arab Emirates'),
  Country('GB', 'United Kingdom'),
  Country('US', 'United States'),
  Country('UY', 'Uruguay'),
  Country('VE', 'Venezuela'),
  Country('VN', 'Vietnam'),
  Country('ZM', 'Zambia'),
  Country('ZW', 'Zimbabwe'),
];

/// Caribbean first, then the rest — the canonical picker order.
const List<Country> kAllCountries = [
  ...kCaribbeanCountries,
  ...kOtherCountries,
];

/// Look up a country by ISO code (case-insensitive).
Country? countryByCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final up = code.toUpperCase();
  for (final c in kAllCountries) {
    if (c.code == up) return c;
  }
  return null;
}
