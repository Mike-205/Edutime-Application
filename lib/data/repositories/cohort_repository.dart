import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/cohort.dart';

/// A user-presentable cohort/membership failure. Keeps Supabase types out of
/// the BLoC and UI.
class CohortFailure implements Exception {
  const CohortFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cohort reads (direct, under RLS) and membership mutations (through the
/// service-role Edge Functions). Joining, removal, code regeneration and
/// promotion never touch users.cohort_id/role directly from the client — those
/// are guarded columns, mutated only server-side.
class CohortRepository {
  CohortRepository(this._client);

  final SupabaseClient _client;

  /// Joins the caller to the cohort matching [code]. Throws [CohortFailure]
  /// with a friendly message on an invalid code or if already in a cohort.
  Future<Cohort> joinByCode(String code) async {
    final data = await _invoke('join-cohort-by-code', {
      'join_code': code.trim(),
    });
    return Cohort.fromMap((data['cohort'] as Map).cast<String, dynamic>());
  }

  /// Loads a cohort with its program + faculty names for display.
  Future<Cohort?> loadCohort(String cohortId) async {
    final row = await _client
        .from('cohorts')
        .select('*, programs(name, faculties(name))')
        .eq('id', cohortId)
        .maybeSingle();
    return row == null ? null : Cohort.fromMap(row);
  }

  /// Cohort directory (name + role only, never email). Returns rows only for a
  /// class rep — RLS/`get_cohort_members()` yields nothing for other roles.
  Future<List<AppUser>> cohortMembers() async {
    final rows = await _client.rpc('get_cohort_members') as List;
    return rows.map((row) {
      final m = (row as Map).cast<String, dynamic>();
      return AppUser(
        id: m['user_id'] as String,
        fullName: m['full_name'] as String,
        role: userRoleFromDb(m['role'] as String),
      );
    }).toList();
  }

  Future<String> regenerateJoinCode() async {
    final data = await _invoke('regenerate-join-code', const {});
    return data['join_code'] as String;
  }

  Future<void> removeStudent(String userId) =>
      _invoke('remove-student', {'user_id': userId});

  Future<void> promoteClassRep(String userId) =>
      _invoke('promote-class-rep', {'user_id': userId});

  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.functions.invoke(name, body: body);
      final data = res.data;
      return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
    } on FunctionException catch (e) {
      throw CohortFailure(_messageFor(e));
    }
  }

  String _messageFor(FunctionException e) {
    final details = e.details;
    final code = details is Map ? details['error']?.toString() : null;
    return switch (code) {
      'invalid_code' => "That join code didn't match any cohort.",
      'already_in_cohort' =>
        "You're already in a cohort. Ask your class rep to remove you first.",
      'join_code_required' => 'Enter a join code.',
      'forbidden' => "You don't have permission to do that.",
      'not_in_your_cohort' => 'That student is not in your cohort.',
      'cannot_remove_self' => "You can't remove yourself.",
      'cannot_remove_rep' => "You can't remove another rep.",
      'unauthorized' => 'Please sign in again.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
