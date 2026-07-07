import 'package:edutime/data/models/cohort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cohort.fromMap', () {
    test('parses a flat row with no joined program/faculty', () {
      final cohort = Cohort.fromMap({
        'id': 'c1',
        'program_id': 'p1',
        'intake_year': 2025,
        'current_semester': 1,
        'join_code': 'DEVCS1',
      });

      expect(cohort.id, 'c1');
      expect(cohort.programId, 'p1');
      expect(cohort.intakeYear, 2025);
      expect(cohort.currentSemester, 1);
      expect(cohort.joinCode, 'DEVCS1');
      expect(cohort.programName, isNull);
      expect(cohort.facultyName, isNull);
    });

    test('parses nested program + faculty names from a joined select', () {
      final cohort = Cohort.fromMap({
        'id': 'c1',
        'program_id': 'p1',
        'intake_year': 2025,
        'current_semester': 2,
        'join_code': null,
        'programs': {
          'name': 'BSc Computer Science',
          'faculties': {'name': 'Faculty of Science'},
        },
      });

      expect(cohort.programName, 'BSc Computer Science');
      expect(cohort.facultyName, 'Faculty of Science');
      expect(cohort.joinCode, isNull);
    });
  });

  group('Cohort.copyWith', () {
    test('replaces only the join code', () {
      const cohort = Cohort(
        id: 'c1',
        programId: 'p1',
        intakeYear: 2025,
        currentSemester: 1,
        joinCode: 'OLD123',
        programName: 'BSc CS',
        facultyName: 'Science',
      );

      final updated = cohort.copyWith(joinCode: 'NEW456');

      expect(updated.joinCode, 'NEW456');
      expect(updated.id, 'c1');
      expect(updated.programName, 'BSc CS');
      expect(updated.facultyName, 'Science');
    });
  });
}
