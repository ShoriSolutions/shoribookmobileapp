import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../models/profile.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../support/support_content.dart';

/// Lets a signed-in customer edit their own name, phone, and profile photo.
/// Email is shown read-only — changing it goes through support (the
/// "Request change" button opens a prefilled email). All writes go through
/// the update_my_profile RPC, which never touches email, role, or trust.
class CustomerProfileEditScreen extends ConsumerStatefulWidget {
  const CustomerProfileEditScreen({super.key});

  @override
  ConsumerState<CustomerProfileEditScreen> createState() =>
      _CustomerProfileEditScreenState();
}

class _CustomerProfileEditScreenState
    extends ConsumerState<CustomerProfileEditScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  Uint8List? _pickedBytes; // a newly chosen photo not yet uploaded
  String? _pickedExt;
  String? _avatarUrl; // the currently stored photo
  bool _removePhoto = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seed(Profile p) {
    _name.text = p.fullName;
    _phone.text = p.phone ?? '';
    _avatarUrl = p.avatarUrl;
    _seeded = true;
  }

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final parts = file.name.split('.');
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedExt = parts.length > 1 ? parts.last : 'jpg';
      _removePhoto = false;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, message: 'Please enter your name', isError: true);
      return;
    }
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      String? avatarUrl = _avatarUrl;
      if (_pickedBytes != null) {
        avatarUrl = await repo.uploadAvatar(
          userId: userId,
          bytes: _pickedBytes!,
          fileExtension: _pickedExt ?? 'jpg',
        );
      } else if (_removePhoto) {
        avatarUrl = null;
      }
      await repo.updateMyProfile(
        fullName: name,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        avatarUrl: avatarUrl,
      );
      await ref.read(myProfileProvider.notifier).refresh();
      if (mounted) {
        showAppSnackBar(context, message: 'Profile updated');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestEmailChange(String currentEmail) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SupportContent.supportEmail,
      query: 'subject=Email change request'
          '&body=I would like to change the email on my BetterBooking '
          'account.%0A%0ACurrent email: $currentEmail%0ANew email: ',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw const AppException('Could not open your email app.');
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Email us at ${SupportContent.supportEmail}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppException.from(e).message)),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not signed in'));
          }
          if (!_seeded) _seed(profile);

          ImageProvider? avatarProvider;
          if (_pickedBytes != null) {
            avatarProvider = MemoryImage(_pickedBytes!);
          } else if (!_removePhoto && _avatarUrl != null) {
            avatarProvider = CachedNetworkImageProvider(_avatarUrl!);
          }
          final name = _name.text.trim();
          final initial = name.isNotEmpty
              ? name[0].toUpperCase()
              : (profile.email.isNotEmpty ? profile.email[0].toUpperCase() : '?');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.sageLight,
                      foregroundColor: AppColors.sageDark,
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? Text(initial, style: const TextStyle(fontSize: 32))
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: _saving ? null : _pick,
                          icon: const Icon(Icons.photo_camera_outlined,
                              size: 18),
                          label: const Text('Change photo'),
                        ),
                        if (avatarProvider != null)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _removePhoto = true;
                                      _pickedBytes = null;
                                      _pickedExt = null;
                                    }),
                            child: const Text('Remove',
                                style: TextStyle(color: AppColors.danger)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                // Keeps the avatar's fallback initial in sync as they type.
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: profile.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.lock_outline, size: 18),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your email can only be changed by support.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _requestEmailChange(profile.email),
                    child: const Text('Request change'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
