import 'package:shared_preferences/shared_preferences.dart';
import '../../support/support_content.dart';

/// Remembers that the user agreed to the Terms & Privacy on this device. Keyed
/// to the terms VERSION, so bumping SupportContent.termsVersion re-prompts
/// everyone on next launch.
class TermsPrefs {
  static const _key = 'accepted_terms_version';

  Future<bool> accepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == SupportContent.termsVersion;
  }

  Future<void> setAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, SupportContent.termsVersion);
  }
}
