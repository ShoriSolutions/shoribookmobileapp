import 'package:flutter/material.dart';
import 'tabs/blocked_time_tab.dart';
import 'tabs/booking_rules_tab.dart';
import 'tabs/hours_tab.dart';
import 'tabs/special_days_tab.dart';
import 'tabs/staff_schedules_tab.dart';

/// Availability management, mirroring the web dashboard's Availability
/// page: Hours / Staff Schedules / Blocked Time / Special Days, plus a
/// Rules tab (buffer + booking limits) enforced by the scheduling engine.
class AvailabilityScreen extends StatelessWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Availability'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Hours'),
              Tab(text: 'Staff Schedules'),
              Tab(text: 'Blocked Time'),
              Tab(text: 'Special Days'),
              Tab(text: 'Rules'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            HoursTab(),
            StaffSchedulesTab(),
            BlockedTimeTab(),
            SpecialDaysTab(),
            BookingRulesTab(),
          ],
        ),
      ),
    );
  }
}
