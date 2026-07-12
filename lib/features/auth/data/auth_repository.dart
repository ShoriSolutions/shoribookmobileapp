import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../support/support_content.dart';

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
        data: {
          'full_name': fullName,
          'role': 'user',
          'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
          'terms_version': SupportContent.termsVersion,
        },
      );
      return response.session != null;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Business (entrepreneur) self-registration. Mirrors signUpCustomer
  /// but with role: 'entrepreneur' — the value the profiles-creation
  /// trigger reads to set profiles.role. The business itself can't be
  /// created here: with email confirmation on there's no session yet, so
  /// the name/category are stashed in the signup metadata and drained by
  /// register_business() on first login (see AuthRepository.registerBusiness
  /// and the 20260711000000 migration). Returns true if a session was
  /// returned immediately (autoconfirm on), false if confirmation is
  /// required first.
  Future<bool> signUpBusiness({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
    required String category,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'entrepreneur',
          'pending_business_name': businessName,
          'pending_business_category': category,
          'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
          'terms_version': SupportContent.termsVersion,
        },
      );
      return response.session != null;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Creates the caller's business + OWNER membership. SECURITY DEFINER
  /// RPC — idempotent and a cheap no-op for anyone who isn't a brand-new
  /// entrepreneur, so it's safe to call on every login. Pass [name] /
  /// [category] for the in-app "create business" form; omit them to have
  /// the RPC use the details captured in signup metadata. Returns the
  /// RPC's result map (its 'status' is 'created' only when a business was
  /// actually made, 'exists' if the owner already had one).
  Future<Map<String, dynamic>?> registerBusiness({
    String? name,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) {
        params['p_name'] = name.trim();
      }
      if (category != null && category.trim().isNotEmpty) {
        params['p_category'] = category.trim();
      }
      final result = await _client.rpc(
        'register_business',
        params: params.isEmpty ? null : params,
      );
      return (result as Map?)?.cast<String, dynamic>();
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
