import 'package:flutter/material.dart';
import '../../../models/appointment.dart';
import '../../../models/customer.dart';
import '../../../models/service.dart';
import '../../../models/staff_profile.dart';

class BookingFormState {
  final Customer? selectedCustomer;
  final bool creatingNewCustomer;
  final String newFirstName;
  final String newLastName;
  final String newPhone;
  final String newWhatsapp;
  final String newEmail;

  final Service? selectedService;
  final StaffProfile? selectedStaff; // null = any available

  final DateTime date;
  final TimeOfDay? time;
  final int durationMinutes;
  final double price;
  final String currency;

  final bool depositRequired;
  final double? depositAmount;
  final String depositStatus; // NOT_REQUIRED | PENDING | PAID
  final String paymentMethod;
  final String paymentReference;

  final String bookingSource;
  final String customerNotes;
  final String internalNotes;

  final bool isSubmitting;
  final String? errorMessage;
  final List<Map<String, dynamic>>? conflicts;

  const BookingFormState({
    this.selectedCustomer,
    this.creatingNewCustomer = false,
    this.newFirstName = '',
    this.newLastName = '',
    this.newPhone = '',
    this.newWhatsapp = '',
    this.newEmail = '',
    this.selectedService,
    this.selectedStaff,
    required this.date,
    this.time,
    this.durationMinutes = 60,
    this.price = 0,
    this.currency = 'BBD',
    this.depositRequired = false,
    this.depositAmount,
    this.depositStatus = DepositStatus.notRequired,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentReference = '',
    this.bookingSource = BookingSource.walkIn,
    this.customerNotes = '',
    this.internalNotes = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.conflicts,
  });

  bool get hasClient =>
      selectedCustomer != null ||
      (creatingNewCustomer && newFirstName.trim().isNotEmpty && newPhone.trim().isNotEmpty);

  bool get canSubmit => hasClient && selectedService != null && time != null;

  BookingFormState copyWith({
    Customer? selectedCustomer,
    bool clearSelectedCustomer = false,
    bool? creatingNewCustomer,
    String? newFirstName,
    String? newLastName,
    String? newPhone,
    String? newWhatsapp,
    String? newEmail,
    Service? selectedService,
    StaffProfile? selectedStaff,
    bool clearSelectedStaff = false,
    DateTime? date,
    TimeOfDay? time,
    int? durationMinutes,
    double? price,
    String? currency,
    bool? depositRequired,
    double? depositAmount,
    bool clearDepositAmount = false,
    String? depositStatus,
    String? paymentMethod,
    String? paymentReference,
    String? bookingSource,
    String? customerNotes,
    String? internalNotes,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    List<Map<String, dynamic>>? conflicts,
    bool clearConflicts = false,
  }) {
    return BookingFormState(
      selectedCustomer: clearSelectedCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      creatingNewCustomer: creatingNewCustomer ?? this.creatingNewCustomer,
      newFirstName: newFirstName ?? this.newFirstName,
      newLastName: newLastName ?? this.newLastName,
      newPhone: newPhone ?? this.newPhone,
      newWhatsapp: newWhatsapp ?? this.newWhatsapp,
      newEmail: newEmail ?? this.newEmail,
      selectedService: selectedService ?? this.selectedService,
      selectedStaff:
          clearSelectedStaff ? null : (selectedStaff ?? this.selectedStaff),
      date: date ?? this.date,
      time: time ?? this.time,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      depositRequired: depositRequired ?? this.depositRequired,
      depositAmount:
          clearDepositAmount ? null : (depositAmount ?? this.depositAmount),
      depositStatus: depositStatus ?? this.depositStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      bookingSource: bookingSource ?? this.bookingSource,
      customerNotes: customerNotes ?? this.customerNotes,
      internalNotes: internalNotes ?? this.internalNotes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      conflicts: clearConflicts ? null : (conflicts ?? this.conflicts),
    );
  }
}
