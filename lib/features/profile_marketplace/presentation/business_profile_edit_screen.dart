import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../models/business.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../../support/support_content.dart';
import '../application/business_profile_controller.dart';

/// Full editable business profile: logo + marketplace cover, contact
/// details, socials, tags, and a "request featured" toggle. The business
/// name & category are locked for 90 days after a change (enforced by the
/// update_business_profile RPC).
class BusinessProfileEditScreen extends ConsumerStatefulWidget {
  const BusinessProfileEditScreen({super.key});

  @override
  ConsumerState<BusinessProfileEditScreen> createState() =>
      _BusinessProfileEditScreenState();
}

class _BusinessProfileEditScreenState
    extends ConsumerState<BusinessProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _tiktok = TextEditingController();
  final _googleMaps = TextEditingController();
  final _tags = TextEditingController();
  String? _category;
  bool _featuredRequested = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    final biz = ref.read(activeMembershipProvider).valueOrNull?.business;
    if (biz != null) _seed(biz);
  }

  void _seed(Business b) {
    _name.text = b.name;
    _description.text = b.description ?? '';
    _phone.text = b.phone ?? '';
    _email.text = b.email ?? '';
    _address.text = b.address ?? '';
    _whatsapp.text = b.whatsappNumber ?? '';
    _instagram.text = b.instagramUrl ?? '';
    _facebook.text = b.facebookUrl ?? '';
    _tiktok.text = b.tiktokUrl ?? '';
    _googleMaps.text = b.googleMapsUrl ?? '';
    _tags.text = b.badges.join(', ');
    _category = b.category;
    _featuredRequested = b.featuredRequested;
    _seeded = true;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _description, _phone, _email, _address, _whatsapp,
      _instagram, _facebook, _tiktok, _googleMaps, _tags,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  bool _isLocked(Business b) {
    final until = b.nameCategoryLockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  Future<void> _appealLock(Business b) async {
    final until = b.nameCategoryLockedUntil != null
        ? DateFormat('MMM d, y').format(b.nameCategoryLockedUntil!.toLocal())
        : 'the lock date';
    final uri = Uri(
      scheme: 'mailto',
      path: SupportContent.supportEmail,
      query: 'subject=${Uri.encodeComponent('Name/category change appeal — ${b.name}')}'
          '&body=${Uri.encodeComponent('I\'d like to change my business name or category before the 90-day lock ends (currently locked until $until).\n\nBusiness: ${b.name}\nReason for the early change:\n')}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showAppSnackBar(
        context,
        message: 'No email app found. Reach us at ${SupportContent.supportEmail}',
        isError: true,
      );
    }
  }

  Future<void> _pickImage(bool isCover) async {
    final biz = ref.read(activeMembershipProvider).valueOrNull?.business;
    if (biz == null) return;
    final ok = await ref
        .read(businessProfileControllerProvider.notifier)
        .pickAndUploadImage(businessId: biz.id, isCover: isCover);
    if (!mounted) return;
    if (ok) {
      showAppSnackBar(context, message: isCover ? 'Cover updated' : 'Logo updated');
    } else {
      final err = ref.read(businessProfileControllerProvider).error;
      if (err != null) {
        showAppSnackBar(
          context,
          message: AppException.from(err).message,
          isError: true,
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final biz = ref.read(activeMembershipProvider).valueOrNull?.business;
    if (biz == null) return;
    final badges = _tags.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final status = await ref
        .read(businessProfileControllerProvider.notifier)
        .save(
          businessId: biz.id,
          name: _name.text.trim(),
          category: _category,
          description: _nullIfEmpty(_description.text),
          phone: _nullIfEmpty(_phone.text),
          email: _nullIfEmpty(_email.text),
          address: _nullIfEmpty(_address.text),
          whatsappNumber: _nullIfEmpty(_whatsapp.text),
          instagramUrl: _nullIfEmpty(_instagram.text),
          facebookUrl: _nullIfEmpty(_facebook.text),
          tiktokUrl: _nullIfEmpty(_tiktok.text),
          googleMapsUrl: _nullIfEmpty(_googleMaps.text),
          badges: badges,
          featuredRequested: _featuredRequested,
        );
    if (!mounted) return;
    if (status == 'ok') {
      showAppSnackBar(context, message: 'Profile saved');
    } else if (status == 'locked') {
      showAppSnackBar(
        context,
        message: 'Name & category are locked until '
            '${DateFormat('MMM d, y').format(biz.nameCategoryLockedUntil!.toLocal())} '
            '(90-day change limit). Other details were saved.',
        isError: true,
      );
    } else {
      final err = ref.read(businessProfileControllerProvider).error;
      showAppSnackBar(
        context,
        message: AppException.from(err ?? 'Save failed').message,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    if (membership == null) return const SizedBox.shrink();
    final business = membership.business;
    if (!_seeded) _seed(business);
    final canManage = can(membership.role, Permission.manageSettings);
    final saving = ref.watch(businessProfileControllerProvider).isLoading;
    final locked = _isLocked(business);

    return Scaffold(
      appBar: AppBar(title: const Text('Business profile')),
      body: AbsorbPointer(
        absorbing: saving,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ── Cover + logo ──────────────────────────────────────────
              _CoverEditor(
                url: business.coverImageUrl,
                enabled: canManage,
                onTap: () => _pickImage(true),
              ),
              Transform.translate(
                offset: const Offset(0, -32),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _LogoEditor(
                    url: business.logoUrl,
                    enabled: canManage,
                    onTap: () => _pickImage(false),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!canManage)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Only an owner or admin can edit the business profile.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    // ── Basics ──────────────────────────────────────────
                    _section(context, 'Basics'),
                    TextFormField(
                      controller: _name,
                      enabled: canManage && !locked,
                      decoration: const InputDecoration(labelText: 'Business name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a business name'
                          : null,
                    ),
                    const SizedBox(height: 12),
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
                      onChanged: (canManage && !locked)
                          ? (v) => setState(() => _category = v)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: locked
                              ? AppColors.parchment
                              : AppColors.sageLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  locked
                                      ? Icons.lock_outline
                                      : Icons.info_outline,
                                  size: 18,
                                  color: AppColors.sageDark,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    locked
                                        ? 'Your business name and category are '
                                            'locked until '
                                            '${DateFormat('MMM d, y').format(business.nameCategoryLockedUntil!.toLocal())}. '
                                            'They can only be changed once '
                                            'every 90 days.'
                                        : 'Heads up: your business name and '
                                            'category can only be changed once '
                                            'every 90 days. Changing either now '
                                            'locks both until '
                                            '${DateFormat('MMM d, y').format(DateTime.now().add(const Duration(days: 90)))}.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.sageDark),
                                  ),
                                ),
                              ],
                            ),
                            if (locked)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _appealLock(business),
                                  style: TextButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Appeal this lock'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      enabled: canManage,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Tell clients what you do…',
                      ),
                    ),

                    // ── Contact & location ──────────────────────────────
                    _section(context, 'Contact & location'),
                    _field(_phone, 'Phone', canManage,
                        keyboardType: TextInputType.phone),
                    _field(_email, 'Email', canManage,
                        keyboardType: TextInputType.emailAddress),
                    _field(_address, 'Address / area', canManage,
                        hint: 'Shown on your marketplace listing'),

                    // ── Socials ─────────────────────────────────────────
                    _section(context, 'Social links'),
                    _field(_whatsapp, 'WhatsApp number', canManage,
                        keyboardType: TextInputType.phone),
                    _field(_instagram, 'Instagram URL', canManage),
                    _field(_facebook, 'Facebook URL', canManage),
                    _field(_tiktok, 'TikTok URL', canManage),
                    _field(_googleMaps, 'Google Maps URL', canManage),

                    // ── Marketplace ─────────────────────────────────────
                    _section(context, 'Marketplace'),
                    _field(_tags, 'Keywords / tags', canManage,
                        hint: 'Comma-separated, e.g. fade, beard, kids'),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Request featured listing'),
                      subtitle: const Text(
                        'Ask to be featured in Discover (reviewed by our team).',
                      ),
                      value: _featuredRequested,
                      onChanged: canManage
                          ? (v) => setState(() => _featuredRequested = v)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    if (canManage)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saving ? null : _save,
                          child: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save profile'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _field(
    TextEditingController c,
    String label,
    bool enabled, {
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _CoverEditor extends StatelessWidget {
  const _CoverEditor({
    required this.url,
    required this.enabled,
    required this.onTap,
  });

  final String? url;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const ColoredBox(
                color: AppColors.parchment,
                child: Icon(Icons.image_outlined, color: AppColors.muted),
              ),
            )
          else
            Container(
              color: AppColors.sageLight,
              child: const Center(
                child: Icon(Icons.photo_size_select_actual_outlined,
                    size: 40, color: AppColors.sageDark),
              ),
            ),
          if (enabled)
            Positioned(
              right: 12,
              bottom: 40,
              child: _EditChip(label: 'Change cover', onTap: onTap),
            ),
        ],
      ),
    );
  }
}

class _LogoEditor extends StatelessWidget {
  const _LogoEditor({
    required this.url,
    required this.enabled,
    required this.onTap,
  });

  final String? url;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
            else
              const Icon(Icons.storefront_outlined, color: AppColors.muted),
            if (enabled)
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.sage,
                    child: Icon(Icons.edit, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditChip extends StatelessWidget {
  const _EditChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
