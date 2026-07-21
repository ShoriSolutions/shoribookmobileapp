import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../theme/app_colors.dart';
import 'time_zone_service.dart';

/// A searchable IANA time-zone picker. Returns the chosen zone id, or the
/// sentinel [autoValue] for "Automatic (detect from device)", or null if
/// dismissed. Only shown when the user explicitly wants to override.
const String kTimeZoneAuto = '__auto__';

Future<String?> showTimeZonePicker(
  BuildContext context, {
  String? currentOverride, // the current zone (or override); null = automatic
  bool allowAutomatic = true, // false for the business zone (always explicit)
}) {
  TimeZoneService.ensureInitialized();
  final zones = tz.timeZoneDatabase.locations.keys.toList()..sort();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TimeZonePickerSheet(
      zones: zones,
      currentOverride: currentOverride,
      allowAutomatic: allowAutomatic,
    ),
  );
}

class _TimeZonePickerSheet extends StatefulWidget {
  const _TimeZonePickerSheet({
    required this.zones,
    required this.currentOverride,
    this.allowAutomatic = true,
  });

  final List<String> zones;
  final String? currentOverride;
  final bool allowAutomatic;

  @override
  State<_TimeZonePickerSheet> createState() => _TimeZonePickerSheetState();
}

class _TimeZonePickerSheetState extends State<_TimeZonePickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.zones
        : widget.zones
            .where((z) => z.toLowerCase().contains(q.replaceAll(' ', '_')))
            .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Time zone',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 10),
              TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search cities / regions',
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.parchment),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    if (widget.allowAutomatic) ...[
                      ListTile(
                        leading: const Icon(Icons.my_location,
                            color: AppColors.sageDark),
                        title: const Text('Automatic',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Detect from this device'),
                        trailing: widget.currentOverride == null
                            ? const Icon(Icons.check, color: AppColors.sage)
                            : null,
                        onTap: () => Navigator.pop(context, kTimeZoneAuto),
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                    ],
                    for (final z in filtered)
                      ListTile(
                        title: Text(TimeZoneService.friendlyName(z)),
                        subtitle: Text(z,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                        trailing: widget.currentOverride == z
                            ? const Icon(Icons.check, color: AppColors.sage)
                            : null,
                        onTap: () => Navigator.pop(context, z),
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
}
