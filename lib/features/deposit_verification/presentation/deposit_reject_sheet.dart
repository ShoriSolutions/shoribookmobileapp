import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/deposit_submission.dart';

typedef DepositRejectResult = ({String reason, String? notes});

/// A bottom sheet for a vendor to reject a deposit with a reason (+ optional
/// notes). Returns null if dismissed. Shared by the verification list and the
/// inline proof-of-payment section on a booking.
Future<DepositRejectResult?> showDepositRejectSheet(BuildContext context) {
  return showModalBottomSheet<DepositRejectResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RejectSheet(),
  );
}

/// Owns its controller so it's disposed with the sheet (not mid-animation).
class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  String? _reason;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reject deposit',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('Choose a reason — the customer is notified and can '
                'resubmit.',
                style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
            const SizedBox(height: 12),
            for (final r in DepositRejectReason.all)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  _reason == r
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _reason == r ? AppColors.sageDark : AppColors.muted,
                ),
                title: Text(r),
                onTap: () => setState(() => _reason = r),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: _reason == null
                    ? null
                    : () => Navigator.pop(context, (
                          reason: _reason!,
                          notes: _notes.text.trim().isEmpty
                              ? null
                              : _notes.text.trim(),
                        )),
                child: const Text('Reject deposit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
