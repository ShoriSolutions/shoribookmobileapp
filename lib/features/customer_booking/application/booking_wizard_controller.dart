import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../models/availability_models.dart';
import '../../../models/service.dart';
import '../../../models/staff_profile.dart';
import '../../auth/application/auth_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../trust/application/trust_providers.dart';
import '../data/availability_calculator.dart';
import '../data/customer_booking_repository.dart';
import 'booking_wizard_state.dart';

final customerBookingRepositoryProvider = Provider<CustomerBookingRepository>(
  (ref) => CustomerBookingRepository(ref.watch(supabaseClientProvider)),
);

/// Available slots for a given (slug, serviceId, staffId-or-null, date) —
/// fetches everything the pure calculateAvailableSlots function needs
/// and delegates the actual algorithm to it.
final availableSlotsProvider = FutureProvider.autoDispose
    .family<List<AvailableSlot>, ({String slug, String serviceId, String? staffId, DateTime date})>(
      (ref, args) async {
        final profileData = await ref.watch(businessProfileProvider(args.slug).future);
        if (profileData == null) return [];

        final service = profileData.services.firstWhere(
          (s) => s.id == args.serviceId,
          orElse: () => profileData.services.first,
        );

        final assignedStaffIds = profileData.serviceStaffLinks[args.serviceId];
        var candidateStaff = (assignedStaffIds == null || assignedStaffIds.isEmpty)
            ? profileData.staff
            : profileData.staff
                .where((s) => assignedStaffIds.contains(s.id))
                .toList();
        if (args.staffId != null) {
          candidateStaff =
              candidateStaff.where((s) => s.id == args.staffId).toList();
        }

        final repo = ref.watch(marketplaceRepositoryProvider);
        final tz = profileData.business.timezone;
        final dateStr = _isoDate(args.date);

        final dayStartUtc = businessLocalToUtc(
          date: dateStr,
          time: '00:00',
          timezone: tz,
        );
        final dayEndUtc = businessLocalToUtc(
          date: dateStr,
          time: '23:59',
          timezone: tz,
        );

        final staffIds = candidateStaff.map((s) => s.id).toList();

        final results = await Future.wait([
          repo.fetchSpecialDay(profileData.business.id, dateStr),
          repo.fetchStaffAvailabilityForStaffIds(staffIds),
          repo.fetchStaffBreaksForStaffIds(staffIds),
          repo.fetchBookedRanges(
            businessId: profileData.business.id,
            rangeStartUtc: dayStartUtc,
            rangeEndUtc: dayEndUtc,
          ),
          repo.fetchBlockedRanges(
            businessId: profileData.business.id,
            rangeStartUtc: dayStartUtc,
            rangeEndUtc: dayEndUtc,
          ),
        ]);

        return calculateAvailableSlots(
          date: dateStr,
          timezone: tz,
          serviceDurationMinutes: service.durationMinutes,
          bufferBeforeMinutes: service.bufferBeforeMinutes,
          bufferAfterMinutes: service.bufferAfterMinutes,
          staffList: candidateStaff,
          businessHours: profileData.hours,
          specialDay: results[0] as SpecialBusinessDay?,
          staffAvailability: results[1] as List<StaffAvailability>,
          staffBreaks: results[2] as List<StaffBreak>,
          bookedRanges: results[3] as List<BookedRange>,
          blockedRanges: results[4] as List<BlockedRange>,
        );
      },
    );

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class BookingWizardController extends AutoDisposeFamilyNotifier<
    BookingWizardState, String> {
  @override
  BookingWizardState build(String slug) {
    _prefillFromExistingCustomer();
    return const BookingWizardState();
  }

  Future<void> _prefillFromExistingCustomer() async {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    try {
      final profileData = await ref.read(businessProfileProvider(arg).future);
      if (profileData == null) return;
      final existing = await ref
          .read(customerBookingRepositoryProvider)
          .fetchMyExistingCustomerRecord(
            businessId: profileData.business.id,
            userId: userId,
          );
      if (existing != null) {
        state = state.copyWith(
          firstName: existing.firstName,
          lastName: existing.lastName ?? '',
          phone: existing.phone,
          whatsapp: existing.whatsappNumber ?? '',
          email: existing.email ?? '',
        );
      }
    } catch (_) {
      // Prefill is a convenience, not required — silently skip on failure.
    }
  }

  void selectService(Service service) {
    state = state.copyWith(
      selectedService: service,
      step: BookingWizardStep.staff,
    );
  }

  void selectStaff(StaffProfile? staff) {
    state = staff == null
        ? state.copyWith(clearSelectedStaff: true, step: BookingWizardStep.date)
        : state.copyWith(selectedStaff: staff, step: BookingWizardStep.date);
  }

  void selectDate(DateTime date) {
    state = state.copyWith(
      selectedDate: date,
      selectedTime: null,
      step: BookingWizardStep.time,
    );
  }

  void selectTime(String time) {
    state = state.copyWith(selectedTime: time, step: BookingWizardStep.details);
  }

  void updateDetails({
    String? firstName,
    String? lastName,
    String? phone,
    String? whatsapp,
    String? email,
    String? notes,
  }) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      whatsapp: whatsapp,
      email: email,
      notes: notes,
    );
  }

  void continueToReview() {
    if (!state.canContinueFromDetails) return;
    state = state.copyWith(step: BookingWizardStep.review);
  }

  void setPolicyAccepted(bool value) {
    state = state.copyWith(policyAccepted: value);
  }

  void goToStep(BookingWizardStep step) {
    state = state.copyWith(step: step, clearError: true, clearConflict: true);
  }

  void backOneStep() {
    const order = BookingWizardStep.values;
    final i = order.indexOf(state.step);
    if (i > 0) goToStep(order[i - 1]);
  }

  Future<void> submit() async {
    final service = state.selectedService;
    final date = state.selectedDate;
    final time = state.selectedTime;
    if (service == null || date == null || time == null) return;
    if (!state.policyAccepted) {
      state = state.copyWith(
        errorMessage: 'Please accept the cancellation policy to continue',
      );
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearConflict: true,
      phoneConflict: false,
    );

    try {
      // Trust gate — only for signed-in customers. Guests have no trust
      // account (banned/suspended is account-level), so they book without
      // it. Softer bands (deposit/manual approval) are surfaced elsewhere.
      if (ref.read(authRepositoryProvider).currentUser != null) {
        final elig =
            await ref.read(trustRepositoryProvider).checkBookingEligibility();
        final eligStatus = elig['status'] as String?;
        if (eligStatus == 'banned') {
          state = state.copyWith(
            isSubmitting: false,
            errorMessage:
                "Your account isn't able to make bookings. Please contact support.",
          );
          return;
        }
        if (eligStatus == 'suspended') {
          final until = elig['suspension_until'] as String?;
          final when = until != null
              ? DateFormat('MMM d, y').format(DateTime.parse(until).toLocal())
              : null;
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: when != null
                ? 'Your account is temporarily suspended from booking until $when.'
                : 'Your account is temporarily suspended from booking.',
          );
          return;
        }
      }

      final profileData = await ref.read(businessProfileProvider(arg).future);
      if (profileData == null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'This business could not be found',
        );
        return;
      }

      final startUtc = businessLocalToUtc(
        date: _isoDate(date),
        time: time,
        timezone: profileData.business.timezone,
      );

      // Smart-scheduling guard (server-calculated): re-verifies open hours,
      // closures, manual blocks, buffer/overlap, and booking limits. The
      // slot calculator already hides invalid slots client-side; this is the
      // authoritative recheck that also catches races and limit changes.
      final slot = await ref
          .read(customerBookingRepositoryProvider)
          .checkSlotAvailable(
            businessId: profileData.business.id,
            serviceId: service.id,
            staffProfileId: state.selectedStaff?.id,
            startTime: startUtc,
          );
      if (!slot.available) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: slot.reason ?? 'That time is no longer available.',
        );
        return;
      }

      final result = await ref
          .read(customerBookingRepositoryProvider)
          .createAppointment(
            businessId: profileData.business.id,
            serviceId: service.id,
            staffProfileId: state.selectedStaff?.id,
            startTime: startUtc,
            firstName: state.firstName,
            lastName: state.lastName.trim().isEmpty ? null : state.lastName,
            phone: state.phone,
            whatsapp: state.whatsapp.trim().isEmpty ? null : state.whatsapp,
            email: state.email.trim().isEmpty ? null : state.email,
            notes: state.notes.trim().isEmpty ? null : state.notes,
            cancellationPolicyAccepted: state.policyAccepted,
          );

      switch (result.status) {
        case CustomerBookingStatus.created:
          state = state.copyWith(
            isSubmitting: false,
            createdAppointmentId: result.appointmentId,
            step: BookingWizardStep.confirmation,
          );
          break;
        case CustomerBookingStatus.conflict:
          final name =
              result.conflicts.isNotEmpty
                  ? result.conflicts.first['customer_name'] as String? ??
                        'Another booking'
                  : 'Another booking';
          state = state.copyWith(
            isSubmitting: false,
            conflictMessage: '$name is already booked at this time.',
          );
          break;
        case CustomerBookingStatus.phoneConflict:
          state = state.copyWith(isSubmitting: false, phoneConflict: true);
          break;
        case CustomerBookingStatus.notAcceptingBookings:
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: 'This business is not accepting bookings right now.',
          );
          break;
        case CustomerBookingStatus.rateLimited:
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: "You've made several bookings with this number "
                'recently. Please try again later or log in to continue.',
          );
          break;
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: AppException.from(e).message,
      );
    }
  }
}

final bookingWizardControllerProvider = NotifierProvider.autoDispose
    .family<BookingWizardController, BookingWizardState, String>(
      BookingWizardController.new,
    );
