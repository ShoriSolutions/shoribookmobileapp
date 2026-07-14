import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../application/notifications_providers.dart';

/// Customer-facing: choose which channels to receive reminders on, and opt
/// out of promotional messages while still getting appointment reminders.
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  bool _seeded = false;
  bool _saving = false;
  bool _push = true;
  bool _whatsapp = true;
  bool _email = true;
  bool _promoOptOut = false;

  void _seed(Map<String, dynamic>? p) {
    _push = p?['push_enabled'] as bool? ?? true;
    _whatsapp = p?['whatsapp_enabled'] as bool? ?? true;
    _email = p?['email_enabled'] as bool? ?? true;
    _promoOptOut = p?['promotional_opt_out'] as bool? ?? false;
    _seeded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(notificationsRepositoryProvider).savePreferences(
            push: _push,
            whatsapp: _whatsapp,
            email: _email,
            promotionalOptOut: _promoOptOut,
          );
      ref.invalidate(myNotificationPrefsProvider);
      if (mounted) showAppSnackBar(context, message: 'Preferences saved');
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
    final async = ref.watch(myNotificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          message: AppException.from(e).message,
          onRetry: () => ref.invalidate(myNotificationPrefsProvider),
        ),
        data: (prefs) {
          if (!_seeded) _seed(prefs);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Appointment reminders',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'How would you like to be reminded about your bookings?',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Push notifications'),
                      value: _push,
                      onChanged: (v) => setState(() => _push = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('WhatsApp'),
                      value: _whatsapp,
                      onChanged: (v) => setState(() => _whatsapp = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Email'),
                      value: _email,
                      onChanged: (v) => setState(() => _email = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  title: const Text('No promotional messages'),
                  subtitle: const Text(
                    "You'll still receive appointment reminders.",
                  ),
                  value: _promoOptOut,
                  onChanged: (v) => setState(() => _promoOptOut = v),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save preferences'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
