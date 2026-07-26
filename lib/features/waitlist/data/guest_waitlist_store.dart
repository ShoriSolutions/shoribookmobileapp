import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers waitlist entries joined as a guest on THIS device so the guest
/// can view/leave them later. Stores the entry id + the phone used — both are
/// required by the server (get_guest_waitlist) to return anything, so a device
/// alone never exposes someone else's waitlist.
class GuestWaitlistStore {
  static const _key = 'guest_waitlist_v1';

  Future<void> add({required String id, required String phone}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _read(prefs);
    if (list.any((e) => e['id'] == id)) return;
    list.add({'id': id, 'phone': phone});
    await prefs.setString(_key, jsonEncode(list));
  }

  Future<List<Map<String, String>>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs)
        .map((e) => {'id': '${e['id']}', 'phone': '${e['phone']}'})
        .toList();
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
