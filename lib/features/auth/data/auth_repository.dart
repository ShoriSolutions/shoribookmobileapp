import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';

/// The only file in the auth feature allowed to touch SupabaseClient
/// directly — see the layering rule in the project plan.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Customer self-registration — matches the web app's
  /// src/app/(auth)/register/user/page.tsx signUp call exactly
  /// (role: 'user' in the metadata is what the profiles-creation
  /// trigger reads to set profiles.role). Returns true if a session
  /// was returned immediately, false if email confirmation is
  /// required first.
  Future<bool> signUpCustomer({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': 'user'},
      );
      return response.session != null;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'shoribook://auth/callback',
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Sets a new password for the current session — used both for a
  /// standard "forgot password" reset and for a newly-invited staff
  /// member setting their password for the first time (both land the
  /// user in an authenticated session via the same deep link).
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Flips a newly-invited membership from INVITED to ACTIVE. Safe to
  /// call on every login — the RPC's own WHERE clause makes repeat
  /// calls a no-op, so no "is this the first login" tracking is needed
  /// client-side.
  Future<void> markMembershipActive() async {
    try {
      await _client.rpc('mark_membership_active');
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
