import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../routing/route_paths.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/profile_marketplace_controller.dart';
import 'widgets/share_booking_link_section.dart';

/// Controls where the business appears publicly (published profile /
/// marketplace listing / accepting bookings) and surfaces the booking
/// link. Mirrors the web dashboard's Profile & Marketplace section.
class ProfileMarketplaceScreen extends ConsumerWidget {
  const ProfileMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    if (membership == null) return const SizedBox.shrink();
    final business = membership.business;
    final canManage = can(membership.role, Permission.manageSettings);
    final saving = ref.watch(profileMarketplaceControllerProvider).isLoading;
    final url = 'https://betterbooking.app/book/${business.slug}';

    Future<void> apply({
      bool? isPublished,
      bool? isMarketplaceListed,
      bool? bookingEnabled,
    }) async {
      final ok = await ref
          .read(profileMarketplaceControllerProvider.notifier)
          .setFlags(
            isPublished: isPublished,
            isMarketplaceListed: isMarketplaceListed,
            bookingEnabled: bookingEnabled,
          );
      if (!ok && context.mounted) {
        final err = ref.read(profileMarketplaceControllerProvider).error;
        showAppSnackBar(
          context,
          message: AppException.from(err ?? 'Update failed').message,
          isError: true,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Marketplace')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.sageLight,
                foregroundColor: AppColors.sageDark,
                backgroundImage: business.logoUrl != null
                    ? CachedNetworkImageProvider(business.logoUrl!)
                    : null,
                child: business.logoUrl == null
                    ? Text(
                        business.name.isNotEmpty
                            ? business.name[0].toUpperCase()
                            : '?',
                      )
                    : null,
              ),
              title: Text(business.name),
              subtitle: const Text('Edit profile, images & details'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => context.push(RoutePaths.editBusinessProfile),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Visibility',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            canManage
                ? 'Control where your business appears publicly.'
                : 'Only an owner or admin can change visibility.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Published profile'),
                  subtitle: Text(
                    'Your booking page at /business/${business.slug} is '
                    'publicly visible to clients.',
                  ),
                  value: business.isPublished,
                  onChanged: (!canManage || saving)
                      ? null
                      : (v) => apply(isPublished: v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Listed in marketplace'),
                  subtitle: const Text(
                    'Appear in the BetterBooking discovery directory so new '
                    'clients can find you.',
                  ),
                  value: business.isMarketplaceListed,
                  onChanged: (!canManage || saving)
                      ? null
                      : (v) => apply(isMarketplaceListed: v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Accepting bookings'),
                  subtitle: const Text(
                    'Allow clients to book new appointments online.',
                  ),
                  value: business.bookingEnabled,
                  onChanged: (!canManage || saving)
                      ? null
                      : (v) => apply(bookingEnabled: v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Booking link',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Your booking link'),
                  subtitle: Text(url),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        showAppSnackBar(context, message: 'Link copied');
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code_2, color: AppColors.sage),
                  title: const Text('QR code & sharing'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                  ),
                  onTap: () => context.push(RoutePaths.bookingLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ShareBookingLinkSection(
            businessName: business.name,
            slug: business.slug,
          ),
        ],
      ),
    );
  }
}
