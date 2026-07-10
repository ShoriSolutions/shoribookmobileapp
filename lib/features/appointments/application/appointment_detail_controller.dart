import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/appointment.dart';
import 'appointments_providers.dart';

class AppointmentDetailController
    extends FamilyAsyncNotifier<Appointment, String> {
  @override
  Future<Appointment> build(String appointmentId) async {
    return ref.read(appointmentsRepositoryProvider).fetchById(appointmentId);
  }

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(appointmentsRepositoryProvider).fetchById(arg),
    );
  }

  Future<bool> updateStatus(String status) async {
    try {
      await ref.read(appointmentsRepositoryProvider).updateStatus(arg, status);
      await _reload();
      return true;
    } catch (e) {
      state = AsyncError(AppException.from(e), StackTrace.current);
      return false;
    }
  }

  Future<bool> markDepositPaid({
    required String paymentMethod,
    String? paymentReference,
  }) async {
    try {
      final current = state.value;
      final wasPending = current?.status == AppointmentStatus.pending;
      await ref
          .read(appointmentsRepositoryProvider)
          .markDepositPaid(
            arg,
            paymentMethod: paymentMethod,
            paymentReference: paymentReference,
            autoConfirmIfPending: wasPending,
          );
      await _reload();
      return true;
    } catch (e) {
      state = AsyncError(AppException.from(e), StackTrace.current);
      return false;
    }
  }

  Future<bool> addInternalNote(String note) async {
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateInternalNotes(arg, note);
      await _reload();
      return true;
    } catch (e) {
      state = AsyncError(AppException.from(e), StackTrace.current);
      return false;
    }
  }

  /// Returns null on success, or a human-readable conflict message.
  Future<String?> reschedule({
    required DateTime newStartUtc,
    required DateTime newEndUtc,
    bool forceOverride = false,
  }) async {
    final current = state.value;
    if (current == null) return 'Appointment not loaded';
    try {
      if (!forceOverride && current.staffProfileId != null) {
        final conflicts = await ref
            .read(appointmentsRepositoryProvider)
            .checkConflicts(
              businessId: current.businessId,
              staffProfileId: current.staffProfileId,
              startUtc: newStartUtc,
              endUtc: newEndUtc,
              excludeAppointmentId: arg,
            );
        if (conflicts.isNotEmpty) {
          final name = conflicts.first['customer_name'] as String? ??
              'Another booking';
          return '$name is already booked at that time.';
        }
      }
      await ref.read(appointmentsRepositoryProvider).updateFields(arg, {
        'start_time': newStartUtc.toIso8601String(),
        'end_time': newEndUtc.toIso8601String(),
      });
      await _reload();
      return null;
    } catch (e) {
      return AppException.from(e).message;
    }
  }
}

final appointmentDetailControllerProvider = AsyncNotifierProvider.family<
  AppointmentDetailController,
  Appointment,
  String
>(AppointmentDetailController.new);
