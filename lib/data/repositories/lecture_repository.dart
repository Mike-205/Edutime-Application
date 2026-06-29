import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lecture.dart';
import '../models/venue.dart';

/// A user-presentable scheduling failure. The Edge Functions return a readable
/// `message` for conflicts (e.g. "That venue is taken by Stats II …"); this
/// carries it to the UI without leaking Supabase types.
class LectureFailure implements Exception {
  const LectureFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads/writes lectures via Supabase.
///
/// Reads go through the client under RLS (a user only sees their own cohort).
/// Writes go through the schedule/edit/cancel Edge Functions, which pre-check
/// for conflicts and return a forwardable error; the DB EXCLUDE constraints are
/// the ground truth.
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

  /// Bookable venues (reference data) for the lecture form's picker.
  Future<List<Venue>> loadVenues() async {
    final rows = await _client.from('venues').select().order('name');
    return rows.map(Venue.fromMap).toList();
  }

  /// Schedules a one-time ([weeks] == 1) or weekly recurring lecture. Throws
  /// [LectureFailure] with the readable conflict message on a clash.
  Future<void> schedule({
    required String unitName,
    required String lecturerName,
    required String venueId,
    required DateTime start,
    required DateTime end,
    int weeks = 1,
  }) {
    return _invoke('schedule-lecture', {
      'unit_name': unitName,
      'lecturer_name': lecturerName,
      'venue_id': venueId,
      'start_time': start.toUtc().toIso8601String(),
      'end_time': end.toUtc().toIso8601String(),
      'weeks': weeks,
    });
  }

  /// Edits a single occurrence. Only the provided fields change.
  Future<void> editLecture({
    required String lectureId,
    String? unitName,
    String? lecturerName,
    String? venueId,
    DateTime? start,
    DateTime? end,
  }) {
    return _invoke('edit-lecture', {
      'lecture_id': lectureId,
      'unit_name': ?unitName,
      'lecturer_name': ?lecturerName,
      'venue_id': ?venueId,
      'start_time': ?start?.toUtc().toIso8601String(),
      'end_time': ?end?.toUtc().toIso8601String(),
    });
  }

  /// Cancels one occurrence, or the whole recurring series when [series] is set.
  Future<void> cancelLecture(String lectureId, {bool series = false}) {
    return _invoke('cancel-lecture', {
      'lecture_id': lectureId,
      'scope': series ? 'series' : 'single',
    });
  }

  Future<void> _invoke(String name, Map<String, dynamic> body) async {
    try {
      await _client.functions.invoke(name, body: body);
    } on FunctionException catch (e) {
      throw LectureFailure(_messageFor(e));
    }
  }

  String _messageFor(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      // Conflict responses carry a ready-to-show message.
      final message = details['message'];
      if (message is String && message.isNotEmpty) return message;
      return switch (details['error']?.toString()) {
        'forbidden' => 'Only a class rep can change the schedule.',
        'invalid_time_range' => 'The end time must be after the start time.',
        'invalid_weeks' => 'Choose between 1 and 26 weeks.',
        'missing_fields' => 'Please fill in every field.',
        'not_in_your_cohort' => 'That lecture is not in your cohort.',
        _ => 'Something went wrong. Please try again.',
      };
    }
    return 'Something went wrong. Please try again.';
  }
}
