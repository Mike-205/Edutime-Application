import 'package:equatable/equatable.dart';

/// A unit within a program — the schedulable subject an event references.
/// Mirrors the `courses` table. A course must exist for the cohort's program
/// before a rep can schedule it (the seeding dependency accepted in Round 2).
class Course extends Equatable {
  const Course({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.semesterTaught,
  });

  factory Course.fromMap(Map<String, dynamic> map) => Course(
    id: map['id'] as String,
    name: map['name'] as String,
    abbreviation: map['abbreviation'] as String,
    semesterTaught: map['semester_taught'] as int,
  );

  final String id;
  final String name;
  final String abbreviation;
  final int semesterTaught;

  @override
  List<Object?> get props => [id, name, abbreviation, semesterTaught];
}
