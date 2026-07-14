import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/input_hints.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/appointment.dart';
import '../../../models/customer.dart';
import '../../../models/service.dart';
import '../../../models/staff_profile.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../clients/application/clients_providers.dart';
import '../../services/application/services_providers.dart';
import '../../staff/application/staff_providers.dart';
import '../application/booking_form_controller.dart';

class BookingFlowScreen extends ConsumerWidget {
  const BookingFlowScreen({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(bookingFormControllerProvider.notifier);
    final id = await controller.submit();
    final state = ref.read(bookingFormControllerProvider);

    if (id != null) {
      if (context.mounted) {
        showAppSnackBar(context, message: 'Booking saved');
        context.pop();
      }
      return;
    }

    if (!context.mounted) return;

    if (state.conflicts != null && state.conflicts!.isNotEmpty) {
      final name = state.conflicts!.first['customer_name'] as String? ??
          'Another booking';
      final confirmed = await showConfirmDialog(
        context,
        title: 'Scheduling conflict',
        message: '$name is already booked at this time. Save anyway?',
        confirmLabel: 'Save anyway',
        isDestructive: false,
      );
      if (confirmed) {
        final overrideId = await controller.submit(forceOverride: true);
        if (overrideId != null && context.mounted) {
          showAppSnackBar(context, message: 'Booking saved');
          context.pop();
        }
      }
    } else if (state.errorMessage != null) {
      showAppSnackBar(context, message: state.errorMessage!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFormControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add booking')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle('Client'),
            const _ClientSection(),
            const SizedBox(height: 20),
            const _SectionTitle('Service'),
            const _ServiceSection(),
            const SizedBox(height: 20),
            const _SectionTitle('Staff'),
            const _StaffSection(),
            const SizedBox(height: 20),
            const _SectionTitle('Date & time'),
            const _DateTimeSection(),
            const SizedBox(height: 20),
            const _SectionTitle('Price & deposit'),
            const _PriceDepositSection(),
            const SizedBox(height: 20),
            const _SectionTitle('Booking source'),
            const _BookingSourceSection(),
            const SizedBox(height: 20),
            const _SectionTitle('Notes'),
            const _NotesSection(),
            const SizedBox(height: 24),
            if (state.errorMessage != null && state.conflicts == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.canSubmit && !state.isSubmitting
                    ? () => _save(context, ref)
                    : null,
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ClientSection extends ConsumerStatefulWidget {
  const _ClientSection();

  @override
  ConsumerState<_ClientSection> createState() => _ClientSectionState();
}

class _ClientSectionState extends ConsumerState<_ClientSection> {
  final _searchController = TextEditingController();
  List<Customer> _results = [];
  bool _searching = false;

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final membership = await ref.read(activeMembershipProvider.future);
    if (membership == null) return;
    final results = await ref
        .read(clientsRepositoryProvider)
        .search(membership.business.id, query.trim());
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingFormControllerProvider);
    final controller = ref.read(bookingFormControllerProvider.notifier);

    if (state.selectedCustomer != null) {
      return Card(
        child: ListTile(
          title: Text(state.selectedCustomer!.fullName),
          subtitle: Text(state.selectedCustomer!.phone),
          trailing: TextButton(
            onPressed: () => controller.startNewCustomer(),
            child: const Text('Change'),
          ),
        ),
      );
    }

    if (state.creatingNewCustomer) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'First name'),
                onChanged: (v) => controller.updateNewCustomerField(firstName: v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'Last name (optional)'),
                onChanged: (v) => controller.updateNewCustomerField(lastName: v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: kPhoneHint,
                ),
                keyboardType: TextInputType.phone,
                onChanged: (v) => controller.updateNewCustomerField(phone: v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'WhatsApp (optional)',
                  hintText: kWhatsAppHint,
                ),
                keyboardType: TextInputType.phone,
                onChanged: (v) => controller.updateNewCustomerField(whatsapp: v),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Search existing client instead'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search clients by name or phone',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _search,
        ),
        for (final c in _results)
          ListTile(
            title: Text(c.fullName),
            subtitle: Text(c.phone),
            onTap: () => controller.selectCustomer(c),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => controller.startNewCustomer(),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('New client'),
          ),
        ),
      ],
    );
  }
}

class _ServiceSection extends ConsumerWidget {
  const _ServiceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesListProvider);
    final state = ref.watch(bookingFormControllerProvider);
    final controller = ref.read(bookingFormControllerProvider.notifier);

    return servicesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => const Text('Could not load services'),
      data: (services) {
        final active = services.where((s) => s.isActive).toList();
        return DropdownButtonFormField<Service>(
          initialValue: state.selectedService,
          decoration: const InputDecoration(labelText: 'Select a service'),
          items: active
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text('${s.name} · ${s.durationMinutes} min'),
                ),
              )
              .toList(),
          onChanged: (s) {
            if (s != null) controller.selectService(s);
          },
        );
      },
    );
  }
}

class _StaffSection extends ConsumerWidget {
  const _StaffSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);
    final state = ref.watch(bookingFormControllerProvider);
    final controller = ref.read(bookingFormControllerProvider.notifier);

    return staffAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => const Text('Could not load staff'),
      data: (staff) {
        final bookable = staff.where((s) => s.isActive && s.isBookable).toList();
        return DropdownButtonFormField<StaffProfile?>(
          initialValue: state.selectedStaff,
          decoration: const InputDecoration(labelText: 'Staff member'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Any available')),
            ...bookable.map(
              (s) => DropdownMenuItem(value: s, child: Text(s.name)),
            ),
          ],
          onChanged: controller.selectStaff,
        );
      },
    );
  }
}

class _DateTimeSection extends ConsumerWidget {
  const _DateTimeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFormControllerProvider);
    final controller = ref.read(bookingFormControllerProvider.notifier);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.date,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) controller.setDate(picked);
            },
            child: Text(
              '${state.date.year}-${state.date.month.toString().padLeft(2, '0')}-${state.date.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: state.time ?? TimeOfDay.now(),
              );
              if (picked != null) controller.setTime(picked);
            },
            child: Text(state.time?.format(context) ?? 'Select time'),
          ),
        ),
      ],
    );
  }
}

class _PriceDepositSection extends ConsumerWidget {
  const _PriceDepositSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFormControllerProvider);
    final controller = ref.read(bookingFormControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('price-${state.selectedService?.id}'),
                initialValue: state.price.toStringAsFixed(2),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price'),
                onChanged: (v) => controller.setPrice(double.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: ValueKey('duration-${state.selectedService?.id}'),
                initialValue: state.durationMinutes.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (min)'),
                onChanged: (v) => controller.setDuration(int.tryParse(v) ?? 60),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Deposit required'),
          value: state.depositRequired,
          onChanged: controller.setDepositRequired,
        ),
        if (state.depositRequired) ...[
          TextFormField(
            key: ValueKey('deposit-${state.selectedService?.id}'),
            initialValue: state.depositAmount?.toStringAsFixed(2) ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Deposit amount'),
            onChanged: (v) => controller.setDepositAmount(double.tryParse(v)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: state.depositStatus == 'PAID' ? 'PAID' : 'PENDING',
            decoration: const InputDecoration(labelText: 'Deposit status'),
            items: const [
              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
              DropdownMenuItem(value: 'PAID', child: Text('Already paid')),
            ],
            onChanged: (v) => controller.setDepositStatus(v ?? 'PENDING'),
          ),
          if (state.depositStatus == 'PAID') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: state.paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: PaymentMethod.all
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => controller.setPaymentMethod(v ?? 'CASH'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Payment reference (optional)',
              ),
              onChanged: controller.setPaymentReference,
            ),
          ],
        ],
        if (state.selectedService != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Total: ${formatCurrency(state.price, state.currency)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}

class _BookingSourceSection extends ConsumerWidget {
  const _BookingSourceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFormControllerProvider);
    final controller = ref.read(bookingFormControllerProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final source in BookingSource.all)
          ChoiceChip(
            label: Text(BookingSource.label(source)),
            selected: state.bookingSource == source,
            onSelected: (_) => controller.setBookingSource(source),
          ),
      ],
    );
  }
}

class _NotesSection extends ConsumerWidget {
  const _NotesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bookingFormControllerProvider.notifier);

    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Customer notes (optional)',
          ),
          minLines: 2,
          maxLines: 3,
          onChanged: controller.setCustomerNotes,
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Internal notes (optional, staff only)',
          ),
          minLines: 2,
          maxLines: 3,
          onChanged: controller.setInternalNotes,
        ),
      ],
    );
  }
}
