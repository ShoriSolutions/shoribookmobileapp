import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/notification_settings.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/notifications_providers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _seeded = false;
  bool _saving = false;
  bool _push = true;
  bool _email = true;
  bool _whatsapp = false;
  bool _sms = false;
  bool _whatsappConnected = false;
  final _offsets = <int>{};
  final _template = TextEditingController();

  @override
  void dispose() {
    _template.dispose();
    super.dispose();
  }

  void _seed(NotificationSettings s) {
    _push = s.pushEnabled;
    _email = s.emailEnabled;
    _whatsapp = s.whatsappEnabled;
    _sms = s.smsEnabled;
    _whatsappConnected = s.whatsappConnected;
    _offsets
      ..clear()
      ..addAll(s.reminderOffsets);
    _template.text = s.reminderTemplate;
    _seeded = true;
  }

  Future<void> _save() async {
    final membership = ref.read(activeMembershipProvider).valueOrNull;
    if (membership == null) return;
    setState(() => _saving = true);
    try {
      final offsets = _offsets.toList()..sort((a, b) => b.compareTo(a));
      await ref.read(notificationsRepositoryProvider).saveSettings(
            membership.business.id,
            NotificationSettings(
              pushEnabled: _push,
              emailEnabled: _email,
              whatsappEnabled: _whatsapp,
              smsEnabled: _sms,
              reminderOffsets: offsets,
              reminderTemplate: _template.text.trim(),
              whatsappConnected: _whatsappConnected,
            ),
          );
      ref.invalidate(notificationSettingsProvider);
      if (mounted) showAppSnackBar(context, message: 'Reminder settings saved');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCustom() async {
    final valueCtrl = TextEditingController();
    var unit = 60; // minutes multiplier: 1=min, 60=hour, 1440=day
    final added = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Custom reminder'),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: unit,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('minutes')),
                  DropdownMenuItem(value: 60, child: Text('hours')),
                  DropdownMenuItem(value: 1440, child: Text('days')),
                ],
                onChanged: (v) => setD(() => unit = v ?? 60),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final n = int.tryParse(valueCtrl.text.trim());
                if (n != null && n > 0) Navigator.pop(ctx, n * unit);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    valueCtrl.dispose();
    if (added != null && added > 0 && added <= 43200) {
      setState(() => _offsets.add(added)); // cap 30 days
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders & notifications')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          message: AppException.from(e).message,
          onRetry: () => ref.invalidate(notificationSettingsProvider),
        ),
        data: (settings) {
          if (!_seeded) _seed(settings);
          final customOffsets = _offsets
              .where((o) => !reminderPresets.containsKey(o))
              .toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Channels', style: Theme.of(context).textTheme.titleMedium),
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
                      title: const Text('Email'),
                      value: _email,
                      onChanged: (v) => setState(() => _email = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('WhatsApp Business'),
                      subtitle: Text(
                        _whatsappConnected
                            ? 'Official Business account connected.'
                            : 'Not connected — reminders on this channel are '
                                'paused until an official WhatsApp Business '
                                'account is connected.',
                        style: TextStyle(
                          color: _whatsappConnected
                              ? AppColors.sageDark
                              : AppColors.muted,
                        ),
                      ),
                      value: _whatsapp,
                      onChanged: (v) => setState(() => _whatsapp = v),
                    ),
                    const Divider(height: 1),
                    const SwitchListTile(
                      title: Text('SMS'),
                      subtitle: Text('Coming soon'),
                      value: false,
                      onChanged: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Reminder times',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Send a reminder this long before each appointment.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in reminderPresets.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _offsets.contains(entry.key),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _offsets.add(entry.key);
                        } else {
                          _offsets.remove(entry.key);
                        }
                      }),
                    ),
                  for (final o in customOffsets)
                    InputChip(
                      label: Text(reminderOffsetLabel(o)),
                      onDeleted: () => setState(() => _offsets.remove(o)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Custom'),
                    onPressed: _addCustom,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text('Message template',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _template,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Reminder message…',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Placeholders: {{customer_name}}, {{business_name}}, '
                '{{service_name}}, {{date}}, {{time}}, {{staff_name}}, '
                '{{business_address}}, {{business_phone}}, {{booking_reference}}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
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
                      : const Text('Save settings'),
                ),
              ),

              const SizedBox(height: 28),
              Text('Recent reminders',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const _ReminderHistory(),
            ],
          );
        },
      ),
    );
  }
}

class _ReminderHistory extends ConsumerWidget {
  const _ReminderHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reminderHistoryProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Text(
        'Could not load reminder history.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.muted),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Text(
            'No reminders scheduled yet. They appear here automatically as '
            'bookings come in.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          );
        }
        return Column(
          children: [
            for (final r in rows) _historyTile(context, r),
          ],
        );
      },
    );
  }

  Widget _historyTile(BuildContext context, Map<String, dynamic> r) {
    final channel = (r['channel'] as String? ?? '').toUpperCase();
    final status = r['status'] as String? ?? 'pending';
    final when = r['scheduled_for'] as String?;
    final whenStr = when != null
        ? DateFormat('MMM d, h:mm a').format(DateTime.parse(when).toLocal())
        : '';
    final color = switch (status) {
      'sent' || 'delivered' || 'read' => AppColors.sage,
      'failed' => AppColors.danger,
      'cancelled' => AppColors.muted,
      _ => AppColors.terracotta,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, size: 12, color: color),
      title: Text('$channel · $whenStr'),
      trailing: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
