import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/phone_input.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/application/auth_providers.dart';
import '../application/waitlist_providers.dart';

/// Opens the "Join the waitlist" sheet. Collects/confirms the customer's name
/// + phone and joins the waitlist for the given business/service/pro/date.
Future<void> showJoinWaitlistSheet(
  BuildContext context, {
  required String businessId,
  String? serviceId,
  String? serviceName,
  String? staffProfileId,
  String? staffName,
  DateTime? preferredDate,
  String? preferredTime,
  String? initialName,
  String? initialPhone,
  String? countryCode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JoinWaitlistSheet(
      businessId: businessId,
      serviceId: serviceId,
      serviceName: serviceName,
      staffProfileId: staffProfileId,
      staffName: staffName,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      initialName: initialName,
      initialPhone: initialPhone,
      countryCode: countryCode,
    ),
  );
}

class _JoinWaitlistSheet extends ConsumerStatefulWidget {
  const _JoinWaitlistSheet({
    required this.businessId,
    this.serviceId,
    this.serviceName,
    this.staffProfileId,
    this.staffName,
    this.preferredDate,
    this.preferredTime,
    this.initialName,
    this.initialPhone,
    this.countryCode,
  });

  final String businessId;
  final String? serviceId;
  final String? serviceName;
  final String? staffProfileId;
  final String? staffName;
  final DateTime? preferredDate;
  final String? preferredTime;
  final String? initialName;
  final String? initialPhone;
  final String? countryCode;

  @override
  ConsumerState<_JoinWaitlistSheet> createState() => _JoinWaitlistSheetState();
}

class _JoinWaitlistSheetState extends ConsumerState<_JoinWaitlistSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.initialPhone ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      showAppSnackBar(context,
          message: 'Enter your name and phone number', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await ref.read(waitlistRepositoryProvider).join(
            businessId: widget.businessId,
            serviceId: widget.serviceId,
            staffProfileId: widget.staffProfileId,
            firstName: _name.text.trim(),
            phone: _phone.text.trim(),
            preferredDate: widget.preferredDate,
            preferredTime: widget.preferredTime,
          );
      final signedIn =
          ref.read(authStatusProvider) == AuthStatus.authenticated;
      if (!signedIn && res.entryId != null) {
        await ref
            .read(guestWaitlistStoreProvider)
            .add(id: res.entryId!, phone: _phone.text.trim());
      }
      ref.invalidate(myWaitlistProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      final msg = switch (res.status) {
        'joined' => "You're on the waitlist. We'll let you know if a spot opens.",
        'exists' => "You're already on the waitlist for this.",
        'disabled' => "This business isn't offering a waitlist right now.",
        _ => 'Could not join the waitlist.',
      };
      showAppSnackBar(context, message: msg, isError: res.status == 'disabled');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      widget.serviceName ?? 'Any service',
      if (widget.staffName != null) 'with ${widget.staffName}',
      if (widget.preferredDate != null)
        DateFormat('EEE, d MMM').format(widget.preferredDate!),
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Join the waitlist',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              "We'll notify you if a spot opens for $summary.",
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneInputFormatters(widget.countryCode),
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Join waitlist',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
