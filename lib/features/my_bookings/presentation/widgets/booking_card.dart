import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_formatters.dart';
import '../../../../models/appointment.dart';
import '../../../marketplace/presentation/widgets/category_visuals.dart';

/// The customer-facing booking list item (C08) — a gradient category
/// cover, business name, service·pro, date/time and a status chip.
/// Business-name-forward (the customer knows who *they* are; what matters
/// is which business and when).
class BookingCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const BookingCard({super.key, required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final tz = a.businessTimezone ?? 'America/Barbados';
    final visual = CategoryVisual.of(a.businessCategory);
    final (label, bg, fg) = _statusChip(a);

    return Opacity(
      opacity: a.isActive ? 1 : 0.6,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.parchment),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: visual.gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(visual.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.businessName ?? 'Business',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      const SizedBox(height: 1),
                      Text(
                        [
                          a.serviceName,
                          a.staffName != null ? 'with ${a.staffName}' : 'Any pro',
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${DateTimeFormatters.weekdayDate(a.startTime, tz)} · '
                              '${DateTimeFormatters.time(a.startTime, tz)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: fg)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _statusChip(Appointment a) {
    if (a.status == AppointmentStatus.cancelled) {
      return ('Cancelled', AppColors.closedBg, AppColors.closedText);
    }
    if (a.status == AppointmentStatus.noShow) {
      return ('No-show', const Color(0xFFF7ECE9), AppColors.danger);
    }
    if (a.status == AppointmentStatus.completed) {
      return ('Completed', AppColors.closedBg, AppColors.closedText);
    }
    if (a.depositRequired && !a.depositPaid) {
      return ('Deposit due', AppColors.terracottaTint, AppColors.terracottaDeep);
    }
    if (a.status == AppointmentStatus.pending) {
      return ('Pending', AppColors.terracottaTint, AppColors.terracottaDeep);
    }
    return ('Confirmed', AppColors.successBg, AppColors.successText);
  }
}
