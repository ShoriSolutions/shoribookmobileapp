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
import '../../../core/utils/timezone_offsets.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/osm_map.dart';
import '../../../models/availability_models.dart';
import '../../../models/service.dart';
import '../../../routing/route_paths.dart';
import '../../favorites/presentation/widgets/favorite_button.dart';
import '../application/marketplace_providers.dart';

class BusinessProfileScreen extends ConsumerWidget {
  final String slug;

  /// When true this is the owner previewing their own public page; the
  /// "Book" action is disabled and a preview banner is shown.
  final bool isPreview;

  const BusinessProfileScreen({
    super.key,
    required this.slug,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(businessProfileProvider(slug));

    return Scaffold(
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: ErrorRetryView(
            message: 'Could not load this business.',
            onRetry: () => ref.invalidate(businessProfileProvider(slug)),
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Business not found'));
          }
          final business = data.business;
          final isOpenNow = _computeIsOpenNow(data.hours, business.timezone);
          final hasCoords =
              business.latitude != null && business.longitude != null;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: AppColors.cream,
                foregroundColor: AppColors.ink,
                automaticallyImplyLeading: false,
                leading: context.canPop()
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                          ),
                          onPressed: () => context.pop(),
                        ),
                      )
                    : null,
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                      onPressed: () => Share.share(
                        'Check out ${business.name} on BetterBooking: '
                        'https://betterbooking.app/business/${business.slug}',
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: business.coverImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: business.coverImageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.ink, AppColors.sageDark],
                            ),
                          ),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  business.name,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (business.category != null)
                                      _Pill(
                                        label: business.category!.replaceAll(
                                          '_',
                                          ' ',
                                        ),
                                        color: AppColors.parchment,
                                        textColor: AppColors.muted,
                                      ),
                                    _Pill(
                                      label: isOpenNow ? 'Open now' : 'Closed',
                                      color: isOpenNow
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF3F4F6),
                                      textColor: isOpenNow
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF374151),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          FavoriteButton(business: business),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (business.whatsappNumber != null)
                            _ContactButton(
                              label: 'WhatsApp',
                              color: const Color(0xFF25D366),
                              onTap: () => launchUrl(
                                Uri.parse(
                                  'https://wa.me/${business.whatsappNumber!.replaceAll(RegExp(r'[^0-9+]'), '')}',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          if (business.phone != null)
                            _ContactButton(
                              label: 'Call',
                              color: AppColors.sage,
                              onTap: () =>
                                  launchUrl(Uri.parse('tel:${business.phone}')),
                            ),
                          if (business.email != null)
                            _ContactButton(
                              label: 'Email',
                              color: AppColors.parchment,
                              textColor: AppColors.ink,
                              onTap: () => launchUrl(
                                Uri.parse('mailto:${business.email}'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isPreview)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.sageLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '👀 Preview — this is how your public profile looks '
                            'to customers.',
                            style: TextStyle(color: AppColors.sageDark),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (isPreview || !business.bookingEnabled)
                              ? null
                              : () => context.push(
                                  RoutePaths.bookingWizard(business.slug),
                                ),
                          child: Text(
                            isPreview
                                ? 'Booking (disabled in preview)'
                                : business.bookingEnabled
                                    ? '📅 Book an Appointment'
                                    : 'Not accepting bookings',
                          ),
                        ),
                      ),
                      if ((business.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: 'About',
                          child: Text(business.description!),
                        ),
                      ],
                      if (business.galleryUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Photos',
                          child: SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: business.galleryUrls.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (c, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: business.galleryUrls[i],
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (data.services.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ServicesSection(
                          services: data.services,
                          currency: business.currency,
                        ),
                      ],
                      if (data.hours.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _HoursSection(hours: data.hours),
                      ],
                      if ((business.address ?? '').isNotEmpty ||
                          business.googleMapsUrl != null ||
                          hasCoords) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Location',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((business.address ?? '').isNotEmpty)
                                Text('📍 ${business.address}'),
                              if (hasCoords) ...[
                                const SizedBox(height: 10),
                                MapPreview(
                                  point: LatLng(
                                    business.latitude!,
                                    business.longitude!,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => launchUrl(
                                      directionsUrl(
                                        business.latitude!,
                                        business.longitude!,
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    icon: const Icon(
                                      Icons.directions,
                                      color: Colors.white,
                                    ),
                                    label: const Text('Get directions'),
                                  ),
                                ),
                              ],
                              if (business.googleMapsUrl != null) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => launchUrl(
                                    Uri.parse(business.googleMapsUrl!),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  child: const Text('View on Google Maps →'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (data.staff.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Meet the Team',
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              for (final s in data.staff)
                                SizedBox(
                                  width: 140,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.sageLight,
                                        foregroundColor: AppColors.sageDark,
                                        backgroundImage:
                                            s.profileImageUrl != null
                                            ? NetworkImage(s.profileImageUrl!)
                                            : null,
                                        child: s.profileImageUrl == null
                                            ? Text(
                                                s.name.isNotEmpty
                                                    ? s.name[0].toUpperCase()
                                                    : '?',
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        s.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      if (s.role != null)
                                        Text(
                                          s.role!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.muted,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _computeIsOpenNow(List<BusinessHours> hours, String timezone) {
    final local = utcToBusinessLocal(DateTime.now().toUtc(), timezone);
    // BusinessHours.dayOfWeek: 0=Sunday..6=Saturday; DateTime.weekday:
    // 1=Monday..7=Sunday — converting to the 0=Sunday convention below.
    final dayOfWeek = local.weekday % 7;
    final todayEntry = hours.where((h) => h.dayOfWeek == dayOfWeek);
    if (todayEntry.isEmpty) return false;
    final entry = todayEntry.first;
    if (entry.isClosed || entry.openTime == null || entry.closeTime == null) {
      return false;
    }
    final nowMin = local.hour * 60 + local.minute;
    final openParts = entry.openTime!.split(':');
    final closeParts = entry.closeTime!.split(':');
    final openMin = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeMin = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
    return nowMin >= openMin && nowMin < closeMin;
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ContactButton({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
      ),
      child: Text(label),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  final List<Service> services;
  final String currency;

  const _ServicesSection({required this.services, required this.currency});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Services',
      child: Column(
        children: [
          for (int i = 0; i < services.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          services[i].name,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (services[i].durationMinutes > 0)
                          Text(
                            '${services[i].durationMinutes} min',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrency(services[i].price, currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.sageDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HoursSection extends StatelessWidget {
  final List<BusinessHours> hours;

  const _HoursSection({required this.hours});

  static const _order = [1, 2, 3, 4, 5, 6, 0]; // Mon..Sun

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Business Hours',
      child: Column(
        children: [
          for (final dow in _order)
            Builder(
              builder: (context) {
                final entry = hours.where((h) => h.dayOfWeek == dow);
                final e = entry.isNotEmpty ? entry.first : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(weekdayLabels[dow]),
                      Text(
                        (e == null || e.isClosed)
                            ? 'Closed'
                            : '${_fmt(e.openTime)} – ${_fmt(e.closeTime)}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _fmt(String? time) {
    if (time == null) return '';
    final parts = time.split(':');
    final h = int.parse(parts[0]);
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $ampm';
  }
}
