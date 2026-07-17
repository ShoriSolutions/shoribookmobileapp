import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers appointments booked as a guest on THIS device so the guest
/// can view them later. We store the appointment id + the phone used —
/// both are required by the server (get_guest_appointments) to return
/// anything, so a device alone never exposes someone else's bookings.
class GuestBookingsStore {
  static const _key = 'guest_bookings_v1';

  Future<void> add({required String id, required String phone}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _read(prefs);
    if (list.any((e) => e['id'] == id)) return;
    list.add({'id': id, 'phone': phone});
    await prefs.setString(_key, jsonEncode(list));
  }

  /// All remembered {id, phone} pairs.
  Future<List<Map<String, String>>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs)
        .map((e) => {'id': '${e['id']}', 'phone': '${e['phone']}'})
        .toList();
  }

  /// The phone used for a given appointment id, if remembered.
  Future<String?> phoneFor(String id) async {
    final prefs = await SharedPreferences.getInstance();
    for (final e in _read(prefs)) {
      if (e['id'] == id) return e['phone'] as String?;
    }
    return null;
  }

  List<Map<String, dynamic>> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
