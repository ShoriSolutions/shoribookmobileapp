import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/directions.dart';
import '../../../core/utils/open_now.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/osm_map.dart';
import '../../../models/business.dart';
import '../../../models/service.dart';
import '../../../routing/route_paths.dart';
import '../../favorites/presentation/widgets/favorite_button.dart';
import '../application/marketplace_providers.dart';
import 'widgets/category_visuals.dart';

/// C04 · Business profile — booking-first: gradient hero, name + status
/// chips, WhatsApp/Call, about, a tap-to-book services list and a sticky
/// Book bar. Every service row jumps straight into the booking flow.
class BusinessProfileScreen extends ConsumerWidget {
  final String slug;

  /// When true this is the owner previewing their own public page; the
  /// booking actions are disabled and a preview banner is shown.
  final bool isPreview;

  const BusinessProfileScreen({
    super.key,
    required this.slug,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(businessProfileProvider(slug));

    return dataAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (err, st) => Scaffold(
        body: Center(
          child: ErrorRetryView(
            message: 'Could not load this business.',
            onRetry: () => ref.invalidate(businessProfileProvider(slug)),
          ),
        ),
      ),
      data: (data) {
        if (data == null) {
          return const Scaffold(body: Center(child: Text('Business not found')));
        }
        return _Loaded(slug: slug, data: data, isPreview: isPreview);
      },
    );
  }
}

/// Opens the native share sheet for a business, passing a
/// [sharePositionOrigin] (required on iPad, harmless on iPhone) computed
/// from the tapped button so the sheet anchors correctly instead of
/// silently failing.
Future<void> _shareBusiness(BuildContext context, Business business) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : const Rect.fromLTWH(0, 0, 1, 1);
  await Share.share(
    'Check out ${business.name} on Shorivo: '
    'https://betterbooking.app/business/${business.slug}',
    sharePositionOrigin: origin,
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.slug,
    required this.data,
    required this.isPreview,
  });

  final String slug;
  final BusinessProfileData data;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final business = data.business;
    final visual = CategoryVisual.of(business.category);
    final open = isOpenNow(data.hours, business.timezone);
    final hasCoords =
        business.latitude != null && business.longitude != null;
    final canBook = !isPreview && business.bookingEnabled;
    final minPrice = data.services.isEmpty
        ? null
        : data.services.map((s) => s.price).reduce((a, b) => a < b ? a : b);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _hero(context, business, visual),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(business.name,
                      style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 10),
                  _chips(business, open),
                  const SizedBox(height: 16),
                  _contactActions(business),
                  if ((business.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(business.description!,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.muted)),
                  ],
                  if (isPreview) ...[
                    const SizedBox(height: 16),
                    _previewBanner(),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (data.services.isNotEmpty)
            _servicesSliver(context, business, canBook)
          else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('No services available yet.',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ),
          if (hasCoords || (business.address ?? '').isNotEmpty)
            SliverToBoxAdapter(
              child: _locationSection(context, business, hasCoords),
            ),
          if (data.staff.isNotEmpty)
            SliverToBoxAdapter(child: _teamSection(context, data)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: (canBook && data.services.isNotEmpty)
          ? _bookBar(context, business, minPrice)
          : null,
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────
  Widget _hero(BuildContext context, Business business, CategoryVisual visual) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 210,
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      automaticallyImplyLeading: false,
      leadingWidth: 64,
      leading: context.canPop()
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _HeroCircleButton(
                icon: Icons.arrow_back,
                onTap: () => context.pop(),
              ),
            )
          : null,
      actions: [
        Builder(
          builder: (ctx) => _HeroCircleButton(
            icon: Icons.ios_share,
            onTap: () => _shareBusiness(ctx, business),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FavoriteButton(business: business),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: business.coverImageUrl != null
            ? CachedNetworkImage(
                imageUrl: business.coverImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => _heroGradient(visual),
              )
            : _heroGradient(visual),
      ),
    );
  }

  Widget _heroGradient(CategoryVisual visual) {
    return Container(
      decoration: BoxDecoration(gradient: visual.gradient),
      alignment: Alignment.center,
      child: Icon(visual.icon, color: Colors.white, size: 64),
    );
  }

  Widget _chips(Business business, bool? open) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (business.category != null)
          _Pill(
            label: BusinessCategory.labelFor(business.category).split(' / ').first,
            bg: AppColors.parchment,
            fg: AppColors.muted,
          ),
        if (open != null)
          _Pill(
            label: open ? 'Open now' : 'Closed',
            bg: open ? AppColors.successBg : AppColors.closedBg,
            fg: open ? AppColors.successText : AppColors.closedText,
          ),
        if ((business.address ?? '').isNotEmpty)
          _Pill(
            label: business.address!,
            bg: AppColors.fieldMuted,
            fg: AppColors.muted,
            icon: Icons.location_on_outlined,
          ),
      ],
    );
  }

  Widget _contactActions(Business business) {
    final hasWhatsApp = business.whatsappNumber != null;
    final hasPhone = business.phone != null;
    if (!hasWhatsApp && !hasPhone) return const SizedBox.shrink();
    return Row(
      children: [
        if (hasWhatsApp)
          Expanded(
            child: _ActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'WhatsApp',
              bg: AppColors.whatsapp,
              fg: Colors.white,
              onTap: () => launchUrl(
                Uri.parse(
                    'https://wa.me/${business.whatsappNumber!.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        if (hasWhatsApp && hasPhone) const SizedBox(width: 12),
        if (hasPhone)
          Expanded(
            child: _ActionButton(
              icon: Icons.call_outlined,
              label: 'Call',
              bg: AppColors.sageLight,
              fg: AppColors.sageDark,
              onTap: () => launchUrl(Uri.parse('tel:${business.phone}')),
            ),
          ),
      ],
    );
  }

  Widget _previewBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sageTintBorder),
      ),
      child: const Text(
        '👀 Preview — this is how your public profile looks to customers.',
        style: TextStyle(color: AppColors.sageDark, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Services ─────────────────────────────────────────────────────────
  Widget _servicesSliver(
      BuildContext context, Business business, bool canBook) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('Services',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                Text(canBook ? 'Tap to book' : 'Services',
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.muted)),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList.separated(
            itemCount: data.services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (c, i) => _ServiceRow(
              service: data.services[i],
              currency: business.currency,
              enabled: canBook,
              onTap: canBook
                  ? () => context.push(RoutePaths.bookingWizardService(
                      business.slug, data.services[i].id))
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookBar(BuildContext context, Business business, double? minPrice) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        boxShadow: [
          BoxShadow(
              color: Color(0x0D1E1B16), blurRadius: 18, offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () =>
                context.push(RoutePaths.bookingWizard(business.slug)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Book appointment',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                if (minPrice != null) ...[
                  const SizedBox(width: 8),
                  Text('· from ${formatCurrency(minPrice, business.currency)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Secondary sections (kept for real data) ──────────────────────────
  Widget _locationSection(
      BuildContext context, Business business, bool hasCoords) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: _Card(
        title: 'Location',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((business.address ?? '').isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: AppColors.sage),
                  const SizedBox(width: 8),
                  Expanded(child: Text(business.address!)),
                ],
              ),
            if (hasCoords) ...[
              const SizedBox(height: 12),
              MapPreview(
                point: LatLng(business.latitude!, business.longitude!),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    directionsUrl(business.latitude!, business.longitude!),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('Get directions'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamSection(BuildContext context, BusinessProfileData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _Card(
        title: 'Meet the team',
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final s in data.staff)
              SizedBox(
                width: 88,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.sageLight,
                      foregroundColor: AppColors.sageDark,
                      backgroundImage: s.profileImageUrl != null
                          ? NetworkImage(s.profileImageUrl!)
                          : null,
                      child: s.profileImageUrl == null
                          ? Text(
                              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700))
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (s.role != null)
                      Text(s.role!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Pieces ─────────────────────────────────────────────────────────────

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.currency,
    required this.enabled,
    required this.onTap,
  });

  final Service service;
  final String currency;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.parchment),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    if (service.durationMinutes > 0) ...[
                      const SizedBox(height: 2),
                      Text('${service.durationMinutes} min'
                          '${service.depositRequired ? ' · deposit' : ''}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
              Text(formatCurrency(service.price, currency),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sageDark)),
              if (enabled) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppColors.faint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style:
                  TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HeroCircleButton extends StatelessWidget {
  const _HeroCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
