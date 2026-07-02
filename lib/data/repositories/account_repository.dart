import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-presentable account failure (e.g. the deletion request didn't submit).
class AccountFailure implements Exception {
  const AccountFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Account self-service: the surfaced Kenya DPA deletion path. Fulfilment is
/// manual at MVP — this records the request; the owner erases the account.
class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  /// Whether the signed-in user already has a pending deletion request.
  Future<bool> hasPendingDeletion() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('deletion_requests')
        .select('id')
        .eq('user_id', uid)
        .eq('status', 'pending')
        .maybeSingle();
    return row != null;
  }

  /// Submits a deletion request (deduped server-side).
  Future<void> requestDeletion() async {
    try {
      await _client.functions.invoke('request-account-deletion');
    } on FunctionException {
      throw const AccountFailure(
        'Could not submit your request. Please try again.',
      );
    }
  }
}
