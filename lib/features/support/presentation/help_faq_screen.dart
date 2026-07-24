import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../support_content.dart';
import 'legal_document_screen.dart';

/// Help & FAQ — a searchable list of common questions, with the legal /
/// privacy documents below. Contacting a human lives on the separate
/// Support screen.
class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  final _search = TextEditingController();
  String _query = '';
  // Which question is expanded, tracked by its text so it's stable across
  // both sections. The first customer question starts open.
  String? _expanded = SupportContent.customerFaq.first.$1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openDoc(BuildContext context, String title, String body) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(title: title, body: body),
    ));
  }

  List<Widget> _section(List<(String, String)> items) {
    return [
      for (final item in items) ...[
        _FaqCard(
          question: item.$1,
          answer: item.$2,
          expanded: _expanded == item.$1,
          onTap: () => setState(
              () => _expanded = _expanded == item.$1 ? null : item.$1),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<(String, String)> _filter(List<(String, String)> faq) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return faq;
    return [
      for (final item in faq)
        if (item.$1.toLowerCase().contains(q) ||
            item.$2.toLowerCase().contains(q))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final customer = _filter(SupportContent.customerFaq);
    final vendor = _filter(SupportContent.vendorFaq);
    final noResults = customer.isEmpty && vendor.isEmpty;

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
                  if (customer.isNotEmpty) ...[
                    const _GroupLabel('For customers'),
                    ..._section(customer),
                    const SizedBox(height: 12),
                  ],
                  if (vendor.isNotEmpty) ...[
                    const _GroupLabel('For businesses'),
                    ..._section(vendor),
                    const SizedBox(height: 12),
                  ],
                  if (noResults)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No results — try different words.',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    ),
                  const SizedBox(height: 8),
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
            trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
            onTap: () => _openDoc(
                context, 'Terms of Service', SupportContent.termsOfService),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ListTile(
            leading:
                const Icon(Icons.privacy_tip_outlined, color: AppColors.sage),
            title: const Text('Privacy & data we collect'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
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
