import 'package:supabase_flutter/supabase_flutter.dart';

/// The only exception type that should ever cross a repository boundary.
/// Repositories catch Supabase/Postgrest-specific exceptions and rethrow
/// as this, so the application/presentation layers never need to know
/// about Supabase internals.
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is AuthException) {
      return AppException(_friendlyAuthMessage(error), cause: error);
    }
    if (error is PostgrestException) {
      return AppException(_friendlyPostgrestMessage(error), cause: error);
    }
    return AppException('Something went wrong. Please try again.', cause: error);
  }

  static String _friendlyAuthMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }
    return e.message;
  }

  static String _friendlyPostgrestMessage(PostgrestException e) {
    if (e.code == '23505') return 'That record already exists.';
    if (e.code == '23P01') {
      return 'That time slot is no longer available.';
    }
    if (e.code == 'PGRST116') return 'Record not found.';
    return e.message;
  }

  @override
  String toString() => message;
}
