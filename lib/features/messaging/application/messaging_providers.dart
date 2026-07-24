import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/appointment.dart';
import '../../../models/conversation.dart';
import '../../../models/message.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/messaging_repository.dart';
import '../data/push_tokens_repository.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(ref.watch(supabaseClientProvider));
});

final pushTokensRepositoryProvider = Provider<PushTokensRepository>((ref) {
  return PushTokensRepository(ref.watch(supabaseClientProvider));
});

/// True when the current session is acting as a business (vendor side).
final isVendorMessagingProvider = Provider<bool>((ref) {
  return ref.watch(appModeProvider) == AppMode.businessOwner;
});

/// The live conversation list for the current viewer (vendor: their active
/// business; customer: their own conversations). Realtime-backed.
final conversationsProvider =
    StreamProvider.autoDispose<List<Conversation>>((ref) {
  final repo = ref.watch(messagingRepositoryProvider);
  final asVendor = ref.watch(isVendorMessagingProvider);
  if (asVendor) {
    final businessId =
        ref.watch(activeMembershipProvider).valueOrNull?.business.id;
    if (businessId == null) return Stream.value(const []);
    return repo.watchConversations(asVendor: true, businessId: businessId);
  }
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return Stream.value(const []);
  return repo.watchConversations(asVendor: false, customerUserId: uid);
});

/// Non-archived conversations for the current viewer, unread first.
final activeConversationsProvider =
    Provider.autoDispose<AsyncValue<List<Conversation>>>((ref) {
  final asVendor = ref.watch(isVendorMessagingProvider);
  return ref.watch(conversationsProvider).whenData((list) {
    final visible = [
      for (final c in list)
        if (!c.archivedFor(asVendor: asVendor)) c,
    ];
    visible.sort((a, b) {
      final au = a.unreadFor(asVendor: asVendor) ? 1 : 0;
      final bu = b.unreadFor(asVendor: asVendor) ? 1 : 0;
      if (au != bu) return bu - au; // unread first
      final at = a.lastMessageAt ?? a.updatedAt;
      final bt = b.lastMessageAt ?? b.updatedAt;
      return bt.compareTo(at);
    });
    return visible;
  });
});

/// Total conversations with unread inbound messages — for the nav badge.
/// Derived from the realtime list so it updates instantly.
final unreadConversationsProvider = Provider.autoDispose<int>((ref) {
  final asVendor = ref.watch(isVendorMessagingProvider);
  return ref.watch(conversationsProvider).maybeWhen(
        data: (list) => list
            .where((c) =>
                !c.archivedFor(asVendor: asVendor) &&
                c.unreadFor(asVendor: asVendor))
            .length,
        orElse: () => 0,
      );
});

/// The live message thread for a conversation.
final messagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, convId) {
  return ref.watch(messagingRepositoryProvider).watchMessages(convId);
});

/// A single conversation's summary from the current list (for the thread
/// header) — realtime, so status/block changes reflect live.
final conversationByIdProvider =
    Provider.autoDispose.family<Conversation?, String>((ref, convId) {
  return ref.watch(conversationsProvider).maybeWhen(
        data: (list) {
          for (final c in list) {
            if (c.id == convId) return c;
          }
          return null;
        },
        orElse: () => null,
      );
});

/// The appointment behind a booking conversation, for the booking summary.
final conversationAppointmentProvider =
    FutureProvider.autoDispose.family<Appointment?, String>((ref, apptId) {
  return ref.watch(messagingRepositoryProvider).fetchAppointment(apptId);
});

/// A short-lived signed URL for a private attachment storage path.
final attachmentUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, path) {
  return ref.watch(messagingRepositoryProvider).signedAttachmentUrl(path);
});
