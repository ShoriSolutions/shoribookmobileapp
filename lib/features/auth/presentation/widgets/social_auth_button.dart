import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum SocialProvider { apple, google }

/// White outlined "Continue with Apple/Google" button used on the auth
/// screens. Sign-in wiring is provider-specific; the button just renders
/// the provider glyph + label and calls [onTap].
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.provider,
    required this.onTap,
  });

  final SocialProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isApple = provider == SocialProvider.apple;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.parchment),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isApple)
              const Icon(Icons.apple, size: 22, color: AppColors.ink)
            else
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                child: const Text('G',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4285F4))),
              ),
            const SizedBox(width: 10),
            Text('Continue with ${isApple ? 'Apple' : 'Google'}',
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
