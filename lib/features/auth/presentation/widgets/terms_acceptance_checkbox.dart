import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../support/presentation/legal_document_screen.dart';
import '../../../support/support_content.dart';

/// Checkbox with tappable Terms of Service / Privacy Policy links, shown
/// on the register screens. Sign-up stays disabled until this is checked.
class TermsAcceptanceCheckbox extends StatelessWidget {
  const TermsAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  void _open(BuildContext context, String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: AppColors.sageDark,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    final baseStyle = Theme.of(context).textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('I agree to the ', style: baseStyle),
                GestureDetector(
                  onTap: () => _open(
                    context,
                    'Terms of Service',
                    SupportContent.termsOfService,
                  ),
                  child: const Text('Terms of Service', style: linkStyle),
                ),
                Text(' and ', style: baseStyle),
                GestureDetector(
                  onTap: () => _open(
                    context,
                    'Privacy & Data',
                    SupportContent.privacyPolicy,
                  ),
                  child: const Text('Privacy Policy', style: linkStyle),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
