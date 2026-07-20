import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/service.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../staff/application/staff_providers.dart';
import '../application/services_providers.dart';

class ServiceFormScreen extends ConsumerStatefulWidget {
  final String? serviceId;

  const ServiceFormScreen({super.key, this.serviceId});

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _depositAmount = TextEditingController();
  final _depositPercentage = TextEditingController();

  String _depositType = 'FIXED';
  bool _depositRequired = false;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingExisting = false;
  Service? _existing;
  // Staff assigned to this service (empty = any active staff can perform it).
  Set<String> _assignedStaffIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.serviceId != null) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoadingExisting = true);
    try {
      final service = await ref
          .read(servicesRepositoryProvider)
          .fetchById(widget.serviceId!);
      _existing = service;
      _assignedStaffIds =
          await ref.read(servicesRepositoryProvider).fetchAssignedStaffIds(
                widget.serviceId!,
              );
      _name.text = service.name;
      _description.text = service.description ?? '';
      _category.text = service.category ?? '';
      _price.text = service.price.toStringAsFixed(2);
      _duration.text = service.durationMinutes.toString();
      _depositRequired = service.depositRequired;
      _depositType = service.depositType;
      _depositAmount.text = service.depositAmount?.toStringAsFixed(2) ?? '';
      _depositPercentage.text =
          service.depositPercentage?.toStringAsFixed(0) ?? '';
      _isActive = service.isActive;
    } catch (_) {
      // form stays blank; save will surface a clear error instead
    } finally {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _price.dispose();
    _duration.dispose();
    _depositAmount.dispose();
    _depositPercentage.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final membership = await ref.read(activeMembershipProvider.future);
      if (membership == null) return;

      final service = Service(
        id: _existing?.id ?? '',
        businessId: membership.business.id,
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        durationMinutes: int.tryParse(_duration.text) ?? 60,
        price: double.tryParse(_price.text) ?? 0,
        currency: membership.business.currency,
        depositRequired: _depositRequired,
        depositAmount: _depositType == 'FIXED'
            ? double.tryParse(_depositAmount.text)
            : null,
        depositType: _depositType,
        depositPercentage: _depositType == 'PERCENTAGE'
            ? double.tryParse(_depositPercentage.text)
            : null,
        bufferBeforeMinutes: _existing?.bufferBeforeMinutes ?? 0,
        bufferAfterMinutes: _existing?.bufferAfterMinutes ?? 0,
        isActive: _isActive,
        isFeatured: _existing?.isFeatured ?? false,
        sortOrder: _existing?.sortOrder ?? 0,
      );

      final repo = ref.read(servicesRepositoryProvider);
      final String serviceId;
      if (_existing == null) {
        serviceId = await repo.create(service, membership.business.id);
      } else {
        serviceId = _existing!.id;
        await repo.update(serviceId, service, membership.business.id);
      }
      await repo.setAssignedStaff(serviceId, _assignedStaffIds);
      ref.invalidate(servicesListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppException.from(e).message,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    if (_existing == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this service?',
      message: 'This cannot be undone. Existing appointments keep their '
          'recorded price and details.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(servicesRepositoryProvider).delete(_existing!.id);
      ref.invalidate(servicesListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppException.from(e).message,
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New service' : 'Edit service'),
        actions: [
          if (_existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Service name',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Service name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n < 0) return 'Enter a valid price';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _duration,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (min)',
                              ),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 5) return 'Min 5 minutes';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Require a deposit'),
                        value: _depositRequired,
                        onChanged: (v) => setState(() => _depositRequired = v),
                      ),
                      if (_depositRequired) ...[
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'FIXED', label: Text('Fixed')),
                            ButtonSegment(
                              value: 'PERCENTAGE',
                              label: Text('Percentage'),
                            ),
                          ],
                          selected: {_depositType},
                          onSelectionChanged: (s) =>
                              setState(() => _depositType = s.first),
                        ),
                        const SizedBox(height: 12),
                        if (_depositType == 'FIXED')
                          TextFormField(
                            controller: _depositAmount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Deposit amount',
                            ),
                          )
                        else
                          TextFormField(
                            controller: _depositPercentage,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Deposit percentage',
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      _OfferedBySection(
                        selected: _assignedStaffIds,
                        onToggle: (id) => setState(() {
                          if (_assignedStaffIds.contains(id)) {
                            _assignedStaffIds.remove(id);
                          } else {
                            _assignedStaffIds.add(id);
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: const Text(
                          'Inactive services are hidden from booking',
                        ),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save service'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// "Offered by" — pick which staff can perform this service. Selecting none
/// means any active staff can perform it (matches the booking flow).
class _OfferedBySection extends ConsumerWidget {
  const _OfferedBySection({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OFFERED BY',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: AppColors.faint)),
        const SizedBox(height: 4),
        Text(
          selected.isEmpty
              ? 'Any active staff can perform this service.'
              : 'Only the selected staff can be booked for this service.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        staffAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Could not load staff',
              style: TextStyle(color: AppColors.muted)),
          data: (staff) {
            final bookable =
                staff.where((s) => s.isActive && s.isBookable).toList();
            if (bookable.isEmpty) {
              return const Text('No bookable staff yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted));
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in bookable)
                  _StaffChip(
                    name: s.name,
                    selected: selected.contains(s.id),
                    onTap: () => onToggle(s.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StaffChip extends StatelessWidget {
  const _StaffChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.sage : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppColors.sage : AppColors.parchment),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor:
                  selected ? Colors.white24 : AppColors.sageLight,
              foregroundColor: selected ? Colors.white : AppColors.sageDark,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 7),
            Text(name,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.ink)),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, size: 15, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}
