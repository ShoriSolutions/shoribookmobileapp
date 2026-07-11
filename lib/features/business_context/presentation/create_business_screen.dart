import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../models/business.dart';
import '../application/create_business_controller.dart';

/// In-app business creation for a signed-in entrepreneur who has no
/// business yet. On success the router redirects to the business home
/// once the membership resolves (see app_router.dart).
class CreateBusinessScreen extends ConsumerStatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  ConsumerState<CreateBusinessScreen> createState() =>
      _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends ConsumerState<CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _businessName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(createBusinessControllerProvider.notifier)
        .create(
          name: _businessName.text.trim(),
          category: _category ?? 'other',
        );
    if (!mounted) return;
    if (ok) {
      showAppSnackBar(context, message: 'Business created. Welcome!');
      // Navigation is handled by the router redirect once the membership
      // provider refreshes.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createBusinessControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create your business')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Set up your business',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Give it a name and pick what you do — you can add the '
                      'rest of your details later in Settings.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _businessName,
                      decoration: const InputDecoration(
                        labelText: 'Business name',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your business name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in BusinessCategory.all)
                          DropdownMenuItem(
                            value: c.value,
                            child: Text('${c.emoji}  ${c.label}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                      validator: (v) => v == null ? 'Choose a category' : null,
                    ),
                    if (state.hasError) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.error.toString(),
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create business'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
