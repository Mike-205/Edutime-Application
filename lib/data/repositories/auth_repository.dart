import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// A user-presentable authentication failure. Keeps Supabase/GoTrue types out
/// of the BLoC and UI layers.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Authentication + current-user profile access via Supabase.
///
/// All Supabase calls live here (never in widgets/BLoCs). Role is read from the
/// `users` table under RLS — never from the JWT — so [loadMyProfile] returns
/// only the caller's own row, and [watchMyProfile] streams live changes to it
/// (e.g. a promotion) without requiring a re-login.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// The signed-in user's id, or null when signed out.
  String? get currentUserId => _auth.currentUser?.id;

  /// Emits the current user's id on sign-in and on the restored initial
  /// session, and `null` on sign-out. Drives session restore in [AuthBloc].
  ///
  /// `distinct` collapses the frequent same-user events (token refresh, user
  /// updated) so the BLoC does not reload the profile and re-subscribe on every
  /// token refresh — it reacts only when the signed-in identity actually
  /// changes.
  Stream<String?> userIdChanges() =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id).distinct();

  /// Registers a new account. [fullName] is carried in user metadata; the
  /// `handle_new_user` DB trigger creates the matching `users` profile row with
  /// role hard-defaulted to `student` (the client never picks its own role).
  /// With email confirmations disabled (MVP), this also signs the user in.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (_) {
      throw const AuthFailure(
        'Could not create your account. Please try again.',
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (_) {
      throw const AuthFailure('Could not sign you in. Please try again.');
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Loads the caller's own profile row. Returns null if the profile row does
  /// not exist yet (e.g. the trigger has not committed). RLS guarantees this
  /// can only ever return the caller's own row.
  Future<AppUser?> loadMyProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : AppUser.fromMap(row);
  }

  /// Streams the caller's own profile row for live role changes (promotion).
  /// RLS scopes realtime to the caller's own row.
  Stream<AppUser?> watchMyProfile(String userId) {
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isEmpty ? null : AppUser.fromMap(rows.first));
  }
}
