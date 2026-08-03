import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/conversation.dart';
import '../../../routing/route_paths.dart';
import '../application/messaging_providers.dart';

/// How the conversation list is split into categories.
enum _ChatFilter { all, bookings, questions }

extension on _ChatFilter {
  String get label => switch (this) {
        _ChatFilter.all => 'All',
        _ChatFilter.bookings => 'Bookings',
        _ChatFilter.questions => 'Questions',
      };

  bool matches(Conversation c) => switch (this) {
        _ChatFilter.all => true,
        _ChatFilter.bookings => c.isBooking,
        _ChatFilter.questions => !c.isBooking,
      };
}

/// Messages — the conversation list. Vendors see threads for their business
/// (by customer name); customers see their threads (by business name).
/// Supports category filters and a multi-select delete (removes a thread from
/// your own inbox).
class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  ConsumerState<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState
    extends ConsumerState<ConversationsListScreen> {
  _ChatFilter _filter = _ChatFilter.all;
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _deleting = false;

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _enterSelect(String id) {
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(id);
    });
  }

  void _cancelSelect() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<void> _deleteSelected(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count ${count == 1 ? 'chat' : 'chats'}?'),
        content: const Text(
          'This removes the selected conversations from your inbox. The other '
          'person keeps their copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    final repo = ref.read(messagingRepositoryProvider);
    try {
      await Future.wait(
        _selected.map((id) => repo.setFlag(id, archive: true)),
      );
      if (!mounted) return;
      showAppSnackBar(context,
          message: '$count ${count == 1 ? 'chat' : 'chats'} deleted');
      _cancelSelect();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asVendor = ref.watch(isVendorMessagingProvider);
    final convosAsync = ref.watch(activeConversationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _deleting ? null : _cancelSelect,
              )
            : null,
        title: Text(_selecting ? '${_selected.length} selected' : 'Messages'),
        actions: [
          if (!_selecting)
            convosAsync.maybeWhen(
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: () => setState(() => _selecting = true),
                      child: const Text('Select'),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filterBar(),
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
                data: (all) {
                  final convos =
                      all.where((c) => _filter.matches(c)).toList();
                  if (convos.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: '💬',
                        title: all.isEmpty
                            ? 'No messages yet'
                            : 'No ${_filter.label.toLowerCase()} chats',
                        message: all.isEmpty
                            ? (asVendor
                                ? 'Messages from your customers about their '
                                    'bookings will appear here.'
                                : 'Questions and booking chats with businesses '
                                    'will appear here.')
                            : 'Try a different category.',
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
                      selecting: _selecting,
                      selected: _selected.contains(convos[i].id),
                      onTap: () {
                        if (_selecting) {
                          _toggleSelect(convos[i].id);
                        } else {
                          context.push(RoutePaths.conversation(convos[i].id));
                        }
                      },
                      onLongPress: () =>
                          _selecting ? null : _enterSelect(convos[i].id),
                    ),
                  );
                },
              ),
            ),
            if (_selecting) _deleteBar(),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final f in _ChatFilter.values) ...[
            _FilterChip(
              label: f.label,
              selected: _filter == f,
              onTap: () => setState(() => _filter = f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _deleteBar() {
    final n = _selected.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (n == 0 || _deleting) ? null : () => _deleteSelected(n),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.delete_outline),
            label: Text(n == 0 ? 'Delete' : 'Delete ($n)'),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.sageLight : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppColors.sage : AppColors.parchment),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.sageDark : AppColors.muted)),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.asVendor,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Conversation conversation;
  final bool asVendor;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadFor(asVendor: asVendor);
    final title = c.titleFor(asVendor: asVendor);
    final preview = c.lastMessagePreview ??
        (c.isBooking ? 'Booking conversation' : 'New enquiry');

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? AppColors.sageLight : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (selecting) ...[
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.sage : AppColors.faint,
              ),
              const SizedBox(width: 14),
            ],
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
                      if (unread && !selecting) ...[
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
