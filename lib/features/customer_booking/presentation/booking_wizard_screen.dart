import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/customer_time_zone.dart';
import '../../../core/time/time_zone_service.dart';
import '../../../core/utils/calendar_export.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/input_hints.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/service.dart';
import '../../../models/staff_profile.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/presentation/widgets/category_visuals.dart';
import '../application/booking_wizard_controller.dart';
import '../application/booking_wizard_state.dart';

const _cancellationPolicyText =
    "24 hours' notice to cancel or reschedule; late cancellations or "
    'no-shows may be charged.';

/// The customer booking flow: service picker → C05 schedule (pro/date/time)
/// → C06 confirm (guest-first) → C07 confirmed. Driven by one wizard
/// controller keyed by business slug.
class BookingWizardScreen extends ConsumerStatefulWidget {
  final String slug;

  /// When set, the flow opens straight onto C05 with this service chosen
  /// (tap-to-book from a business profile). Null starts on the picker.
  final String? initialServiceId;

  const BookingWizardScreen({
    super.key,
    required this.slug,
    this.initialServiceId,
  });

  @override
  ConsumerState<BookingWizardScreen> createState() =>
      _BookingWizardScreenState();
}

class _BookingWizardScreenState extends ConsumerState<BookingWizardScreen> {
  /// Whether the initial-service preselect has been scheduled and resolved
  /// (once resolved we never re-run it — "Book another" legitimately clears
  /// the service and should land on the picker, not re-preselect).
  bool _preselectScheduled = false;
  bool _preselectResolved = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(businessProfileProvider(widget.slug));
    final state = ref.watch(bookingWizardControllerProvider(widget.slug));
    final controller =
        ref.read(bookingWizardControllerProvider(widget.slug).notifier);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: ErrorRetryView(
            message: 'Could not load this business.',
            onRetry: () =>
                ref.invalidate(businessProfileProvider(widget.slug)),
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Business not found'));
          }

          // Open straight onto the chosen service, once.
          if (!_preselectScheduled && widget.initialServiceId != null) {
            _preselectScheduled = true;
            final match = data.services
                .where((s) => s.id == widget.initialServiceId)
                .toList();
            if (match.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => controller.selectService(match.first));
            } else {
              _preselectResolved = true; // bad id → fall through to picker
            }
          }
          if (state.selectedService != null) _preselectResolved = true;

          // Hide the one-frame flash of the picker while the preselect runs.
          if (_preselectScheduled && !_preselectResolved) {
            return const Center(child: CircularProgressIndicator());
          }

          switch (state.step) {
            case BookingWizardStep.service:
              return _ServicePicker(slug: widget.slug, services: data.services);
            case BookingWizardStep.schedule:
              return _ScheduleScreen(slug: widget.slug, data: data);
            case BookingWizardStep.confirm:
              return _ConfirmScreen(slug: widget.slug, data: data);
            case BookingWizardStep.confirmation:
              return _ConfirmedScreen(slug: widget.slug, data: data);
          }
        },
      ),
    );
  }
}

// ── Shared header ────────────────────────────────────────────────────────

class _PushHeader extends StatelessWidget {
  const _PushHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}

/// Sticky terracotta footer with a primary action and an optional summary
/// line, matching C05/C06.
class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.label,
    required this.onPressed,
    this.summary,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? summary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        boxShadow: [
          BoxShadow(
              color: Color(0x0D1E1B16), blurRadius: 18, offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy ? null : onPressed,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Text(summary!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The service summary card at the top of C05 / C06.
class _ServiceSummaryCard extends StatelessWidget {
  const _ServiceSummaryCard({
    required this.service,
    required this.businessName,
    required this.category,
    this.onChange,
  });

  final Service service;
  final String businessName;
  final String? category;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(category);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: visual.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(visual.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('${service.durationMinutes} min · $businessName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCurrency(service.price, service.currency),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sageDark)),
              if (onChange != null)
                GestureDetector(
                  onTap: onChange,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Change',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sageDark)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Service picker (entry when no service preselected) ────────────────────

class _ServicePicker extends ConsumerWidget {
  const _ServicePicker({required this.slug, required this.services});
  final String slug;
  final List<Service> services;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bookingWizardControllerProvider(slug).notifier);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PushHeader(title: 'Choose a service', onBack: () => context.pop()),
          Expanded(
            child: services.isEmpty
                ? const Center(child: Text('No services available for booking.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (c, i) {
                      final s = services[i];
                      return _ServiceRowTile(
                        service: s,
                        onTap: () => controller.selectService(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRowTile extends StatelessWidget {
  const _ServiceRowTile({required this.service, required this.onTap});
  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.parchment),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text('${service.durationMinutes} min'
                        '${service.depositRequired ? ' · deposit' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              Text(formatCurrency(service.price, service.currency),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sageDark)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

// ── C05 · Pro, date & time ────────────────────────────────────────────────

class _ScheduleScreen extends ConsumerWidget {
  const _ScheduleScreen({required this.slug, required this.data});
  final String slug;
  final BusinessProfileData data;

  static const _avatarColors = [
    (bg: AppColors.sage, fg: Colors.white),
    (bg: AppColors.terracotta, fg: Colors.white),
    (bg: AppColors.shoriBlue, fg: AppColors.ink),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingWizardControllerProvider(slug));
    final controller = ref.read(bookingWizardControllerProvider(slug).notifier);
    final service = state.selectedService;
    if (service == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Eligible pros: those linked to this service (or all bookable if the
    // service has no explicit links), mirroring availability logic.
    final assigned = data.serviceStaffLinks[service.id];
    final eligible = (assigned == null || assigned.isEmpty)
        ? data.staff.where((s) => s.isBookable).toList()
        : data.staff
            .where((s) => s.isBookable && assigned.contains(s.id))
            .toList();

    return SafeArea(
      child: Column(
        children: [
          _PushHeader(title: 'Book', onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                _ServiceSummaryCard(
                  service: service,
                  businessName: data.business.name,
                  category: data.business.category,
                  onChange: () => controller.changeService(),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Choose your pro'),
                const SizedBox(height: 12),
                _ProRow(
                  slug: slug,
                  eligible: eligible,
                  selectedId: state.selectedStaff?.id,
                  colors: _avatarColors,
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Pick a date'),
                const SizedBox(height: 12),
                _DateRow(slug: slug, data: data),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const _SectionLabel('Available times'),
                    const SizedBox(width: 8),
                    if (state.selectedDate != null)
                      Text(DateFormat('EEE, d MMM').format(state.selectedDate!),
                          style: const TextStyle(
                              fontSize: 13.5, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 12),
                _TimesGrid(slug: slug, data: data),
              ],
            ),
          ),
          _StickyFooter(
            label: 'Continue',
            onPressed: state.canContinueFromSchedule
                ? () => controller.continueToConfirm()
                : null,
            summary: _footerSummary(state),
          ),
        ],
      ),
    );
  }

  String? _footerSummary(BookingWizardState state) {
    if (state.selectedDate == null || state.selectedTime == null) return null;
    final who = state.selectedStaff?.name ?? 'any pro';
    return '${DateFormat('EEE, d MMM').format(state.selectedDate!)} · '
        '${_fmtTime(state.selectedTime!)} · with $who';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink));
  }
}

class _ProRow extends ConsumerWidget {
  const _ProRow({
    required this.slug,
    required this.eligible,
    required this.selectedId,
    required this.colors,
  });

  final String slug;
  final List<StaffProfile> eligible;
  final String? selectedId;
  final List<({Color bg, Color fg})> colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bookingWizardControllerProvider(slug).notifier);
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ProAvatar(
            label: 'Any',
            selected: selectedId == null,
            background: AppColors.sageLight,
            onTap: () => controller.selectStaff(null),
            child: const Icon(Icons.groups_outlined,
                color: AppColors.sageDark, size: 26),
          ),
          for (var i = 0; i < eligible.length; i++)
            _ProAvatar(
              label: eligible[i].name,
              selected: selectedId == eligible[i].id,
              background: colors[i % colors.length].bg,
              onTap: () => controller.selectStaff(eligible[i]),
              child: Text(
                eligible[i].name.isNotEmpty
                    ? eligible[i].name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors[i % colors.length].fg),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProAvatar extends StatelessWidget {
  const _ProAvatar({
    required this.label,
    required this.selected,
    required this.child,
    required this.background,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget child;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: AppColors.sage, width: 2.5)
                        : null,
                  ),
                  child: child,
                ),
                if (selected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.sage,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                            BorderSide(color: AppColors.cream, width: 2)),
                      ),
                      child: const Icon(Icons.check,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.ink : AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends ConsumerWidget {
  const _DateRow({required this.slug, required this.data});
  final String slug;
  final BusinessProfileData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingWizardControllerProvider(slug));
    final controller = ref.read(bookingWizardControllerProvider(slug).notifier);
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final date = base.add(Duration(days: i));
          final selected = state.selectedDate != null &&
              _sameDay(state.selectedDate!, date);
          final available = _dayIsOpen(date);
          return _DateChip(
            date: date,
            selected: selected,
            available: available,
            onTap: available ? () => controller.selectDate(date) : null,
          );
        },
      ),
    );
  }

  bool _dayIsOpen(DateTime date) {
    if (data.hours.isEmpty) return true; // unknown → let the times grid decide
    final dow = date.weekday % 7; // 0=Sun..6=Sat
    final entry = data.hours.where((h) => h.dayOfWeek == dow);
    if (entry.isEmpty) return false;
    return !entry.first.isClosed;
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Colors.white
        : (available ? AppColors.ink : AppColors.faint);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.sage
              : (available ? AppColors.white : AppColors.fieldMuted),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.sage : AppColors.parchment),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateFormat('EEE').format(date),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white70 : AppColors.muted)),
            const SizedBox(height: 2),
            Text('${date.day}',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _TimesGrid extends ConsumerWidget {
  const _TimesGrid({required this.slug, required this.data});
  final String slug;
  final BusinessProfileData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingWizardControllerProvider(slug));
    final controller = ref.read(bookingWizardControllerProvider(slug).notifier);
    final service = state.selectedService;
    final date = state.selectedDate;
    if (service == null || date == null) {
      return const Text('Pick a date to see available times.',
          style: TextStyle(color: AppColors.muted));
    }

    final args = (
      slug: slug,
      serviceId: service.id,
      staffId: state.selectedStaff?.id,
      date: date,
    );
    final slotsAsync = ref.watch(availableSlotsProvider(args));

    return slotsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => ErrorRetryView(
        message: 'Could not load available times.',
        onRetry: () => ref.invalidate(availableSlotsProvider(args)),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No times available for this date.\nTry a different date or pro.',
              style: TextStyle(color: AppColors.muted),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemCount: slots.length,
          itemBuilder: (c, i) {
            final slot = slots[i];
            final selected = slot.startTime == state.selectedTime;
            return GestureDetector(
              onTap: () => controller.selectTime(slot.startTime),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.sage : AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected ? AppColors.sage : AppColors.parchment),
                ),
                child: Text(_fmtTime(slot.startTime),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.ink)),
              ),
            );
          },
        );
      },
    );
  }
}

// ── C06 · Confirm — guest-first ───────────────────────────────────────────

class _ConfirmScreen extends ConsumerStatefulWidget {
  const _ConfirmScreen({required this.slug, required this.data});
  final String slug;
  final BusinessProfileData data;

  @override
  ConsumerState<_ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<_ConfirmScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;

  @override
  void initState() {
    super.initState();
    final s = ref.read(bookingWizardControllerProvider(widget.slug));
    _firstName = TextEditingController(text: s.firstName);
    _lastName = TextEditingController(text: s.lastName);
    _phone = TextEditingController(text: s.phone);
    _whatsapp = TextEditingController(text: s.whatsapp);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final controller =
        ref.read(bookingWizardControllerProvider(widget.slug).notifier);
    await controller.submit();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingWizardControllerProvider(widget.slug));
    final controller =
        ref.read(bookingWizardControllerProvider(widget.slug).notifier);
    final service = state.selectedService;
    final date = state.selectedDate;
    final time = state.selectedTime;
    if (service == null || date == null || time == null) {
      return const Center(child: Text('Missing booking details'));
    }
    final business = widget.data.business;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: _PushHeader(
            title: 'Confirm booking',
            onBack: () => controller.goToStep(BookingWizardStep.schedule),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              _summaryCard(context, service, business.name, date, time,
                  state.selectedStaff?.name, business.address),
              if (_zonesDiffer(date, time)) ...[
                const SizedBox(height: 12),
                _tzNotice(business.timezone),
              ],
              const SizedBox(height: 20),
              const Text('Your details',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'First name',
                      controller: _firstName,
                      onChanged: (v) =>
                          controller.updateDetails(firstName: v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Last name',
                      controller: _lastName,
                      onChanged: (v) => controller.updateDetails(lastName: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
                hint: kPhoneHint,
                onChanged: (v) => controller.updateDetails(phone: v),
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'WhatsApp · optional, same as phone if blank',
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                hint: kWhatsAppHint,
                onChanged: (v) => controller.updateDetails(whatsapp: v),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppColors.sage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "No account needed — we'll send your confirmation and a "
                      'reminder by text.',
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _dividerLabel('or save your details'),
              const SizedBox(height: 14),
              _socialRow(context),
              const SizedBox(height: 16),
              _policyCard(state.policyAccepted,
                  (v) => controller.setPolicyAccepted(v)),
              if (service.depositRequired &&
                  service.effectiveDepositAmount != null) ...[
                const SizedBox(height: 12),
                _depositNote(service, business.currency, business.name),
              ],
              if (state.phoneConflict) ...[
                const SizedBox(height: 12),
                const Text(
                  'This phone number is linked to a different account at this '
                  'business. Please use a different number.',
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
              if (state.conflictMessage != null) ...[
                const SizedBox(height: 12),
                Text(state.conflictMessage!,
                    style: const TextStyle(color: AppColors.danger)),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(state.errorMessage!,
                    style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
        _StickyFooter(
          label:
              'Confirm booking · ${formatCurrency(service.price, business.currency)}',
          busy: state.isSubmitting,
          onPressed: state.canConfirm ? _confirm : null,
        ),
      ],
    );
  }

  Widget _summaryCard(
    BuildContext context,
    Service service,
    String businessName,
    DateTime date,
    String time,
    String? proName,
    String? address,
  ) {
    final visual = CategoryVisual.of(widget.data.business.category);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: visual.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visual.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(businessName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text('${service.name} · ${service.durationMinutes} min',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.divider, height: 1),
          ),
          _scheduleRows(date, time),
          const SizedBox(height: 10),
          _summaryRow(Icons.person_outline, 'with ${proName ?? 'any pro'}'),
          if ((address ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _summaryRow(Icons.location_on_outlined, address!),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.divider, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total · pay in person',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
              Text(formatCurrency(service.price, service.currency),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.sage),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink))),
      ],
    );
  }

  /// The date/time line(s): a single line when the customer is in the
  /// business's zone, or two clearly-labelled lines (Business time / Your
  /// local time) when they differ — DST-aware via TimeZoneService.
  Widget _scheduleRows(DateTime date, String time) {
    final bizZone = widget.data.business.timezone;
    final iso = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final utc = businessLocalToUtc(date: iso, time: time, timezone: bizZone);
    final custZone = ref.watch(customerTimeZoneProvider).valueOrNull;
    final differ =
        custZone != null && TimeZoneService.zonesDiffer(utc, bizZone, custZone);

    if (!differ) {
      return _summaryRow(
          Icons.calendar_today_outlined, TimeZoneService.dateTime(utc, bizZone));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dualTime('Business time', TimeZoneService.dateTime(utc, bizZone),
            '${TimeZoneService.friendlyName(bizZone)} time'),
        const SizedBox(height: 10),
        _dualTime('Your local time', TimeZoneService.dateTime(utc, custZone),
            'your time'),
      ],
    );
  }

  Widget _dualTime(String label, String value, String zoneLabel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule, size: 18, color: AppColors.sage),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AppColors.muted)),
              const SizedBox(height: 1),
              Text('$value  ·  $zoneLabel',
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ],
          ),
        ),
      ],
    );
  }

  /// Friendly, reassuring notice shown when the customer's zone differs from
  /// the business's — never framed as an error.
  Widget _tzNotice(String bizZone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sageTintBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.public, size: 18, color: AppColors.sageDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You're booking with a business in "
              '${TimeZoneService.friendlyName(bizZone)}. We\'ve automatically '
              'adjusted the appointment to your local time.',
              style: const TextStyle(fontSize: 13, color: AppColors.sageDark),
            ),
          ),
        ],
      ),
    );
  }

  /// True when the chosen slot renders in a different zone for the customer.
  bool _zonesDiffer(DateTime date, String time) {
    final bizZone = widget.data.business.timezone;
    final iso = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final utc = businessLocalToUtc(date: iso, time: time, timezone: bizZone);
    final custZone = ref.watch(customerTimeZoneProvider).valueOrNull;
    return custZone != null &&
        TimeZoneService.zonesDiffer(utc, bizZone, custZone);
  }

  Widget _dividerLabel(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.parchment)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ),
        const Expanded(child: Divider(color: AppColors.parchment)),
      ],
    );
  }

  Widget _socialRow(BuildContext context) {
    Widget tile(IconData icon, String label, Color color) {
      return Expanded(
        child: GestureDetector(
          onTap: () => context.push(RoutePaths.login),
          child: Container(
            height: 62,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.parchment),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(Icons.apple, 'Apple', AppColors.ink),
        tile(Icons.g_mobiledata, 'Google', const Color(0xFF4285F4)),
        tile(Icons.mail_outline, 'Email', AppColors.sageDark),
        tile(Icons.smartphone, 'Phone', AppColors.ink),
      ],
    );
  }

  Widget _policyCard(bool accepted, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!accepted),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.sageLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sageTintBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: accepted ? AppColors.sage : AppColors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: accepted ? AppColors.sage : AppColors.parchment),
              ),
              child: accepted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                        text: 'Cancellation policy — ',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: AppColors.ink)),
                    TextSpan(
                        text: '$_cancellationPolicyText I agree.',
                        style: TextStyle(color: AppColors.muted)),
                  ],
                ),
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _depositNote(Service service, String currency, String businessName) {
    final deposit = service.effectiveDepositAmount!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.terracottaTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.terracottaTintBorder),
      ),
      child: Text(
        'Deposit ${formatCurrency(deposit, currency)} — your booking is held '
        'as pending until paid; $businessName will arrange payment.',
        style: const TextStyle(fontSize: 13, color: AppColors.terracottaDeep),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

// ── C07 · Confirmed ───────────────────────────────────────────────────────

class _ConfirmedScreen extends ConsumerWidget {
  const _ConfirmedScreen({required this.slug, required this.data});
  final String slug;
  final BusinessProfileData data;

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingWizardControllerProvider(slug));
    final controller = ref.read(bookingWizardControllerProvider(slug).notifier);
    final business = data.business;
    final service = state.selectedService;
    final date = state.selectedDate;
    final time = state.selectedTime;
    final staff = state.selectedStaff;
    final apptId = state.createdAppointmentId;
    final reference = (apptId != null && apptId.length >= 8)
        ? apptId.substring(0, 8).toUpperCase()
        : apptId?.toUpperCase();
    final signedIn = ref.watch(authStatusProvider) == AuthStatus.authenticated;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.elasticOut,
                    builder: (c, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                          color: AppColors.sage, shape: BoxShape.circle),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Booking confirmed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 8),
                Text(
                  'Your appointment with ${business.name} is set. See you soon!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, height: 1.4, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                _detailsCard(service, staff, date, time, business.address,
                    reference),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notifications_none,
                        size: 18, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "We'll remind you before your appointment on the "
                        'details you gave.',
                        style: const TextStyle(
                            fontSize: 13.5, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                if (!signedIn) ...[
                  const SizedBox(height: 16),
                  _signUpNudge(context),
                ],
                const SizedBox(height: 20),
                _outlinedButton(
                  icon: Icons.event_available_outlined,
                  label: 'Add to calendar',
                  onPressed: (service == null || date == null || time == null)
                      ? null
                      : () {
                          final start = businessLocalToUtc(
                            date: _isoDate(date),
                            time: time,
                            timezone: business.timezone,
                          );
                          final end = start.add(
                              Duration(minutes: service.durationMinutes));
                          addAppointmentToCalendar(
                            title: '${service.name} at ${business.name}',
                            startUtc: start,
                            endUtc: end,
                            location: business.address,
                            description: reference != null
                                ? 'Booking reference $reference'
                                : null,
                          );
                        },
                ),
                const SizedBox(height: 10),
                _outlinedButton(
                  label: 'Book another',
                  onPressed: () => controller.bookAnother(),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(
                    signedIn ? RoutePaths.bookings : RoutePaths.discover),
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(
    Service? service,
    StaffProfile? staff,
    DateTime? date,
    String? time,
    String? address,
    String? reference,
  ) {
    final rows = <Widget>[
      if (service != null)
        _row(Icons.local_offer_outlined,
            '${service.name} · with ${staff?.name ?? 'any pro'}'),
      if (date != null && time != null)
        _row(Icons.calendar_today_outlined,
            '${DateFormat('EEE, d MMM').format(date)} · ${_fmtTime(time)}'),
      if ((address ?? '').isNotEmpty)
        _row(Icons.location_on_outlined, address!),
      if (reference != null)
        _row(Icons.confirmation_number_outlined, 'Booking ref\n$reference'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(color: AppColors.divider, height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  Widget _signUpNudge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.bookmark_border, color: AppColors.shoriBlue),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Create an account to reschedule or cancel in a tap.',
                style: TextStyle(fontSize: 14, color: AppColors.ink)),
          ),
          GestureDetector(
            onTap: () => context.push(RoutePaths.customerRegister),
            child: const Text('Sign up',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.sageDark)),
          ),
        ],
      ),
    );
  }

  Widget _outlinedButton({
    IconData? icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.parchment),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.ink),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

String _fmtTime(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.parse(parts[0]);
  final ampm = h >= 12 ? 'PM' : 'AM';
  final hour = h % 12 == 0 ? 12 : h % 12;
  return '$hour:${parts[1]} $ampm';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
