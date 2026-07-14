import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/subscription_package.dart';
import '../../../models/trial_eligibility.dart';

/// One place for everything subscription-related: reading the dynamic
/// package catalog and trial state from the DB, and driving the App Store /
/// Play in-app-purchase flow. UI never touches Supabase or the store
/// plugin directly.
class SubscriptionRepository {
  final SupabaseClient _client;
  final InAppPurchase _iap = InAppPurchase.instance;

  SubscriptionRepository(this._client);

  // ── Dynamic catalog (DB) ────────────────────────────────────────────────
  Future<List<SubscriptionPackage>> fetchPackages() async {
    try {
      final data = await _client
          .from('subscription_packages')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      return (data as List)
          .map((e) => SubscriptionPackage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<TrialEligibility> checkTrialEligibility(String businessId) async {
    try {
      final res = await _client
          .rpc('check_trial_eligibility', params: {'p_business_id': businessId});
      return TrialEligibility.fromJson((res as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<TrialEligibility> startTrial(String businessId) async {
    try {
      final res =
          await _client.rpc('start_trial', params: {'p_business_id': businessId});
      return TrialEligibility.fromJson((res as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Grants the entitlement after a completed store purchase. (Production:
  /// move receipt verification to an Edge Function before granting.)
  Future<void> recordPurchase({
    required String businessId,
    required String packageId,
    required String store,
    required String token,
    DateTime? periodEnd,
  }) async {
    try {
      await _client.rpc('record_subscription_purchase', params: {
        'p_business_id': businessId,
        'p_package_id': packageId,
        'p_store': store,
        'p_token': token,
        'p_period_end': periodEnd?.toIso8601String(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Store in-app purchase ───────────────────────────────────────────────
  Future<bool> storeAvailable() => _iap.isAvailable();

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  String get storeName => Platform.isIOS ? 'apple' : 'google';

  /// The store product id for the current platform, if the package carries
  /// one.
  String? storeProductId(SubscriptionPackage p) =>
      Platform.isIOS ? p.storeProductIdIos : p.storeProductIdAndroid;

  /// Looks up the store's live product details (localized price, etc.) for
  /// the given packages, keyed by store product id. Empty if the store is
  /// unavailable or none of the ids are configured yet.
  Future<Map<String, ProductDetails>> queryProducts(
      Iterable<SubscriptionPackage> packages) async {
    final ids = packages.map(storeProductId).whereType<String>().toSet();
    if (ids.isEmpty) return {};
    final resp = await _iap.queryProductDetails(ids);
    return {for (final pd in resp.productDetails) pd.id: pd};
  }

  Future<void> buy(ProductDetails product) => _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  Future<void> restorePurchases() => _iap.restorePurchases();
}
