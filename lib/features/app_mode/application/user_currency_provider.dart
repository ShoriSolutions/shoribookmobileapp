import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import 'app_mode_provider.dart';

/// The signed-in user's saved country and the currency that goes with it.
///
/// Source of truth is their PROFILE (`profiles.country_code`, edited in
/// Profile > address) -- never GPS. Because [myProfileProvider] watches the
/// auth status, this clears on sign-out and reloads for the next user, so one
/// account's currency can never linger for another.
///
/// IMPORTANT -- this is for DEFAULTS ONLY (e.g. which currency to show
/// subscription plans in). It must NEVER be used to display a provider's
/// service price: those are stored in the provider's own currency and the app
/// has no live exchange rates, so re-labelling them would misstate the price.
/// Service/booking prices always use the currency stored with them.
final userCountryCodeProvider = Provider<String?>((ref) {
  final code = ref.watch(myProfileProvider).valueOrNull?.address.countryCode;
  return (code == null || code.trim().isEmpty) ? null : code.trim();
});

/// Currency for the user's saved country, falling back to [kDefaultCurrency]
/// when they have no country saved or it isn't one we know.
final userCurrencyProvider = Provider<String>((ref) {
  return currencyForCountry(ref.watch(userCountryCodeProvider));
});
