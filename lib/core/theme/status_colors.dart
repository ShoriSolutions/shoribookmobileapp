import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Maps the DB's plain-text appointment/deposit status values to a
/// consistent color + label across every screen. Kept as a single
/// source of truth so a status never renders differently on two screens.
class StatusColors {
  const StatusColors._();

  static Color appointmentStatus(String status) {
    switch (status) {
      case 'pending':
        return AppColors.terracotta;
      case 'confirmed':
        return AppColors.sage;
      case 'completed':
        return AppColors.sageDark;
      case 'cancelled':
        return AppColors.muted;
      case 'no_show':
        return AppColors.danger;
      default:
        return AppColors.muted;
    }
  }

  static String appointmentStatusLabel(String status) {
    switch (status) {
      case 'no_show':
        return 'No-show';
      default:
        return status.isEmpty
            ? status
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  static Color depositStatus(String status) {
    switch (status) {
      case 'PAID':
        return AppColors.sage;
      case 'PENDING':
        return AppColors.terracotta;
      case 'FAILED':
        return AppColors.danger;
      case 'REFUNDED':
        return AppColors.muted;
      case 'NOT_REQUIRED':
      default:
        return AppColors.parchment;
    }
  }

  static String depositStatusLabel(String status) {
    switch (status) {
      case 'NOT_REQUIRED':
        return 'Not required';
      default:
        return status.isEmpty
            ? status
            : status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
  }
}
