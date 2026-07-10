import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Uniform success/error feedback after every mutation (status change,
/// deposit marked paid, booking saved, etc.) — required by the brief
/// ("show success/error messages after updates").
void showAppSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: isError ? AppColors.danger : AppColors.ink,
      content: Text(message),
    ),
  );
}
