import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/password_policy.dart';

/// A live checklist of the password rules that ticks green as the user
/// types. Pass the current password value; the parent rebuilds it on change.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final items = PasswordPolicy.checklist(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  it.met
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: it.met ? AppColors.sage : AppColors.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  it.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: it.met ? AppColors.ink : AppColors.muted,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
