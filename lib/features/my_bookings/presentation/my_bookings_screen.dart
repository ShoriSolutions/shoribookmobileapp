import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/appointment.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
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

    return DefaultTabController(
      length: 2,
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
                tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')],
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
