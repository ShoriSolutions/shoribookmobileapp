/// A vendor's reminder/notification configuration (read from
/// notification_settings). Scheduling is server-side; the app only edits
/// these preferences.
class NotificationSettings {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool whatsappEnabled;
  final bool smsEnabled;

  /// Minutes-before-appointment for each reminder (1440 = 24h, 120 = 2h…).
  final List<int> reminderOffsets;
  final String reminderTemplate;
  final bool whatsappConnected;

  const NotificationSettings({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.whatsappEnabled,
    required this.smsEnabled,
    required this.reminderOffsets,
    required this.reminderTemplate,
    required this.whatsappConnected,
  });

  /// Defaults used when a business hasn't saved settings yet.
  static const defaults = NotificationSettings(
    pushEnabled: true,
    emailEnabled: true,
    whatsappEnabled: false,
    smsEnabled: false,
    reminderOffsets: [1440, 120],
    reminderTemplate:
        'Hi {{customer_name}}, this is a reminder of your {{service_name}} '
        'appointment with {{business_name}} on {{date}} at {{time}}. '
        'Ref: {{booking_reference}}',
    whatsappConnected: false,
  );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        pushEnabled: json['push_enabled'] as bool? ?? true,
        emailEnabled: json['email_enabled'] as bool? ?? true,
        whatsappEnabled: json['whatsapp_enabled'] as bool? ?? false,
        smsEnabled: json['sms_enabled'] as bool? ?? false,
        reminderOffsets:
            (json['reminder_offsets'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [1440, 120],
        reminderTemplate:
            json['reminder_template'] as String? ?? defaults.reminderTemplate,
        whatsappConnected: json['whatsapp_connected'] as bool? ?? false,
      );

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? whatsappEnabled,
    bool? smsEnabled,
    List<int>? reminderOffsets,
    String? reminderTemplate,
  }) => NotificationSettings(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
    smsEnabled: smsEnabled ?? this.smsEnabled,
    reminderOffsets: reminderOffsets ?? this.reminderOffsets,
    reminderTemplate: reminderTemplate ?? this.reminderTemplate,
    whatsappConnected: whatsappConnected,
  );
}

/// Preset reminder offsets (minutes → label), in descending order.
const reminderPresets = <int, String>{
  10080: '7 days',
  4320: '3 days',
  1440: '24 hours',
  720: '12 hours',
  120: '2 hours',
  60: '1 hour',
  30: '30 min',
};

/// Human label for any offset in minutes (handles custom values too).
String reminderOffsetLabel(int minutes) {
  if (reminderPresets.containsKey(minutes)) return reminderPresets[minutes]!;
  if (minutes % 1440 == 0) return '${minutes ~/ 1440} day(s)';
  if (minutes % 60 == 0) return '${minutes ~/ 60} hour(s)';
  return '$minutes min';
}
