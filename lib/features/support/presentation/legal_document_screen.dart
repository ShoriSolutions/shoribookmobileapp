import 'package:flutter/material.dart';

/// Simple scrollable viewer for a titled block of text (Terms of Service,
/// Privacy Policy). Pushed from the Support screen.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            body.trim(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
      ),
    );
  }
}
