import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lecture.dart';

/// Reads/writes lectures via Supabase.
///
/// Reads go through the client under RLS (a user only sees their own cohort).
/// Writes go through the `schedule-lecture` Edge Function, which pre-checks for
/// conflicts and returns a forwardable error; the DB EXCLUDE constraints are
/// the ground truth. This is a template — methods are filled in during the
/// scheduling milestone.
class LectureRepository {
  LectureRepository(this._client);

  final SupabaseClient _client;

  /// Upcoming lectures for the signed-in user's cohort, ordered by start time.
  Future<List<Lecture>> upcomingForMyCohort() async {
    final rows = await _client
        .from('lectures')
        .select()
        .gte('end_time', DateTime.now().toUtc().toIso8601String())
        .neq('status', 'canceled')
        .order('start_time');
    return rows.map(Lecture.fromMap).toList();
  }

  /// Realtime stream of the cohort's lectures for live calendar updates.
  Stream<List<Lecture>> watchMyCohort() {
    return _client
        .from('lectures')
        .stream(primaryKey: ['id'])
        .order('start_time')
        .map((rows) => rows.map(Lecture.fromMap).toList());
  }

  // TODO(scheduling milestone): schedule(), reschedule(), cancel() via the
  // schedule-lecture Edge Function.
}
