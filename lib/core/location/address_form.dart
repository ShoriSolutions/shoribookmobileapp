import 'package:flutter/material.dart';
import '../../models/address.dart';
import '../errors/app_exception.dart';
import '../theme/app_colors.dart';
import '../utils/location_service.dart';
import 'countries.dart';

/// Reusable, country-aware address entry. Field labels and postal-code
/// visibility adapt to the selected country (see [addressConfigFor]), and
/// "Use my current location" reverse-geocodes the device position into the
/// fields — which stay fully editable afterwards. Emits the current
/// [Address] via [onChanged]; the host owns validation and saving.
///
/// Designed to be dropped into registration, profile editing, vendor
/// address updates, delivery addresses, etc. without duplicating logic.
class AddressForm extends StatefulWidget {
  const AddressForm({
    super.key,
    this.initial,
    required this.onChanged,
    this.streetLabel = 'Street address (optional)',
    this.showUseMyLocation = true,
  });

  final Address? initial;
  final ValueChanged<Address> onChanged;
  final String streetLabel;
  final bool showUseMyLocation;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  String? _countryCode;
  String? _countryName;
  final _admin = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  final _street = TextEditingController();
  double? _lat;
  double? _lng;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a != null) {
      _countryCode = a.countryCode;
      _countryName = a.countryName ?? countryByCode(a.countryCode)?.name;
      _admin.text = a.adminArea ?? '';
      _city.text = a.city ?? '';
      _postal.text = a.postalCode ?? '';
      _street.text = a.street ?? '';
      _lat = a.latitude;
      _lng = a.longitude;
    }
    for (final c in [_admin, _city, _postal, _street]) {
      c.addListener(_emit);
    }
  }

  @override
  void dispose() {
    for (final c in [_admin, _city, _postal, _street]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nz(String s) => s.trim().isEmpty ? null : s.trim();

  Address get _current => Address(
        countryCode: _countryCode,
        countryName: _countryName,
        adminArea: _nz(_admin.text),
        city: _nz(_city.text),
        postalCode: _nz(_postal.text),
        street: _nz(_street.text),
        latitude: _lat,
        longitude: _lng,
      );

  void _emit() => widget.onChanged(_current);

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (picked == null) return;
    setState(() {
      _countryCode = picked.code;
      _countryName = picked.name;
    });
    _emit();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final addr = await resolveCurrentAddress();
      setState(() {
        _lat = addr.latitude;
        _lng = addr.longitude;
        if (addr.countryCode != null) {
          _countryCode = addr.countryCode;
          _countryName =
              countryByCode(addr.countryCode)?.name ?? addr.countryName;
        }
        if (addr.adminArea != null) _admin.text = addr.adminArea!;
        if (addr.city != null) _city.text = addr.city!;
        if (addr.postalCode != null) _postal.text = addr.postalCode!;
        if (addr.street != null) _street.text = addr.street!;
      });
      _emit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location filled in — please review the fields.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = addressConfigFor(_countryCode);
    final country = countryByCode(_countryCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showUseMyLocation) ...[
          OutlinedButton.icon(
            onPressed: _locating ? null : _useMyLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('📍', style: TextStyle(fontSize: 16)),
            label: Text(_locating ? 'Locating…' : 'Use my current location'),
          ),
          const SizedBox(height: 4),
          Text(
            'Optional — this only runs when you tap it. It speeds up entry '
            'and improves nearby discovery, and you can edit every field '
            'afterwards.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
        ],
        InkWell(
          onTap: _pickCountry,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Country',
              border: OutlineInputBorder(),
            ),
            child: Text(
              country != null ? '${country.flag}  ${country.name}' : 'Select…',
              style: country == null
                  ? const TextStyle(color: AppColors.muted)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _admin,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: cfg.adminLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _city,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'City / Town',
            border: OutlineInputBorder(),
          ),
        ),
        if (cfg.usesPostalCode) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _postal,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: '${cfg.postalLabel} (optional)',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _street,
          maxLines: 2,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: widget.streetLabel,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet listing countries (Caribbean first) with live search.
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? kAllCountries
        : kAllCountries
            .where((c) =>
                c.name.toLowerCase().contains(q) || c.code.toLowerCase() == q)
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search countries',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                final caribbeanHeader = q.isEmpty && i == 0;
                final otherHeader =
                    q.isEmpty && i == kCaribbeanCountries.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caribbeanHeader) const _SheetHeader('Caribbean'),
                    if (otherHeader) const _SheetHeader('Other countries'),
                    ListTile(
                      leading:
                          Text(c.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(c.name),
                      onTap: () => Navigator.pop(context, c),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
      );
}
