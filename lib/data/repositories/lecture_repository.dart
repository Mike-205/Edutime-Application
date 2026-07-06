import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/course.dart';
import '../models/lecture.dart';
import '../models/venue.dart';
import '../models/venue_availability.dart';

/// A user-presentable scheduling failure. The Edge Functions return a readable
/// `message` for conflicts (e.g. "That venue is taken by Stats II …"); this
/// carries it to the UI without leaking Supabase types.
class LectureFailure implements Exception {
  const LectureFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads/writes events (lectures) via Supabase.
///
/// Reads go through the client under RLS (a user only sees their own cohort).
/// Writes go through the schedule/edit/cancel Edge Functions, which pre-check
/// for conflicts and return a forwardable error; the DB EXCLUDE constraints are
/// the ground truth.
class LectureRepository {
  LectureRepository(this._client);

  final SupabaseClient _client;

  /// Upcoming lectures for the signed-in user's cohort, ordered by start time.
  /// Embeds the course name for display.
  Future<List<Lecture>> upcomingForMyCohort() async {
    final rows = await _client
        .from('events')
        .select('*, course:courses(name, abbreviation)')
        .gte('end_time', DateTime.now().toUtc().toIso8601String())
        .neq('status', 'canceled')
        .order('start_time');
    return rows.map(Lecture.fromMap).toList();
  }

  /// The cohort's non-canceled schedule with course + venue names embedded, for
  /// the calendar. RLS scopes rows to the caller's cohort. [from]/[to] bound the
  /// window (NFR: time-windowed reads, never a full-semester refetch); omit for
  /// the whole schedule.
  Future<List<Lecture>> loadCohortSchedule({
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _client
        .from('events')
        .select(
          '*, course:courses(name, abbreviation), '
          'venue:venues(type, label, room:rooms(number, building:buildings(abbreviation)))',
        )
        .neq('status', 'canceled');
    if (from != null) {
      query = query.gte('end_time', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte('start_time', to.toUtc().toIso8601String());
    }
    final rows = await query.order('start_time');
    return rows.map(Lecture.fromMap).toList();
  }

  /// Realtime nudge: emits whenever the cohort's events change. Streams can't
  /// embed joins, so consumers treat each emission as "something changed" and
  /// refetch the enriched window via [loadCohortSchedule] — the same shape the
  /// planned Broadcast-from-Postgres migration will take (nudge -> refetch).
  Stream<void> watchMyCohort() {
    return _client.from('events').stream(primaryKey: ['id']).map((_) {});
  }

  /// Bookable venues (reference data) for the form's picker, with the room +
  /// building joined so a physical venue can show its composed `abbrev-number`
  /// name. Sorted client-side because that name is composed, not a stored column.
  Future<List<Venue>> loadVenues() async {
    final rows = await _client
        .from('venues')
        .select(
          'id, type, label, room:rooms(number, building:buildings(abbreviation, name))',
        );
    return rows.map(Venue.fromMap).toList()..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  }

  /// Physical venues and whether each is occupied at [at] (Journey 3). Goes
  /// through the `venue_availability` DB function (SECURITY DEFINER) because
  /// occupancy is cross-cohort and RLS scopes event reads to the caller's own
  /// cohort — the function reveals only room busy-ness, no schedule details.
  Future<List<VenueSlot>> venueAvailability(DateTime at) async {
    final rows = await _client.rpc(
      'venue_availability',
      params: {'at_time': at.toUtc().toIso8601String()},
    );
    return (rows as List)
        .map((r) => VenueSlot.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Courses for the signed-in user's cohort program — the schedulable units
  /// for the form's picker. Resolves cohort -> program -> courses under RLS.
  Future<List<Course>> loadCoursesForMyCohort() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final me = await _client
        .from('users')
        .select('cohort_id')
        .eq('id', userId)
        .maybeSingle();
    final cohortId = me?['cohort_id'] as String?;
    if (cohortId == null) return const [];
    final cohort = await _client
        .from('cohorts')
        .select('program_id')
        .eq('id', cohortId)
        .maybeSingle();
    final programId = cohort?['program_id'] as String?;
    if (programId == null) return const [];
    final rows = await _client
        .from('courses')
        .select('id, name, abbreviation, semester_taught')
        .eq('program_id', programId)
        .order('name');
    return rows.map(Course.fromMap).toList();
  }

  /// Schedules a one-time ([weeks] == 1) or weekly recurring lecture. Throws
  /// [LectureFailure] with the readable conflict message on a clash.
  Future<void> schedule({
    required String courseId,
    required String lecturerName,
    required String venueId,
    required DateTime start,
    required DateTime end,
    int weeks = 1,
    String? title,
  }) {
    return _invoke('schedule-lecture', {
      'course_id': courseId,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
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
    String? courseId,
    String? lecturerName,
    String? venueId,
    DateTime? start,
    DateTime? end,
  }) {
    return _invoke('edit-lecture', {
      'lecture_id': lectureId,
      'course_id': ?courseId,
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
