import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/utils/input_hints.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/service.dart';
import '../../../models/staff_profile.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../application/booking_wizard_controller.dart';
import '../application/booking_wizard_state.dart';

const _cancellationPolicyText =
    "We require at least 24 hours' notice to cancel or reschedule. "
    "Cancellations with less than 24 hours' notice, or no-shows, may "
    "result in a charge of up to 50% of the scheduled service fee. By "
    "confirming your booking, you agree to this policy.";

class BookingWizardScreen extends ConsumerWidget {
  final String slug;

  const BookingWizardScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider(slug));
    final wizardState = ref.watch(bookingWizardControllerProvider(slug));

    return Scaffold(
      appBar: AppBar(
        leading: wizardState.step != BookingWizardStep.service &&
                wizardState.step != BookingWizardStep.confirmation
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref
                    .read(bookingWizardControllerProvider(slug).notifier)
                    .backOneStep(),
              )
            : null,
        title: Text(_stepTitle(wizardState.step)),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => ErrorRetryView(
          message: 'Could not load this business.',
          onRetry: () => ref.invalidate(businessProfileProvider(slug)),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Business not found'));
          }
          switch (wizardState.step) {
            case BookingWizardStep.service:
              return _ServiceStep(slug: slug, services: data.services);
            case BookingWizardStep.staff:
              return _StaffStep(
                slug: slug,
                allStaff: data.staff,
                assignedStaffIds:
                    data.serviceStaffLinks[wizardState.selectedService?.id],
              );
            case BookingWizardStep.date:
              return _DateStep(slug: slug);
            case BookingWizardStep.time:
              return _TimeStep(slug: slug);
            case BookingWizardStep.details:
              return _DetailsStep(slug: slug);
            case BookingWizardStep.review:
              return _ReviewStep(
                slug: slug,
                currency: data.business.currency,
                businessName: data.business.name,
              );
            case BookingWizardStep.confirmation:
              return _ConfirmationStep(
                businessName: data.business.name,
                businessAddress: data.business.address,
              );
          }
        },
      ),
    );
  }

  String _stepTitle(BookingWizardStep step) {
    switch (step) {
      case BookingWizardStep.service:
        return 'Choose a service';
      case BookingWizardStep.staff:
        return 'Choose your pro';
      case BookingWizardStep.date:
        return 'Pick a date';
      case BookingWizardStep.time:
        return 'Choose a time';
      case BookingWizardStep.details:
        return 'Your details';
      case BookingWizardStep.review:
        return 'Review your booking';
      case BookingWizardStep.confirmation:
        return 'Booking confirmed';
    }
  }
}

class _ServiceStep extends ConsumerWidget {
  final String slug;
  final List<Service> services;

  const _ServiceStep({required this.slug, required this.services});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (services.isEmpty) {
      return const Center(child: Text('No services available for booking.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = services[i];
        return Card(
          child: ListTile(
            title: Text(s.name),
            subtitle: Text(
              '${s.durationMinutes} min'
              '${s.depositRequired ? ' · deposit required' : ''}',
            ),
            trailing: Text(
              formatCurrency(s.price, s.currency),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.sageDark,
              ),
            ),
            onTap: () => ref
                .read(bookingWizardControllerProvider(slug).notifier)
                .selectService(s),
          ),
        );
      },
    );
  }
}

class _StaffStep extends ConsumerWidget {
  final String slug;
  final List<StaffProfile> allStaff;
  final Set<String>? assignedStaffIds;

  const _StaffStep({
    required this.slug,
    required this.allStaff,
    required this.assignedStaffIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligible = (assignedStaffIds == null || assignedStaffIds!.isEmpty)
        ? allStaff.where((s) => s.isBookable)
        : allStaff.where(
            (s) => s.isBookable && assignedStaffIds!.contains(s.id),
          );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.sageLight,
              child: Text('✦'),
            ),
            title: const Text('Any Available Pro'),
            subtitle: const Text("We'll assign someone for your chosen time"),
            onTap: () => ref
                .read(bookingWizardControllerProvider(slug).notifier)
                .selectStaff(null),
          ),
        ),
        const SizedBox(height: 8),
        for (final s in eligible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.sageLight,
                  foregroundColor: AppColors.sageDark,
                  backgroundImage: s.profileImageUrl != null
                      ? NetworkImage(s.profileImageUrl!)
                      : null,
                  child: s.profileImageUrl == null
                      ? Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?')
                      : null,
                ),
                title: Text(s.name),
                subtitle: s.role != null ? Text(s.role!) : null,
                onTap: () => ref
                    .read(bookingWizardControllerProvider(slug).notifier)
                    .selectStaff(s),
              ),
            ),
          ),
      ],
    );
  }
}

class _DateStep extends ConsumerWidget {
  final String slug;

  const _DateStep({required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: CalendarDatePicker(
              initialDate: now,
              firstDate: now.subtract(const Duration(days: 0)),
              lastDate: now.add(const Duration(days: 90)),
              onDateChanged: (date) => ref
                  .read(bookingWizardControllerProvider(slug).notifier)
                  .selectDate(date),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeStep extends ConsumerWidget {
  final String slug;

  const _TimeStep({required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizardState = ref.watch(bookingWizardControllerProvider(slug));
    final service = wizardState.selectedService;
    final date = wizardState.selectedDate;
    if (service == null || date == null) {
      return const Center(child: Text('Select a service and date first'));
    }

    final slotsAsync = ref.watch(
      availableSlotsProvider((
        slug: slug,
        serviceId: service.id,
        staffId: wizardState.selectedStaff?.id,
        date: date,
      )),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: slotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => ErrorRetryView(
          message: 'Could not load available times.',
          onRetry: () => ref.invalidate(
            availableSlotsProvider((
              slug: slug,
              serviceId: service.id,
              staffId: wizardState.selectedStaff?.id,
              date: date,
            )),
          ),
        ),
        data: (slots) {
          if (slots.isEmpty) {
            return const Center(
              child: Text(
                'No times available for this date.\nTry a different date or pro.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: slots.length,
            itemBuilder: (context, i) {
              final slot = slots[i];
              final selected = slot.startTime == wizardState.selectedTime;
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: selected ? AppColors.sage : null,
                  foregroundColor: selected ? Colors.white : AppColors.ink,
                ),
                onPressed: () => ref
                    .read(bookingWizardControllerProvider(slug).notifier)
                    .selectTime(slot.startTime),
                child: Text(_formatTime(slot.startTime)),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:${parts[1]} $ampm';
  }
}

class _DetailsStep extends ConsumerStatefulWidget {
  final String slug;

  const _DetailsStep({required this.slug});

  @override
  ConsumerState<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<_DetailsStep> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _email;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final s = ref.read(bookingWizardControllerProvider(widget.slug));
    _firstName = TextEditingController(text: s.firstName);
    _lastName = TextEditingController(text: s.lastName);
    _phone = TextEditingController(text: s.phone);
    _whatsapp = TextEditingController(text: s.whatsapp);
    _email = TextEditingController(text: s.email);
    _notes = TextEditingController(text: s.notes);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(bookingWizardControllerProvider(widget.slug).notifier);
    final state = ref.watch(bookingWizardControllerProvider(widget.slug));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'First name'),
                    onChanged: (v) => controller.updateDetails(firstName: v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastName,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                    ),
                    onChanged: (v) => controller.updateDetails(lastName: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: kPhoneHint,
              ),
              onChanged: (v) => controller.updateDetails(phone: v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp (optional, same as phone if blank)',
                hintText: kWhatsAppHint,
              ),
              onChanged: (v) => controller.updateDetails(whatsapp: v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
              onChanged: (v) => controller.updateDetails(email: v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
              minLines: 2,
              maxLines: 4,
              onChanged: (v) => controller.updateDetails(notes: v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    state.canContinueFromDetails ? controller.continueToReview : null,
                child: const Text('Continue to review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewStep extends ConsumerWidget {
  final String slug;
  final String currency;
  final String businessName;

  const _ReviewStep({
    required this.slug,
    required this.currency,
    required this.businessName,
  });

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    if (ref.read(authStatusProvider) != AuthStatus.authenticated) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Sign in to book',
        message: 'Create a free account or log in to confirm this booking '
            'and keep track of it in My Bookings.',
        confirmLabel: 'Continue',
        isDestructive: false,
      );
      if (!confirmed) return;
      if (context.mounted) context.push(RoutePaths.login);
      return;
    }
    await ref
        .read(bookingWizardControllerProvider(slug).notifier)
        .submit();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingWizardControllerProvider(slug));
    final service = state.selectedService;
    final staff = state.selectedStaff;
    final date = state.selectedDate;
    final time = state.selectedTime;
    if (service == null || date == null || time == null) {
      return const Center(child: Text('Missing booking details'));
    }

    final deposit = service.effectiveDepositAmount;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('✦', service.name,
                        sub: formatCurrency(service.price, service.currency)),
                    _row('◈', staff?.name ?? 'Any Available Pro'),
                    _row('📅', DateTimeFormatters.fullDate(date.toUtc(), 'UTC')),
                    _row('🕐', time),
                    const Divider(height: 24),
                    _row('○', '${state.firstName} ${state.lastName}'.trim(),
                        sub: state.phone),
                    if (state.email.isNotEmpty) _row('@', state.email),
                    if (state.notes.isNotEmpty) _row('✎', state.notes),
                  ],
                ),
              ),
            ),
            if (service.depositRequired && deposit != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  'Deposit required: ${formatCurrency(deposit, currency)}. Your '
                  'booking will be held as pending until the deposit is paid; '
                  '$businessName will contact you to arrange payment.',
                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sageLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cancellation Policy',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    _cancellationPolicyText,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.policyAccepted,
                    onChanged: (v) => ref
                        .read(bookingWizardControllerProvider(slug).notifier)
                        .setPolicyAccepted(v ?? false),
                    title: const Text(
                      'I accept the cancellation and no-show policy',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (state.phoneConflict) ...[
              const SizedBox(height: 12),
              const Text(
                'This phone number is linked to a different account at this '
                'business. Please use a different number.',
                style: TextStyle(color: AppColors.danger),
              ),
            ],
            if (state.conflictMessage != null) ...[
              const SizedBox(height: 12),
              Text(state.conflictMessage!,
                  style: const TextStyle(color: AppColors.danger)),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isSubmitting || !state.policyAccepted
                    ? null
                    : () => _confirm(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: service.depositRequired
                      ? AppColors.terracotta
                      : AppColors.sage,
                ),
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        service.depositRequired
                            ? 'Hold My Spot — Pay Deposit Later'
                            : 'Confirm Booking',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String icon, String label, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text(icon)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (sub != null)
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationStep extends StatelessWidget {
  final String businessName;
  final String? businessAddress;

  const _ConfirmationStep({
    required this.businessName,
    this.businessAddress,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✓', style: TextStyle(fontSize: 40, color: AppColors.sage)),
            const SizedBox(height: 16),
            Text(
              'Your appointment with $businessName has been booked.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(RoutePaths.bookings),
                child: const Text('View My Bookings'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go(RoutePaths.discover),
                child: const Text('Back to Discover'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
