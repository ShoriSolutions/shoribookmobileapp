import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../support_content.dart';
import 'legal_document_screen.dart';

/// C16 · Support — the company email and a phone number to call, plus the
/// required legal/privacy documents. Kept deliberately simple.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _email(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SupportContent.supportEmail,
      query: 'subject=${Uri.encodeComponent('Support request')}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnackBar(context,
          message: 'No email app found. Reach us at ${SupportContent.supportEmail}',
          isError: true);
    }
  }

  Future<void> _call(BuildContext context) async {
    final digits = SupportContent.supportPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: digits);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnackBar(context,
          message: 'Call us at ${SupportContent.supportPhone}', isError: true);
    }
  }

  void _openDoc(BuildContext context, String title, String body) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(title: title, body: body),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/account'),
                  ),
                  const SizedBox(width: 4),
                  const Text('Support',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _contactCard(context),
                  const SizedBox(height: 20),
                  const _GroupLabel('Legal & privacy'),
                  _legalCard(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.mail_outline, color: AppColors.sage),
            title: const Text('Email us'),
            subtitle: Text(SupportContent.supportEmail),
            trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
            onTap: () => _email(context),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ListTile(
            leading: const Icon(Icons.call_outlined, color: AppColors.sage),
            title: const Text('Call us'),
            subtitle: Text(SupportContent.supportPhone),
            trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
            onTap: () => _call(context),
          ),
        ],
      ),
    );
  }

  Widget _legalCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        children: [
          ListTile(
            leading:
                const Icon(Icons.description_outlined, color: AppColors.sage),
            title: const Text('Terms of Service'),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.faint),
            onTap: () => _openDoc(
                context, 'Terms of Service', SupportContent.termsOfService),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ListTile(
            leading:
                const Icon(Icons.privacy_tip_outlined, color: AppColors.sage),
            title: const Text('Privacy & data we collect'),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.faint),
            onTap: () =>
                _openDoc(context, 'Privacy & Data', SupportContent.privacyPolicy),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: AppColors.faint)),
    );
  }
}
