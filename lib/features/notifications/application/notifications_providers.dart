import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/notification_settings.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});

/// The active business's notification settings (defaults if none saved yet).
final notificationSettingsProvider =
    FutureProvider.autoDispose<NotificationSettings>((ref) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return NotificationSettings.defaults;
  return ref
      .read(notificationsRepositoryProvider)
      .getSettings(membership.business.id);
});

/// Recent reminder history for the active business.
final reminderHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return const [];
  return ref
      .read(notificationsRepositoryProvider)
      .getHistory(membership.business.id);
});

/// The signed-in customer's own notification preferences (raw row or null).
final myNotificationPrefsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.read(notificationsRepositoryProvider).getMyPreferences();
});
