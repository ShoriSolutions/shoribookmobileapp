import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/input_hints.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../models/customer.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/clients_providers.dart';

/// Handles both "add new client" (clientId == null) and "edit client"
/// (clientId provided) — same fields either way.
class ClientFormScreen extends ConsumerStatefulWidget {
  final String? clientId;

  const ClientFormScreen({super.key, this.clientId});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingExisting = false;

  @override
  void initState() {
    super.initState();
    if (widget.clientId != null) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoadingExisting = true);
    try {
      final customer = await ref
          .read(clientsRepositoryProvider)
          .fetchById(widget.clientId!);
      _firstName.text = customer.firstName;
      _lastName.text = customer.lastName ?? '';
      _phone.text = customer.phone;
      _whatsapp.text = customer.whatsappNumber ?? '';
      _email.text = customer.email ?? '';
    } catch (_) {
      // handled by the form staying blank + save failing with a clear error
    } finally {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(clientsRepositoryProvider);
      if (widget.clientId == null) {
        final membership = await ref.read(activeMembershipProvider.future);
        if (membership == null) return;
        await repo.findOrCreateByPhone(
          businessId: membership.business.id,
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
          whatsappNumber: _whatsapp.text,
          email: _email.text,
        );
      } else {
        final existing = await repo.fetchById(widget.clientId!);
        final updated = Customer(
          id: existing.id,
          businessId: existing.businessId,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
          phone: _phone.text.trim(),
          whatsappNumber:
              _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          notes: existing.notes,
          tags: existing.tags,
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
        );
        await repo.update(existing.id, updated);
        ref.invalidate(clientDetailProvider(existing.id));
      }
      ref.invalidate(clientsListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppException.from(e).message,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clientId == null ? 'New client' : 'Edit client'),
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _firstName,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'First name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastName,
                        decoration: const InputDecoration(
                          labelText: 'Last name (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          hintText: kPhoneHint,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Phone number is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _whatsapp,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp number (optional)',
                          hintText: kWhatsAppHint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save client'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
