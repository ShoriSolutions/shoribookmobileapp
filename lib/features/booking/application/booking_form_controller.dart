import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../models/customer.dart';
import '../../../models/service.dart';
import '../../../models/staff_profile.dart';
import '../../appointments/application/appointments_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../clients/application/clients_providers.dart';
import 'booking_form_state.dart';

class BookingFormController extends Notifier<BookingFormState> {
  @override
  BookingFormState build() {
    return BookingFormState(date: DateTime.now());
  }

  void selectCustomer(Customer customer) {
    state = state.copyWith(
      selectedCustomer: customer,
      creatingNewCustomer: false,
    );
  }

  void startNewCustomer() {
    state = state.copyWith(
      creatingNewCustomer: true,
      clearSelectedCustomer: true,
    );
  }

  void updateNewCustomerField({
    String? firstName,
    String? lastName,
    String? phone,
    String? whatsapp,
    String? email,
  }) {
    state = state.copyWith(
      newFirstName: firstName,
      newLastName: lastName,
      newPhone: phone,
      newWhatsapp: whatsapp,
      newEmail: email,
    );
  }

  void selectService(Service service) {
    state = state.copyWith(
      selectedService: service,
      durationMinutes: service.durationMinutes,
      price: service.price,
      currency: service.currency,
      depositRequired: service.depositRequired,
      depositAmount: service.effectiveDepositAmount,
      depositStatus: service.depositRequired ? 'PENDING' : 'NOT_REQUIRED',
      clearDepositAmount: service.effectiveDepositAmount == null,
    );
  }

  void selectStaff(StaffProfile? staff) {
    if (staff == null) {
      state = state.copyWith(clearSelectedStaff: true);
    } else {
      state = state.copyWith(selectedStaff: staff);
    }
  }

  void setDate(DateTime date) => state = state.copyWith(date: date);
  void setTime(TimeOfDay time) => state = state.copyWith(time: time);
  void setDuration(int minutes) => state = state.copyWith(durationMinutes: minutes);
  void setPrice(double price) => state = state.copyWith(price: price);
  void setDepositRequired(bool value) =>
      state = state.copyWith(depositRequired: value);
  void setDepositAmount(double? amount) =>
      state = state.copyWith(depositAmount: amount, clearDepositAmount: amount == null);
  void setDepositStatus(String status) =>
      state = state.copyWith(depositStatus: status);
  void setPaymentMethod(String method) =>
      state = state.copyWith(paymentMethod: method);
  void setPaymentReference(String ref) =>
      state = state.copyWith(paymentReference: ref);
  void setBookingSource(String source) =>
      state = state.copyWith(bookingSource: source);
  void setCustomerNotes(String notes) =>
      state = state.copyWith(customerNotes: notes);
  void setInternalNotes(String notes) =>
      state = state.copyWith(internalNotes: notes);

  /// Returns the new appointment id on success, null on conflict/error
  /// (state.errorMessage / state.conflicts carry the reason).
  Future<String?> submit({bool forceOverride = false}) async {
    final membership = ref.read(activeMembershipProvider).valueOrNull;
    if (membership == null) return null;
    if (!state.canSubmit) {
      state = state.copyWith(
        errorMessage: 'Please fill in client, service, and time.',
      );
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearConflicts: true,
    );

    try {
      String? customerId = state.selectedCustomer?.id;
      String? customerName = state.selectedCustomer?.fullName;
      String? customerPhone = state.selectedCustomer?.phone;
      String? customerEmail = state.selectedCustomer?.email;

      if (state.creatingNewCustomer) {
        final created = await ref
            .read(clientsRepositoryProvider)
            .findOrCreateByPhone(
              businessId: membership.business.id,
              firstName: state.newFirstName,
              lastName: state.newLastName,
              phone: state.newPhone,
              whatsappNumber: state.newWhatsapp,
              email: state.newEmail,
            );
        customerId = created.id;
        customerName = created.fullName;
        customerPhone = created.phone;
        customerEmail = created.email;
      }

      final tz = membership.business.timezone;
      final time = state.time!;
      final startUtc = businessLocalToUtc(
        date:
            '${state.date.year.toString().padLeft(4, '0')}-${state.date.month.toString().padLeft(2, '0')}-${state.date.day.toString().padLeft(2, '0')}',
        time:
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        timezone: tz,
      );
      final endUtc = startUtc.add(Duration(minutes: state.durationMinutes));

      final result = await ref
          .read(appointmentsRepositoryProvider)
          .createAppointmentSafe(
            businessId: membership.business.id,
            serviceId: state.selectedService?.id,
            staffProfileId: state.selectedStaff?.id,
            customerId: customerId,
            startTime: startUtc,
            endTime: endUtc,
            price: state.price,
            currency: state.currency,
            depositRequired: state.depositRequired,
            depositAmount: state.depositAmount,
            depositStatus: state.depositStatus,
            paymentMethod:
                state.depositStatus == 'PAID' ? state.paymentMethod : null,
            paymentReference:
                state.depositStatus == 'PAID' ? state.paymentReference : null,
            status: state.depositRequired && state.depositStatus != 'PAID'
                ? 'pending'
                : 'confirmed',
            bookingSource: state.bookingSource,
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
            notes: state.customerNotes,
            internalNotes: state.internalNotes,
            forceOverride: forceOverride,
          );

      if (result.isConflict) {
        state = state.copyWith(
          isSubmitting: false,
          conflicts: result.conflicts,
        );
        return null;
      }

      state = state.copyWith(isSubmitting: false);
      return result.appointmentId;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: AppException.from(e).message,
      );
      return null;
    }
  }
}

final bookingFormControllerProvider =
    NotifierProvider<BookingFormController, BookingFormState>(
      BookingFormController.new,
    );
