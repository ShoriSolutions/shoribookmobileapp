import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../business_context/application/active_business_provider.dart';

class BookingLinkScreen extends ConsumerWidget {
  const BookingLinkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    if (membership == null) return const SizedBox.shrink();

    final business = membership.business;
    final url = 'https://betterbooking.app/book/${business.slug}';
    final shareText =
        'Book your next appointment with ${business.name} here: $url';

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Link')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.parchment),
                  ),
                  child: QrImageView(
                    data: url,
                    size: 200,
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
                const SizedBox(height: 20),
                Text(
                  business.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (context.mounted) {
                            showAppSnackBar(context, message: 'Link copied');
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
        ),
      ),
    );
  }
}
