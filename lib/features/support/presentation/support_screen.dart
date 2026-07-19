import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../support_content.dart';
import 'legal_document_screen.dart';

/// C16 · Help & FAQ — searchable FAQ list plus a "Still need a hand?"
/// contact card. Legal/privacy documents live below.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _search = TextEditingController();
  String _query = '';
  int? _expanded = 0; // first item open by default

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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

  void _openDoc(BuildContext context, String title, String body) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(title: title, body: body),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final faq = SupportContent.faq;
    final q = _query.trim().toLowerCase();
    final filtered = <(int, (String, String))>[];
    for (var i = 0; i < faq.length; i++) {
      if (q.isEmpty ||
          faq[i].$1.toLowerCase().contains(q) ||
          faq[i].$2.toLowerCase().contains(q)) {
        filtered.add((i, faq[i]));
      }
    }

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
                  const Text('Help & FAQ',
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
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search help',
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: AppColors.parchment),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: AppColors.parchment),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide:
                            const BorderSide(color: AppColors.sage, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final entry in filtered) ...[
                    _FaqCard(
                      question: entry.$2.$1,
                      answer: entry.$2.$2,
                      expanded: _expanded == entry.$1,
                      onTap: () => setState(() =>
                          _expanded = _expanded == entry.$1 ? null : entry.$1),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No results — try different words.',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    ),
                  const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Still need a hand?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sageDark)),
          const SizedBox(height: 4),
          const Text('We usually reply within a day.',
              style: TextStyle(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => _email(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sage,
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: const Text('Contact support',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
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

class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.parchment),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(question,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                ),
                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.sageDark),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Text(answer,
                  style: const TextStyle(
                      fontSize: 14.5, height: 1.4, color: AppColors.muted)),
            ],
          ],
        ),
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
