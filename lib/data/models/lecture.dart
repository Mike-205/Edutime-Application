import 'package:equatable/equatable.dart';

import 'venue.dart';

/// Mirrors the `event_status` enum in the database.
enum LectureStatus { scheduled, canceled, rescheduled }

LectureStatus lectureStatusFromDb(String value) => switch (value) {
  'scheduled' => LectureStatus.scheduled,
  'canceled' => LectureStatus.canceled,
  'rescheduled' => LectureStatus.rescheduled,
  _ => throw ArgumentError('Unknown status: $value'),
};

/// A scheduled academic event (the `events` table). The unit is FK'd via
/// [courseId]; [courseName] is the joined display name (null when read from a
/// realtime stream, which can't embed joins). Recurring series are stored as one
/// row per occurrence sharing [recurrenceGroupId]; [recurrenceRule] is display
/// metadata only, not the source of truth.
class Lecture extends Equatable {
  const Lecture({
    required this.id,
    required this.cohortId,
    required this.courseId,
    required this.lecturerName,
    required this.venueId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.title,
    this.courseName,
    this.venueName,
    this.recurrenceGroupId,
    this.recurrenceRule,
  });

  factory Lecture.fromMap(Map<String, dynamic> map) {
    // `course:courses(...)` / `venue:venues(...)` embed as an object, or a
    // single-element list depending on PostgREST; both absent on realtime streams.
    final course = _embed(map['course']);
    final venue = _embed(map['venue']);
    return Lecture(
      id: map['id'] as String,
      cohortId: map['cohort_id'] as String,
      courseId: map['course_id'] as String,
      title: map['title'] as String?,
      courseName: course?['name'] as String?,
      venueName: venue == null ? null : Venue.composeName(venue),
      lecturerName: map['lecturer_name'] as String,
      venueId: map['venue_id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      status: lectureStatusFromDb(map['status'] as String),
      recurrenceGroupId: map['recurrence_group_id'] as String?,
      recurrenceRule: map['recurrence_rule'] as String?,
    );
  }

  static Map<String, dynamic>? _embed(Object? raw) => switch (raw) {
    final List l => l.isEmpty ? null : l.first as Map<String, dynamic>,
    final Map m => m.cast<String, dynamic>(),
    _ => null,
  };

  final String id;
  final String cohortId;
  final String courseId;
  final String? title;
  final String? courseName;
  final String? venueName;
  final String lecturerName;
  final String venueId;
  final DateTime startTime;
  final DateTime endTime;
  final LectureStatus status;
  final String? recurrenceGroupId;
  final String? recurrenceRule;

  /// Heading to show for the lecture: a custom title if set, else the course
  /// name, else a neutral fallback (e.g. when read from a stream without a join).
  String get displayName => title ?? courseName ?? 'Lecture';

  /// A row shape compatible with [Lecture.fromMap], for the offline cache. Keeps
  /// a single parse path — the composed course/venue names round-trip as embeds.
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'cohort_id': cohortId,
    'course_id': courseId,
    'title': title,
    if (courseName != null) 'course': {'name': courseName},
    if (venueName != null) 'venue': {'type': 'online', 'label': venueName},
    'lecturer_name': lecturerName,
    'venue_id': venueId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'status': status.name,
    'recurrence_group_id': recurrenceGroupId,
    'recurrence_rule': recurrenceRule,
  };

  @override
  List<Object?> get props => [
    id,
    cohortId,
    courseId,
    title,
    courseName,
    venueName,
    lecturerName,
    venueId,
    startTime,
    endTime,
    status,
    recurrenceGroupId,
    recurrenceRule,
  ];
}
