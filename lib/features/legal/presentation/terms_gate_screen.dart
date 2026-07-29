import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bubble_background.dart';
import '../../../core/widgets/shori_logo.dart';
import '../../support/presentation/legal_document_screen.dart';
import '../../support/support_content.dart';
import '../application/terms_providers.dart';

/// First-launch gate: everyone must agree to the Terms & Privacy before using
/// the app. Presented as a branded popup-style card; agreement is remembered
/// per terms version, so it only shows again when the terms change.
class TermsGateScreen extends ConsumerStatefulWidget {
  const TermsGateScreen({super.key});

  @override
  ConsumerState<TermsGateScreen> createState() => _TermsGateScreenState();
}

class _TermsGateScreenState extends ConsumerState<TermsGateScreen> {
  bool _saving = false;

  Future<void> _agree() async {
    setState(() => _saving = true);
    await acceptTerms(ref);
    // The router's redirect moves the user on once the flag flips.
  }

  void _open(String title, String body) {
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
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    return Scaffold(
      backgroundColor: kBubbleBeige,
      body: Stack(
        children: [
          const Positioned.fill(child: BubbleBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ShoriLogo(markSize: 64, showWordmark: false),
                      const SizedBox(height: 20),
                      const Text('Welcome to Shorivo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      const SizedBox(height: 8),
                      const Text(
                        'Before you start, please review and agree to how we '
                        'keep your data safe and how the app works.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14.5, height: 1.4, color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Read our ',
                              style: TextStyle(color: AppColors.ink)),
                          GestureDetector(
                            onTap: () => _open(
                                'Terms of Service', SupportContent.termsOfService),
                            child: const Text('Terms of Service',
                                style: linkStyle),
                          ),
                          const Text(' and ',
                              style: TextStyle(color: AppColors.ink)),
                          GestureDetector(
                            onTap: () => _open(
                                'Privacy & Data', SupportContent.privacyPolicy),
                            child:
                                const Text('Privacy Policy', style: linkStyle),
                          ),
                          const Text('.', style: TextStyle(color: AppColors.ink)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _agree,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Agree & continue',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'By continuing you agree to the Terms of Service and '
                        'Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.faint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
