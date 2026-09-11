import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../routing/route_paths.dart';
import '../application/messaging_providers.dart';

// True while a chat is being opened, so repeat taps are ignored instead of
// stacking several copies of the chat screen.
bool _opening = false;

/// Opens the signed-in customer's chat with [businessId] (creating it on
/// first use), optionally about [bookingId]: new messages are then tagged
/// with that booking. Shows a friendly message if the chat can't be opened.
Future<void> openBusinessChat(
  BuildContext context,
  WidgetRef ref, {
  required String businessId,
  String? bookingId,
}) async {
  if (_opening) return;
  _opening = true;
  try {
    final id = await ref
        .read(messagingRepositoryProvider)
        .getOrCreateConversation(
            businessId: businessId, appointmentId: bookingId);
    if (context.mounted) {
      context.push(RoutePaths.conversation(id, bookingId: bookingId));
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context,
          message: _friendly(AppException.from(e).message), isError: true);
    }
  } finally {
    _opening = false;
  }
}

String _friendly(String msg) {
  if (msg.contains('pre_booking_disabled')) {
    return "This business isn't taking questions right now.";
  }
  if (msg.contains('messaging_disabled')) {
    return 'This business has messaging turned off.';
  }
  if (msg.contains('account_required')) {
    return 'Create an account to message businesses.';
  }
  if (msg.contains('invalid_booking')) {
    return "We couldn't find that booking.";
  }
  return msg;
}
