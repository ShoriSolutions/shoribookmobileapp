import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../models/business.dart';

/// Bottom-sheet version of the booking link (QR + copy / share / WhatsApp),
/// so it can be opened from the Home FAB without leaving the screen.
Future<void> showBookingShareSheet(BuildContext context, Business business) {
  final url = 'https://betterbooking.app/book/${business.slug}';
  final shareText =
      'Book your next appointment with ${business.name} here: $url';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share booking link',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.parchment),
                ),
                child: QrImageView(
                  data: url,
                  size: 180,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  url,
                  style: const TextStyle(color: AppColors.sageDark),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (sheetContext.mounted) {
                          showAppSnackBar(sheetContext, message: 'Link copied');
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Share.share(shareText),
                      icon: const Icon(Icons.share_outlined, color: Colors.white),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final digits = (business.whatsappNumber ?? '')
                        .replaceAll(RegExp(r'[^0-9+]'), '');
                    final waUrl = digits.isEmpty
                        ? 'https://wa.me/?text=${Uri.encodeComponent(shareText)}'
                        : 'https://wa.me/$digits?text=${Uri.encodeComponent(shareText)}';
                    launchUrl(
                      Uri.parse(waUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Share via WhatsApp'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
