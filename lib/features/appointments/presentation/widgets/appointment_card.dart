import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/utils/date_time_formatters.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/appointment.dart';

/// The single appointment list-item design reused across Dashboard,
/// Calendar/Agenda, Deposits, and Client history — so an appointment
/// always looks the same regardless of which screen it's shown on.
class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String timezone;
  final VoidCallback onTap;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.timezone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isInactive = !appointment.isActive;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Opacity(
          opacity: isInactive ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateTimeFormatters.time(appointment.startTime, timezone),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DateTimeFormatters.time(appointment.endTime, timezone),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.customerName?.trim().isNotEmpty == true
                            ? appointment.customerName!
                            : 'Walk-in client',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          appointment.serviceName,
                          appointment.staffName,
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusBadge(
                            label: StatusColors.appointmentStatusLabel(
                              appointment.status,
                            ),
                            color: StatusColors.appointmentStatus(
                              appointment.status,
                            ),
                          ),
                          if (appointment.depositRequired)
                            StatusBadge(
                              label: StatusColors.depositStatusLabel(
                                appointment.depositStatus,
                              ),
                              color: StatusColors.depositStatus(
                                appointment.depositStatus,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
