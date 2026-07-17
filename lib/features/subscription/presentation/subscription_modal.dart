import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../models/subscription_package.dart';
import '../../../models/trial_eligibility.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/subscription_providers.dart';
import 'widgets/feature_list.dart';
import 'widgets/pricing_card.dart';
import 'widgets/trial_badge.dart';

/// Opens the premium subscription bottom sheet. Plans are loaded live from
/// the DB; the trial and purchase flows are server- and store-driven.
Future<void> showSubscriptionModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _SubscriptionSheet(),
  );
}

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet();

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  TrialEligibility? _eligibility;
  Map<String, ProductDetails> _products = {};
  bool _productsRequested = false;
  String? _selectedId;
  bool _busy = false;
  String? _successMessage;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  String? get _businessId =>
      ref.read(activeMembershipProvider).valueOrNull?.business.id;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadEligibility();
    _purchaseSub =
        ref.read(subscriptionRepositoryProvider).purchaseStream.listen(
              _onPurchases,
              onError: (_) {},
            );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadEligibility() async {
    final id = _businessId;
    if (id == null) return;
    try {
      final elig =
          await ref.read(subscriptionRepositoryProvider).checkTrialEligibility(id);
      if (mounted) setState(() => _eligibility = elig);
    } catch (_) {
      // Eligibility is advisory for the CTA label; ignore failures.
    }
  }

  Future<void> _loadProducts(List<SubscriptionPackage> packages) async {
    _productsRequested = true;
    try {
      final map =
          await ref.read(subscriptionRepositoryProvider).queryProducts(packages);
      if (mounted && map.isNotEmpty) setState(() => _products = map);
    } catch (_) {
      // Store may be unavailable / products not configured yet — the DB
      // fallback price is shown instead.
    }
  }

  String _priceFor(SubscriptionPackage p) {
    final repo = ref.read(subscriptionRepositoryProvider);
    final storeId = repo.storeProductId(p);
    final product = storeId == null ? null : _products[storeId];
    if (product != null) return product.price; // localized store price
    if (p.priceAmount != null) {
      return '${p.currency} ${p.priceAmount!.toStringAsFixed(2)}';
    }
    return '—';
  }

  SubscriptionPackage? _selected(List<SubscriptionPackage> packages) {
    if (packages.isEmpty) return null;
    return packages.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => packages.firstWhere((p) => p.isPopular,
          orElse: () => packages.first),
    );
  }

  Future<void> _onPrimary(List<SubscriptionPackage> packages) async {
    if (_busy) return;
    final id = _businessId;
    final pkg = _selected(packages);
    if (id == null || pkg == null) return;

    // Trial path — eligible customers start the 14-day trial (no payment).
    if (_eligibility?.isEligible ?? true) {
      setState(() => _busy = true);
      try {
        final res =
            await ref.read(subscriptionRepositoryProvider).startTrial(id);
        if (!mounted) return;
        if (res.status == TrialStatus.trialing) {
          ref.invalidate(activeMembershipProvider);
          setState(() => _successMessage = res.message);
        } else {
          // pending / ineligible — surface and update the CTA.
          setState(() => _eligibility = res);
          showAppSnackBar(context, message: res.message);
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context,
              message: AppException.from(e).message, isError: true);
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // Purchase path — start the store in-app purchase for the plan.
    await _purchase(pkg);
  }

  Future<void> _purchase(SubscriptionPackage pkg) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final storeId = repo.storeProductId(pkg);
    final product = storeId == null ? null : _products[storeId];
    if (product == null) {
      showAppSnackBar(
        context,
        message: 'Subscriptions aren’t available right now. Please try again '
            'shortly.',
        isError: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await repo.buy(product); // result arrives on the purchase stream
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final id = _businessId;
    final packages =
        ref.read(subscriptionPackagesProvider).valueOrNull ?? const [];
    final repo = ref.read(subscriptionRepositoryProvider);
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final pkg = packages.firstWhere(
            (p) => repo.storeProductId(p) == purchase.productID,
            orElse: () => packages.isNotEmpty
                ? packages.first
                : const SubscriptionPackage(id: '', name: ''),
          );
          if (id != null && pkg.id.isNotEmpty) {
            try {
              await repo.recordPurchase(
                businessId: id,
                packageId: pkg.id,
                store: repo.storeName,
                token: purchase.purchaseID ?? '',
              );
              ref.invalidate(activeMembershipProvider);
            } catch (_) {}
          }
          if (purchase.pendingCompletePurchase) {
            await repo.completePurchase(purchase);
          }
          if (mounted) {
            setState(() {
              _busy = false;
              _successMessage = 'Welcome to Pro — your subscription is active.';
            });
          }
          break;
        case PurchaseStatus.error:
          if (mounted) {
            setState(() => _busy = false);
            showAppSnackBar(context,
                message: purchase.error?.message ?? 'Purchase failed.',
                isError: true);
          }
          break;
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _busy = false);
          break;
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: _successMessage != null
            ? _SuccessView(
                message: _successMessage!,
                onDone: () => Navigator.of(context).pop(),
              )
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final packagesAsync = ref.watch(subscriptionPackagesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _GrabHandle(),
        Flexible(
          child: packagesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.sage,
                ),
              ),
            ),
            error: (_, __) => _EmptyState(
              onRetry: () => ref.invalidate(subscriptionPackagesProvider),
            ),
            data: (packages) {
              if (packages.isEmpty) {
                return _EmptyState(
                  onRetry: () => ref.invalidate(subscriptionPackagesProvider),
                );
              }
              if (!_productsRequested) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _loadProducts(packages));
              }
              return _content(context, packages);
            },
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, List<SubscriptionPackage> packages) {
    final selected = _selected(packages)!;
    final eligible = _eligibility?.isEligible ?? true;
    final primaryLabel = eligible ? 'Start Free Trial' : 'Subscribe';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Center(child: Text('🎉', style: TextStyle(fontSize: 34))),
          const SizedBox(height: 8),
          Text(
            'Start Your FREE 14-Day Trial',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Experience every premium feature free for 14 days. No credit '
            'card required to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          const Center(child: TrialBadge()),
          const SizedBox(height: 20),

          // Feature summary for the selected plan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sageLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: FeatureList(features: selected.features),
          ),
          const SizedBox(height: 20),

          // Plans (animated in, popular first)
          for (var i = 0; i < packages.length; i++)
            _StaggerIn(
              controller: _entrance,
              index: i,
              child: PricingCard(
                package: packages[i],
                selected: packages[i].id == selected.id,
                priceText: _priceFor(packages[i]),
                onTap: () => setState(() => _selectedId = packages[i].id),
              ),
            ),

          const SizedBox(height: 8),

          // CTAs
          _PressableScale(
            onPressed: _busy ? null : () => _onPrimary(packages),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      primaryLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _busy
                ? null
                : () => ref
                    .read(subscriptionRepositoryProvider)
                    .restorePurchases(),
            child: const Text('Restore purchases'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later',
                style: TextStyle(color: AppColors.muted)),
          ),
          const SizedBox(height: 4),
          Text(
            eligible
                ? 'Your trial starts today and runs for 14 days. Cancel '
                    'anytime.'
                : 'Billed through the App Store / Google Play. Cancel anytime '
                    'in your store account.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Fade + slide a child in, staggered by [index], driven by [controller].
class _StaggerIn extends StatelessWidget {
  const _StaggerIn({
    required this.controller,
    required this.index,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (0.08 * index).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - anim.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Scales its child down slightly while pressed.
class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.onPressed});
  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Opacity(opacity: enabled ? 1 : 0.7, child: widget.child),
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.parchment,
          borderRadius: BorderRadius.circular(999),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🛠️', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(
            "We're updating our subscription plans. Please try again shortly.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.message, required this.onDone});
  final String message;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.sage,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 20),
          Text("You're all set!",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(onPressed: onDone, child: const Text('Done')),
          ),
        ],
      ),
    );
  }
}
