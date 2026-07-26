import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/appointment.dart';
import '../../../models/waitlist_entry.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
import '../../guest_prompt/presentation/guest_account_prompt.dart';
import '../../waitlist/application/waitlist_providers.dart';
import '../application/my_bookings_providers.dart';
import 'widgets/booking_card.dart';

/// C08 · My bookings — big title, Upcoming/Past tabs, and a
/// "made on this device" note for guests (bookings sync once signed in).
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest =
        ref.watch(authStatusProvider) != AuthStatus.authenticated;

    // Nudge guests to create an account when they check their bookings
    // (once-per-30-days cooldown; never on launch).
    if (isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) maybeShowGuestAccountPrompt(context, ref);
      });
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('My bookings',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.ink)),
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.ink,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.sageDark,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                unselectedLabelStyle:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Past'),
                  Tab(text: 'Waitlist'),
                ],
              ),
              if (isGuest)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Icon(Icons.smartphone, size: 16, color: AppColors.muted),
                      SizedBox(width: 6),
                      Text('Bookings made on this device',
                          style: TextStyle(
                              fontSize: 13.5, color: AppColors.muted)),
                    ],
                  ),
                ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final bookingsAsync = ref.watch(myBookingsProvider);
                    return RefreshIndicator(
                      onRefresh: () => ref.refresh(myBookingsProvider.future),
                      child: bookingsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, st) => ListView(
                          children: [
                            const SizedBox(height: 80),
                            ErrorRetryView(
                              message: 'Could not load your bookings.',
                              onRetry: () =>
                                  ref.invalidate(myBookingsProvider),
                            ),
                          ],
                        ),
                        data: (bookings) {
                          final now = DateTime.now().toUtc();
                          final upcoming = bookings
                              .where((b) =>
                                  b.isActive && b.startTime.isAfter(now))
                              .toList();
                          final past = bookings
                              .where((b) =>
                                  !b.isActive || !b.startTime.isAfter(now))
                              .toList();
                          return TabBarView(
                            children: [
                              _BookingsList(
                                bookings: upcoming,
                                emptyTitle: 'No upcoming bookings',
                                emptyMessage:
                                    'Book an appointment to see it here.',
                              ),
                              _BookingsList(
                                bookings: past,
                                emptyTitle: 'No past bookings yet',
                                emptyMessage:
                                    'Completed and cancelled bookings show up here.',
                              ),
                              const _WaitlistList(),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final List<Appointment> bookings;
  final String emptyTitle;
  final String emptyMessage;

  const _BookingsList({
    required this.bookings,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          EmptyState(icon: '📅', title: emptyTitle, message: emptyMessage),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => BookingCard(
        appointment: bookings[i],
        onTap: () => context.push(RoutePaths.bookingDetail(bookings[i].id)),
      ),
    );
  }
}

/// The customer's active waitlist entries, each with a "Leave" action.
class _WaitlistList extends ConsumerWidget {
  const _WaitlistList();

  Future<void> _leave(
      BuildContext context, WidgetRef ref, WaitlistEntry e, bool isGuest) async {
    try {
      await ref.read(waitlistRepositoryProvider).leave(
            e.id,
            guestPhone: isGuest ? e.customerPhone : null,
          );
      ref.invalidate(myWaitlistProvider);
      if (context.mounted) {
        showAppSnackBar(context, message: 'Left the waitlist');
      }
    } catch (err) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: AppException.from(err).message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest =
        ref.watch(authStatusProvider) != AuthStatus.authenticated;
    final async = ref.watch(myWaitlistProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myWaitlistProvider.future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            ErrorRetryView(
              message: 'Could not load your waitlist.',
              onRetry: () => ref.invalidate(myWaitlistProvider),
            ),
          ],
        ),
        data: (all) {
          final entries =
              all.where((e) => e.status == WaitlistStatus.active).toList();
          if (entries.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: '⏳',
                  title: 'Not on any waitlists',
                  message:
                      'Join a waitlist when your preferred time is taken and '
                      "we'll tell you if a spot opens.",
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _WaitlistEntryCard(entry: entries[i], isGuest: isGuest,
                    onLeave: () => _leave(context, ref, entries[i], isGuest)),
          );
        },
      ),
    );
  }
}

class _WaitlistEntryCard extends StatelessWidget {
  const _WaitlistEntryCard({
    required this.entry,
    required this.isGuest,
    required this.onLeave,
  });

  final WaitlistEntry entry;
  final bool isGuest;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final detail = <String>[
      entry.serviceName ?? 'Any service',
      if (entry.staffName != null) 'with ${entry.staffName}',
      if (entry.preferredDate != null)
        DateFormat('EEE, d MMM').format(entry.preferredDate!),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.businessName ?? 'Business',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ),
              if (entry.notifiedAt != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Spot alerted',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successText)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(detail,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onLeave,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Leave waitlist',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
