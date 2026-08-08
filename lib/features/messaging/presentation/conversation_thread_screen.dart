import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/appointment.dart';
import '../../../models/conversation.dart';
import '../../../models/message.dart';
import '../../../routing/route_paths.dart';
import '../application/messaging_providers.dart';

/// The conversation thread: booking summary (for booking chats), live
/// message history, read receipts, a typing indicator, quick actions, and
/// the composer. Muting/archiving/blocking/reporting live in the menu.
class ConversationThreadScreen extends ConsumerStatefulWidget {
  const ConversationThreadScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState
    extends ConsumerState<ConversationThreadScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  RealtimeChannel? _typing;
  Timer? _typingSelfStop;
  Timer? _typingPeerStop;
  bool _peerTyping = false;
  bool _sentTyping = false;

  bool get _asVendor => ref.read(isVendorMessagingProvider);
  String get _mySide => _asVendor ? 'vendor' : 'customer';

  @override
  void initState() {
    super.initState();
    // Mark read on open, and again whenever new inbound messages arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
    _setupTyping();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    _typingSelfStop?.cancel();
    _typingPeerStop?.cancel();
    _typing?.unsubscribe();
    super.dispose();
  }

  void _markRead() {
    ref
        .read(messagingRepositoryProvider)
        .markRead(widget.conversationId);
  }

  void _setupTyping() {
    final channel = ref
        .read(messagingRepositoryProvider)
        .typingChannel(widget.conversationId);
    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        if (payload['side'] == _mySide) return; // ignore my own echo
        if (!mounted) return;
        setState(() => _peerTyping = true);
        _typingPeerStop?.cancel();
        _typingPeerStop = Timer(const Duration(seconds: 3),
            () => mounted ? setState(() => _peerTyping = false) : null);
      },
    );
    channel.subscribe();
    _typing = channel;
  }

  void _onComposerChanged(String _) {
    if (_sentTyping) return;
    _sentTyping = true;
    _typing?.sendBroadcastMessage(
        event: 'typing', payload: {'side': _mySide});
    _typingSelfStop?.cancel();
    _typingSelfStop =
        Timer(const Duration(seconds: 2), () => _sentTyping = false);
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .sendMessage(widget.conversationId, text);
      _composer.clear();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: _friendly(AppException.from(e).message), isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: 'Could not open your photos. Please try again.',
            isError: true);
      }
      return;
    }
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final repo = ref.read(messagingRepositoryProvider);
      final path = await repo.uploadAttachment(widget.conversationId, bytes,
          ext: ext);
      await repo.sendMessage(widget.conversationId, '',
          type: 'image', attachmentUrl: path);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: _friendly(AppException.from(e).message), isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Why the customer can't type right now (vendor block, or the business is
  /// currently closed). Vendors can always reply. Returns null when open.
  String? _disabledReason(Conversation? conv, String title) {
    if (_asVendor || conv == null) return null;
    if (conv.blockedByVendor) {
      return 'You can no longer message this business.';
    }
    final gate =
        ref.watch(businessMessagingGateProvider(conv.businessId)).valueOrNull;
    if (gate != null && gate.restrictAfterHours && gate.open == false) {
      return '$title is closed right now. Send a message during opening '
          'hours and they\'ll get back to you.';
    }
    return null;
  }

  String _friendly(String msg) {
    if (msg.contains('messaging_disabled')) {
      return 'Messaging is turned off for this business.';
    }
    if (msg.contains('messaging_blocked')) {
      return 'You can no longer message this business.';
    }
    if (msg.contains('messaging_suspended')) {
      return 'Your messaging is temporarily restricted.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final conv = ref.watch(conversationByIdProvider(widget.conversationId));
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final title = conv?.titleFor(asVendor: _asVendor) ??
        (_asVendor ? 'Customer' : 'Business');
    // Peer photo: the customer's avatar (vendor view, avatar-only, no PII) or
    // the business logo (customer view).
    final avatars = _asVendor
        ? (ref.watch(customerAvatarsProvider).valueOrNull ??
            const <String, String>{})
        : const <String, String>{};
    final headerPhoto = _asVendor
        ? (conv?.customerUserId != null ? avatars[conv!.customerUserId] : null)
        : conv?.businessLogoUrl;

    // Re-mark read as new inbound messages stream in.
    ref.listen(messagesProvider(widget.conversationId), (_, next) {
      next.whenData((msgs) {
        if (msgs.any((m) => m.senderRole != _mySide && m.readAt == null)) {
          _markRead();
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.sageLight,
              foregroundColor: AppColors.sageDark,
              backgroundImage: (headerPhoto != null && headerPhoto.isNotEmpty)
                  ? CachedNetworkImageProvider(headerPhoto)
                  : null,
              child: (headerPhoto == null || headerPhoto.isEmpty)
                  ? Text(
                      title.trim().isNotEmpty
                          ? title.trim()[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  if (_peerTyping)
                    const Text('typing…',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.sageDark)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (conv != null)
            _ConversationMenu(conversation: conv, asVendor: _asVendor),
        ],
      ),
      body: Column(
        children: [
          if (conv != null && conv.isBooking && conv.appointmentId != null)
            _BookingSummary(
                appointmentId: conv.appointmentId!, asVendor: _asVendor),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Could not load messages.',
                    style: const TextStyle(color: AppColors.muted)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        conv?.isBooking ?? false
                            ? 'Say hello — ask about arrival time, parking, or '
                                'anything about your appointment.'
                            : 'Send a message to start the conversation.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  );
                }
                // Flatten into date separators + grouped bubbles (WhatsApp
                // style), chronological; the reversed list renders them
                // bottom-anchored with the newest at the bottom.
                final rows = _buildChatRows(messages);
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final row = rows[rows.length - 1 - i];
                    if (row.date != null) {
                      return _DateSeparator(day: row.date!);
                    }
                    final msg = row.msg!;
                    return _MessageBubble(
                      message: msg,
                      mine: msg.senderRole == _mySide,
                      showTail: row.showTail,
                      firstOfGroup: row.firstOfGroup,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _composer,
            sending: _sending,
            disabledReason: _disabledReason(conv, title),
            onChanged: _onComposerChanged,
            onSend: _send,
            onAttach: _pickAndSendImage,
          ),
        ],
      ),
    );
  }
}

// ── Booking summary + quick actions ────────────────────────────────────────
class _BookingSummary extends ConsumerWidget {
  const _BookingSummary({required this.appointmentId, required this.asVendor});
  final String appointmentId;
  final bool asVendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptAsync = ref.watch(conversationAppointmentProvider(appointmentId));
    return apptAsync.maybeWhen(
      data: (appt) => appt == null
          ? const SizedBox.shrink()
          : _card(context, appt),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _card(BuildContext context, Appointment appt) {
    final start = appt.startTime.toLocal();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sageTintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available,
                  size: 18, color: AppColors.sageDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(appt.serviceName ?? 'Appointment',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ),
              _statusPill(appt.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('EEE d MMM').format(start)} · '
            '${DateFormat.jm().format(start)}'
            '${appt.staffName != null ? ' · ${appt.staffName}' : ''}',
            style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _action(
                icon: Icons.receipt_long_outlined,
                label: 'View booking',
                onTap: () => context.push(
                  asVendor
                      ? RoutePaths.appointmentDetailPath(appt.id)
                      : RoutePaths.bookingDetail(appt.id),
                ),
              ),
              if (!asVendor &&
                  appt.businessPhone != null &&
                  appt.businessPhone!.isNotEmpty) ...[
                const SizedBox(width: 10),
                _action(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  onTap: () => _call(context, appt.businessPhone!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _action(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sageDark,
          side: const BorderSide(color: AppColors.sageTintBorder),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final label = switch (status) {
      'confirmed' => 'Confirmed',
      'pending' => 'Pending',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'no_show' => 'No-show',
      _ => status,
    };
    final ok = status == 'confirmed' || status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: ok ? AppColors.successBg : AppColors.closedBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ok ? AppColors.successText : AppColors.closedText)),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────
class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.showTail = true,
    this.firstOfGroup = true,
  });
  final Message message;
  final bool mine;
  // WhatsApp-style grouping: [showTail] draws the pointed corner only on the
  // last bubble of a run; [firstOfGroup] adds a little more space above the
  // first bubble of a run (consecutive bubbles sit tight together).
  final bool showTail;
  final bool firstOfGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.fieldMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(message.body,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
        ),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76),
        margin: EdgeInsets.only(top: firstOfGroup ? 8 : 2, bottom: 2),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
        decoration: BoxDecoration(
          color: mine ? AppColors.sage : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            // Pointed "tail" corner only on the last bubble of a run.
            bottomLeft: Radius.circular((!mine && showTail) ? 4 : 16),
            bottomRight: Radius.circular((mine && showTail) ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: AppColors.parchment),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.messageType == 'image' &&
                message.attachmentUrl != null) ...[
              _AttachmentImage(path: message.attachmentUrl!),
              if (message.body.isNotEmpty) const SizedBox(height: 6),
            ],
            if (message.body.isNotEmpty)
              Text(message.body,
                  style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      color: mine ? Colors.white : AppColors.ink)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat.jm().format(message.createdAt.toLocal()),
                    style: TextStyle(
                        fontSize: 10.5,
                        color: mine
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.faint)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.readAt != null ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.readAt != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Attachment image (private bucket -> signed URL, tap to view) ───────────
class _AttachmentImage extends ConsumerWidget {
  const _AttachmentImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(attachmentUrlProvider(path));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: urlAsync.when(
        loading: () => const _ImagePlaceholder(),
        error: (_, __) => const _ImagePlaceholder(icon: Icons.broken_image),
        data: (url) => GestureDetector(
          onTap: () => _openFull(context, url),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 220,
            fit: BoxFit.cover,
            placeholder: (_, __) => const _ImagePlaceholder(),
            errorWidget: (_, __, ___) =>
                const _ImagePlaceholder(icon: Icons.broken_image),
          ),
        ),
      ),
    );
  }

  void _openFull(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.icon});
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 160,
      color: AppColors.fieldMuted,
      child: Icon(icon ?? Icons.image_outlined, color: AppColors.faint),
    );
  }
}

// ── Composer ───────────────────────────────────────────────────────────────
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.disabledReason,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
  });
  final TextEditingController controller;
  final bool sending;
  final String? disabledReason;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    if (disabledReason != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.fieldMuted,
        child: Text(disabledReason!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted)),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: sending ? null : onAttach,
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.sageDark),
              tooltip: 'Send a photo',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: AppColors.cream,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.parchment),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.parchment),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide:
                        const BorderSide(color: AppColors.sage, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.sage,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overflow menu: mute / archive / block (vendor) / report ────────────────
class _ConversationMenu extends ConsumerWidget {
  const _ConversationMenu({required this.conversation, required this.asVendor});
  final Conversation conversation;
  final bool asVendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(messagingRepositoryProvider);
    final muted = conversation.mutedFor(asVendor: asVendor);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.ink),
      onSelected: (v) async {
        switch (v) {
          case 'mute':
            await repo.setFlag(conversation.id, mute: !muted);
            break;
          case 'archive':
            await repo.setFlag(conversation.id, archive: true);
            if (context.mounted) context.pop();
            break;
          case 'block':
            final ok = await showConfirmDialog(context,
                title: conversation.blockedByVendor
                    ? 'Unblock customer?'
                    : 'Block customer?',
                message: conversation.blockedByVendor
                    ? 'They will be able to message you again.'
                    : 'They will no longer be able to message you.',
                confirmLabel:
                    conversation.blockedByVendor ? 'Unblock' : 'Block');
            if (ok) {
              await repo.setBlocked(
                  conversation.id, !conversation.blockedByVendor);
            }
            break;
          case 'report':
            await _report(context, repo);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
            value: 'mute',
            child: Text(muted ? 'Unmute notifications' : 'Mute notifications')),
        const PopupMenuItem(value: 'archive', child: Text('Archive')),
        if (asVendor)
          PopupMenuItem(
              value: 'block',
              child: Text(conversation.blockedByVendor
                  ? 'Unblock customer'
                  : 'Block customer')),
        const PopupMenuItem(value: 'report', child: Text('Report conversation')),
      ],
    );
  }

  Future<void> _report(BuildContext context, dynamic repo) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'What is the problem? (abuse, spam, etc.)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Submit')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await repo.report(conversation.id, reason);
      if (context.mounted) {
        showAppSnackBar(context,
            message: 'Thanks — our team will review this conversation.');
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    }
  }
}

/// One rendered row in the thread: either a date separator or a message with
/// its WhatsApp-style grouping flags.
class _Row {
  const _Row._(this.date, this.msg, this.showTail, this.firstOfGroup);
  factory _Row.date(DateTime day) => _Row._(day, null, false, false);
  factory _Row.msg(Message m,
          {required bool showTail, required bool firstOfGroup}) =>
      _Row._(null, m, showTail, firstOfGroup);

  final DateTime? date;
  final Message? msg;
  final bool showTail;
  final bool firstOfGroup;
}

DateTime _dayOf(DateTime dt) {
  final l = dt.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Two messages belong to the same visual group when they're from the same
/// sender on the same day (and neither is a system message).
bool _sameGroup(Message? a, Message? b) {
  if (a == null || b == null) return false;
  if (a.isSystem || b.isSystem) return false;
  if (a.senderRole != b.senderRole) return false;
  return _dayOf(a.createdAt) == _dayOf(b.createdAt);
}

/// Builds the chronological row list: a date separator before the first
/// message of each day, then each message tagged with group boundaries.
List<_Row> _buildChatRows(List<Message> input) {
  // Guarantee chronological order (oldest -> newest) regardless of the source
  // order, so the reversed list shows the newest message at the bottom.
  final messages = [...input]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final rows = <_Row>[];
  DateTime? lastDay;
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    final day = _dayOf(m.createdAt);
    if (lastDay == null || day != lastDay) {
      rows.add(_Row.date(day));
      lastDay = day;
    }
    final prev = i > 0 ? messages[i - 1] : null;
    final next = i < messages.length - 1 ? messages[i + 1] : null;
    rows.add(_Row.msg(
      m,
      firstOfGroup: !_sameGroup(prev, m),
      showTail: !_sameGroup(m, next),
    ));
  }
  return rows;
}

/// Centered "Today / Yesterday / date" chip between days, like WhatsApp.
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.day});
  final DateTime day;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return DateFormat('EEEE').format(day);
    return DateFormat('d MMM yyyy').format(day);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.fieldMuted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _label(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}
