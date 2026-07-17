import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/appointment.dart';
import '../../../routing/route_paths.dart';
import '../application/my_bookings_providers.dart';
import 'widgets/booking_card.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')],
          ),
        ),
        body: Consumer(
          builder: (context, ref, _) {
            final bookingsAsync = ref.watch(myBookingsProvider);
            return RefreshIndicator(
              onRefresh: () => ref.refresh(myBookingsProvider.future),
              child: bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    ErrorRetryView(
                      message: 'Could not load your bookings.',
                      onRetry: () => ref.invalidate(myBookingsProvider),
                    ),
                  ],
                ),
                data: (bookings) {
                  final now = DateTime.now().toUtc();
                  final upcoming = bookings
                      .where(
                        (b) =>
                            b.isActive &&
                            b.startTime.isAfter(now),
                      )
                      .toList();
                  final past = bookings
                      .where(
                        (b) => !b.isActive || !b.startTime.isAfter(now),
                      )
                      .toList();

                  return TabBarView(
                    children: [
                      _BookingsList(
                        bookings: upcoming,
                        emptyTitle: 'No upcoming bookings',
                        emptyMessage: 'Book an appointment to see it here.',
                      ),
                      _BookingsList(
                        bookings: past,
                        emptyTitle: 'No past bookings yet',
                        emptyMessage: 'Completed and cancelled bookings show up here.',
                      ),
                    ],
                  );
                },
              ),
            );
          },
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
          EmptyState(icon: '▤', title: emptyTitle, message: emptyMessage),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => BookingCard(
        appointment: bookings[i],
        onTap: () => context.push(RoutePaths.bookingDetail(bookings[i].id)),
      ),
    );
  }
}
