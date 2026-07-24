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

  /// Persists the vendor's auto-renew / billing-period preference. The
  /// actual renewal charge is performed by the app store (auto-renewable
  /// IAP) or a payment-processor Edge Function — this only records intent.
  Future<void> setSubscriptionPrefs({
    required String businessId,
    bool? autoRenew,
    String? billingPeriod,
  }) async {
    try {
      await _client.rpc('set_subscription_prefs', params: {
        'p_business_id': businessId,
        'p_auto_renew': autoRenew,
        'p_billing_period': billingPeriod,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Server-side receipt verification: forwards the store receipt to the
  /// `verify-purchase` Edge Function, which validates it with Apple / Google
  /// and grants the entitlement with the store's own (trusted) expiry date.
  ///
  /// Returns true when the purchase was verified and the plan activated.
  /// Returns false when verification isn't configured on the backend yet
  /// (no store secret set) — the caller should fall back to [recordPurchase].
  /// Throws [AppException] when the receipt is present but fails validation.
  Future<bool> verifyPurchase({
    required String businessId,
    required String packageId,
    required String store,
    required String productId,
    String? receipt,
    String? purchaseToken,
  }) async {
    try {
      final res = await _client.functions.invoke('verify-purchase', body: {
        'business_id': businessId,
        'package_id': packageId,
        'store': store,
        'product_id': productId,
        if (receipt != null) 'receipt': receipt,
        if (purchaseToken != null) 'purchase_token': purchaseToken,
      });
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
      return data['success'] == true;
    } on FunctionException catch (e) {
      // 501 = the backend has no store secret configured yet → let the caller
      // fall back to the trust-the-client MVP path. Anything else (a real
      // validation failure) is surfaced.
      final details = (e.details as Map?)?.cast<String, dynamic>();
      if (e.status == 501 || details?['error'] == 'verification_not_configured') {
        return false;
      }
      throw AppException(
        (details?['message'] as String?) ??
            'We couldn\'t verify that purchase. Please try again.',
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Grants the entitlement after a completed store purchase. Used as the
  /// fallback when [verifyPurchase] reports server verification isn't set up.
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

  /// The store product id for the current platform + billing period, if the
  /// package carries one. Annual falls back to the monthly id when no annual
  /// product is configured yet.
  String? storeProductId(SubscriptionPackage p,
      {BillingPeriod period = BillingPeriod.monthly}) {
    if (period == BillingPeriod.yearly) {
      return Platform.isIOS
          ? p.storeProductIdIosAnnual
          : p.storeProductIdAndroidAnnual;
    }
    return Platform.isIOS ? p.storeProductIdIos : p.storeProductIdAndroid;
  }

  /// Looks up the store's live product details (localized price, etc.) for
  /// the given packages, keyed by store product id. Empty if the store is
  /// unavailable or none of the ids are configured yet.
  Future<Map<String, ProductDetails>> queryProducts(
      Iterable<SubscriptionPackage> packages) async {
    final ids = <String>{};
    for (final p in packages) {
      final monthly = storeProductId(p);
      final annual = storeProductId(p, period: BillingPeriod.yearly);
      if (monthly != null) ids.add(monthly);
      if (annual != null) ids.add(annual);
    }
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
