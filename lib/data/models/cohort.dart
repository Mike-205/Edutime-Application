import 'package:equatable/equatable.dart';

/// Mirrors the `cohorts` table. [programName]/[facultyName] are populated only
/// when the row is fetched with the program/faculty join (for display);
/// [joinCode] is present for a class rep viewing their own cohort.
class Cohort extends Equatable {
  const Cohort({
    required this.id,
    required this.programId,
    required this.intakeYear,
    required this.currentSemester,
    this.joinCode,
    this.programName,
    this.facultyName,
  });

  factory Cohort.fromMap(Map<String, dynamic> map) {
    // `programs` (and nested `faculties`) appear when selected via a join.
    final program = map['programs'] as Map<String, dynamic>?;
    final faculty = program?['faculties'] as Map<String, dynamic>?;
    return Cohort(
      id: map['id'] as String,
      programId: map['program_id'] as String,
      intakeYear: map['intake_year'] as int,
      currentSemester: map['current_semester'] as int,
      joinCode: map['join_code'] as String?,
      programName: program?['name'] as String?,
      facultyName: faculty?['name'] as String?,
    );
  }

  final String id;
  final String programId;
  final int intakeYear;
  final int currentSemester;
  final String? joinCode;
  final String? programName;
  final String? facultyName;

  Cohort copyWith({String? joinCode}) => Cohort(
    id: id,
    programId: programId,
    intakeYear: intakeYear,
    currentSemester: currentSemester,
    joinCode: joinCode ?? this.joinCode,
    programName: programName,
    facultyName: facultyName,
  );

  @override
  List<Object?> get props => [
    id,
    programId,
    intakeYear,
    currentSemester,
    joinCode,
    programName,
    facultyName,
  ];
}
