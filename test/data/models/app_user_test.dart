import 'package:edutime/data/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('userRoleFromDb', () {
    test('maps student', () {
      expect(userRoleFromDb('student'), UserRole.student);
    });

    test('maps class_rep', () {
      expect(userRoleFromDb('class_rep'), UserRole.classRep);
    });

    test('maps faculty_rep', () {
      expect(userRoleFromDb('faculty_rep'), UserRole.facultyRep);
    });

    test('throws on an unknown role', () {
      expect(() => userRoleFromDb('superadmin'), throwsArgumentError);
    });
  });

  group('AppUser.fromMap', () {
    test('parses a full own-profile row including email and cohort', () {
      final user = AppUser.fromMap({
        'id': 'u1',
        'full_name': 'Alice',
        'role': 'class_rep',
        'email': 'alice@test.dev',
        'cohort_id': 'c1',
      });

      expect(user.id, 'u1');
      expect(user.fullName, 'Alice');
      expect(user.role, UserRole.classRep);
      expect(user.email, 'alice@test.dev');
      expect(user.cohortId, 'c1');
    });

    test('parses a cohort-member row with no email (the DPA shape)', () {
      final user = AppUser.fromMap({
        'id': 'u2',
        'full_name': 'Bob',
        'role': 'student',
        'email': null,
        'cohort_id': null,
      });

      expect(user.email, isNull);
      expect(user.cohortId, isNull);
      expect(user.role, UserRole.student);
    });

    test('equality is value-based via Equatable', () {
      AppUser build() =>
          const AppUser(id: 'u1', fullName: 'Alice', role: UserRole.student);
      expect(build(), build());
    });
  });
}
