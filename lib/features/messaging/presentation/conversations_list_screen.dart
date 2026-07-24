import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/conversation.dart';
import '../../../routing/route_paths.dart';
import '../application/messaging_providers.dart';

/// Messages — the conversation list. Vendors see threads for their business
/// (by customer name); customers see their threads (by business name).
class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asVendor = ref.watch(isVendorMessagingProvider);
    final convosAsync = ref.watch(activeConversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: convosAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, st) => ListView(children: [
                  const SizedBox(height: 80),
                  ErrorRetryView(
                    message: 'Could not load messages.',
                    onRetry: () => ref.invalidate(conversationsProvider),
                  ),
                ]),
                data: (convos) {
                  if (convos.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: '💬',
                        title: 'No messages yet',
                        message: asVendor
                            ? 'Messages from your customers about their '
                                'bookings will appear here.'
                            : 'Questions and booking chats with businesses '
                                'will appear here.',
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: convos.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 84, color: AppColors.divider),
                    itemBuilder: (_, i) => _ConversationTile(
                      conversation: convos[i],
                      asVendor: asVendor,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.asVendor});

  final Conversation conversation;
  final bool asVendor;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadFor(asVendor: asVendor);
    final title = c.titleFor(asVendor: asVendor);
    final preview = c.lastMessagePreview ??
        (c.isBooking ? 'Booking conversation' : 'New enquiry');

    return InkWell(
      onTap: () => context.push(RoutePaths.conversation(c.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(title),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    unread ? FontWeight.w800 : FontWeight.w700,
                                color: AppColors.ink)),
                      ),
                      if (c.lastMessageAt != null)
                        Text(_timeLabel(c.lastMessageAt!),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: unread
                                    ? AppColors.terracottaDeep
                                    : AppColors.faint)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (c.isBooking) ...[
                        const Icon(Icons.event_available,
                            size: 13, color: AppColors.sage),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                color: unread
                                    ? AppColors.ink
                                    : AppColors.muted,
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: AppColors.terracotta,
                              shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String title) {
    final logo = conversation.businessLogoUrl;
    if (!asVendor && logo != null && logo.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.sageLight,
        backgroundImage: CachedNetworkImageProvider(logo),
      );
    }
    final initial = title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.sageLight,
      foregroundColor: AppColors.sageDark,
      child: Text(initial,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    );
  }
}

String _timeLabel(DateTime dt) {
  final now = DateTime.now();
  final local = dt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return DateFormat.jm().format(local); // 3:04 PM
  if (today.difference(day).inDays < 7) return DateFormat.E().format(local);
  return DateFormat('d MMM').format(local);
}
