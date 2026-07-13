import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../application/auth_providers.dart';
import '../application/delete_account_controller.dart';

/// Deliberately high-friction account deletion: type "DELETE", then
/// confirm with a one-time code emailed to the account.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmWord = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _confirmWord.addListener(() => setState(() {}));
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmWord.dispose();
    _code.dispose();
    super.dispose();
  }

  void _error() {
    final err = ref.read(deleteAccountControllerProvider).error;
    if (err != null && mounted) {
      showAppSnackBar(context, message: AppException.from(err).message, isError: true);
    }
  }

  Future<void> _sendCode() async {
    final ok = await ref.read(deleteAccountControllerProvider.notifier).sendCode();
    if (!mounted) return;
    if (ok) {
      setState(() => _codeSent = true);
      showAppSnackBar(context, message: 'Confirmation code sent to your email');
    } else {
      _error();
    }
  }

  Future<void> _delete() async {
    final ok = await ref
        .read(deleteAccountControllerProvider.notifier)
        .confirmDelete(_code.text);
    if (!mounted) return;
    if (ok) {
      // Deletion signs the user out; the router redirects automatically.
      showAppSnackBar(context, message: 'Your account has been deleted.');
    } else {
      _error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authRepositoryProvider).currentUser?.email ?? '';
    final loading = ref.watch(deleteAccountControllerProvider).isLoading;
    final canSend = _confirmWord.text.trim().toUpperCase() == 'DELETE';

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'This permanently deletes your account and all of its data. '
                  'If you own a business, this also deletes the business and '
                  'all its services, staff, clients, and bookings.\n\n'
                  'This cannot be undone.',
                  style: TextStyle(color: AppColors.danger, height: 1.4),
                ),
              ),
              const SizedBox(height: 24),

              if (!_codeSent) ...[
                Text(
                  'Type DELETE to confirm',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmWord,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'DELETE'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (!canSend || loading) ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Email me a confirmation code'),
                ),
              ] else ...[
                Text(
                  'Enter the 6-digit code we emailed to $email to permanently '
                  'delete your account.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Confirmation code',
                    hintText: '123456',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (_code.text.trim().length < 6 || loading)
                      ? null
                      : _delete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Permanently delete my account'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: loading ? null : _sendCode,
                  child: const Text('Resend code'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
