import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/utils/date_time_formatters.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/appointment.dart';

/// The customer-facing booking list item — business-name-forward (the
/// customer already knows who *they* are; what matters is which
/// business and when), unlike the Owner/Staff app's client-name-forward
/// AppointmentCard.
class BookingCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const BookingCard({super.key, required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tz = appointment.businessTimezone ?? 'America/Barbados';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Opacity(
          opacity: appointment.isActive ? 1 : 0.6,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.sageLight,
                  foregroundColor: AppColors.sageDark,
                  backgroundImage: appointment.businessLogoUrl != null
                      ? NetworkImage(appointment.businessLogoUrl!)
                      : null,
                  child: appointment.businessLogoUrl == null
                      ? Text(
                          (appointment.businessName ?? '?').isNotEmpty
                              ? appointment.businessName![0].toUpperCase()
                              : '?',
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.businessName ?? 'Business',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        [
                          appointment.serviceName,
                          DateTimeFormatters.weekdayDate(
                            appointment.startTime,
                            tz,
                          ),
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(
                        label: StatusColors.appointmentStatusLabel(
                          appointment.status,
                        ),
                        color: StatusColors.appointmentStatus(appointment.status),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
