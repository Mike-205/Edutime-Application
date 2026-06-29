import 'package:equatable/equatable.dart';

/// Mirrors the `lecture_status` enum in the database.
enum LectureStatus { scheduled, canceled, rescheduled }

LectureStatus lectureStatusFromDb(String value) => switch (value) {
  'scheduled' => LectureStatus.scheduled,
  'canceled' => LectureStatus.canceled,
  'rescheduled' => LectureStatus.rescheduled,
  _ => throw ArgumentError('Unknown status: $value'),
};

/// A scheduled academic event. Recurring series are stored as one row per
/// occurrence sharing [recurrenceGroupId]; [recurrenceRule] is display metadata
/// only, not the source of truth.
class Lecture extends Equatable {
  const Lecture({
    required this.id,
    required this.cohortId,
    required this.unitName,
    required this.lecturerName,
    required this.venueId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.recurrenceGroupId,
    this.recurrenceRule,
  });

  factory Lecture.fromMap(Map<String, dynamic> map) => Lecture(
    id: map['id'] as String,
    cohortId: map['cohort_id'] as String,
    unitName: map['unit_name'] as String,
    lecturerName: map['lecturer_name'] as String,
    venueId: map['venue_id'] as String,
    startTime: DateTime.parse(map['start_time'] as String),
    endTime: DateTime.parse(map['end_time'] as String),
    status: lectureStatusFromDb(map['status'] as String),
    recurrenceGroupId: map['recurrence_group_id'] as String?,
    recurrenceRule: map['recurrence_rule'] as String?,
  );

  final String id;
  final String cohortId;
  final String unitName;
  final String lecturerName;
  final String venueId;
  final DateTime startTime;
  final DateTime endTime;
  final LectureStatus status;
  final String? recurrenceGroupId;
  final String? recurrenceRule;

  @override
  List<Object?> get props => [
    id,
    cohortId,
    unitName,
    lecturerName,
    venueId,
    startTime,
    endTime,
    status,
    recurrenceGroupId,
    recurrenceRule,
  ];
}
