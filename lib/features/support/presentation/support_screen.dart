import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../support_content.dart';
import 'legal_document_screen.dart';

/// Help & Support: contact support, FAQ, and the legal/privacy documents
/// (including what data the app collects).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _email(BuildContext context, {String? subject, String? body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SupportContent.supportEmail,
      query: [
        if (subject != null) 'subject=${Uri.encodeComponent(subject)}',
        if (body != null) 'body=${Uri.encodeComponent(body)}',
      ].join('&'),
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnackBar(
        context,
        message: 'No email app found. Reach us at ${SupportContent.supportEmail}',
        isError: true,
      );
    }
  }

  void _openDoc(BuildContext context, String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Contact ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need a hand?', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Our team is happy to help with your account, bookings, '
                    'or anything else.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _email(
                        context,
                        subject: 'Support request',
                      ),
                      icon: const Icon(Icons.mail_outline, color: Colors.white),
                      label: const Text('Contact support'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── FAQ ──────────────────────────────────────────────────────
          Text('Frequently asked', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < SupportContent.faq.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ExpansionTile(
                    title: Text(
                      SupportContent.faq[i].$1,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SupportContent.faq[i].$2,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.muted, height: 1.4),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Legal & data ─────────────────────────────────────────────
          Text('Legal & privacy', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: AppColors.sage),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.muted),
                  onTap: () => _openDoc(
                    context,
                    'Terms of Service',
                    SupportContent.termsOfService,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.sage),
                  title: const Text('Privacy & data we collect'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.muted),
                  onTap: () => _openDoc(
                    context,
                    'Privacy & Data',
                    SupportContent.privacyPolicy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'ShoriBooks',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
