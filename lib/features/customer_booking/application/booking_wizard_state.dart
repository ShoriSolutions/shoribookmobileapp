import '../../../models/service.dart';
import '../../../models/staff_profile.dart';

enum BookingWizardStep { service, staff, date, time, details, review, confirmation }

class BookingWizardState {
  final BookingWizardStep step;

  final Service? selectedService;
  final StaffProfile? selectedStaff; // null = any available

  final DateTime? selectedDate;
  final String? selectedTime; // "HH:MM"

  final String firstName;
  final String lastName;
  final String phone;
  final String whatsapp;
  final String email;
  final String notes;

  final bool policyAccepted;

  final bool isSubmitting;
  final String? errorMessage;
  final String? conflictMessage;
  final bool phoneConflict;
  final String? createdAppointmentId;

  const BookingWizardState({
    this.step = BookingWizardStep.service,
    this.selectedService,
    this.selectedStaff,
    this.selectedDate,
    this.selectedTime,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.notes = '',
    this.policyAccepted = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.conflictMessage,
    this.phoneConflict = false,
    this.createdAppointmentId,
  });

  bool get canContinueFromDetails =>
      firstName.trim().isNotEmpty && phone.trim().isNotEmpty;

  BookingWizardState copyWith({
    BookingWizardStep? step,
    Service? selectedService,
    StaffProfile? selectedStaff,
    bool clearSelectedStaff = false,
    DateTime? selectedDate,
    String? selectedTime,
    String? firstName,
    String? lastName,
    String? phone,
    String? whatsapp,
    String? email,
    String? notes,
    bool? policyAccepted,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? conflictMessage,
    bool clearConflict = false,
    bool? phoneConflict,
    String? createdAppointmentId,
  }) {
    return BookingWizardState(
      step: step ?? this.step,
      selectedService: selectedService ?? this.selectedService,
      selectedStaff:
          clearSelectedStaff ? null : (selectedStaff ?? this.selectedStaff),
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      policyAccepted: policyAccepted ?? this.policyAccepted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      conflictMessage:
          clearConflict ? null : (conflictMessage ?? this.conflictMessage),
      phoneConflict: phoneConflict ?? this.phoneConflict,
      createdAppointmentId: createdAppointmentId ?? this.createdAppointmentId,
    );
  }
}
