import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/models/app_user.dart';
import 'package:edutime/data/models/cohort.dart';
import 'package:edutime/data/repositories/cohort_repository.dart';
import 'package:edutime/features/cohort/bloc/cohort_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCohortRepository extends Mock implements CohortRepository {}

void main() {
  late MockCohortRepository repo;

  const cohort = Cohort(
    id: 'c1',
    programId: 'p1',
    intakeYear: 2025,
    currentSemester: 1,
    joinCode: 'OLD123',
    programName: 'BSc CS',
    facultyName: 'Science',
  );
  const studentA = AppUser(id: 's1', fullName: 'Stu A', role: UserRole.student);
  const studentB = AppUser(id: 's2', fullName: 'Stu B', role: UserRole.student);

  setUp(() => repo = MockCohortRepository());

  blocTest<CohortBloc, CohortState>(
    'loads the cohort and members on request',
    setUp: () {
      when(() => repo.loadCohort(any())).thenAnswer((_) async => cohort);
      when(
        () => repo.cohortMembers(),
      ).thenAnswer((_) async => [studentA, studentB]);
    },
    build: () => CohortBloc(repo),
    act: (bloc) => bloc.add(const CohortRequested('c1')),
    expect: () => const [
      CohortState(loading: true),
      CohortState(
        loading: false,
        cohort: cohort,
        members: [studentA, studentB],
      ),
    ],
  );

  blocTest<CohortBloc, CohortState>(
    'surfaces a load error',
    setUp: () {
      when(() => repo.loadCohort(any())).thenThrow(Exception('boom'));
    },
    build: () => CohortBloc(repo),
    act: (bloc) => bloc.add(const CohortRequested('c1')),
    expect: () => const [
      CohortState(loading: true),
      CohortState(
        loading: false,
        errorMessage: 'Could not load your cohort. Pull to retry.',
      ),
    ],
  );

  blocTest<CohortBloc, CohortState>(
    'regenerating the join code updates it and reports success',
    setUp: () =>
        when(() => repo.regenerateJoinCode()).thenAnswer((_) async => 'NEW456'),
    build: () => CohortBloc(repo),
    seed: () => const CohortState(loading: false, cohort: cohort),
    act: (bloc) => bloc.add(const CohortJoinCodeRegenerated()),
    expect: () => [
      CohortState(
        loading: false,
        cohort: cohort.copyWith(joinCode: 'NEW456'),
        actionMessage: 'Join code updated.',
      ),
    ],
  );

  blocTest<CohortBloc, CohortState>(
    'removing a student drops them from the list and reports success',
    setUp: () => when(() => repo.removeStudent(any())).thenAnswer((_) async {}),
    build: () => CohortBloc(repo),
    seed: () => const CohortState(
      loading: false,
      cohort: cohort,
      members: [studentA, studentB],
    ),
    act: (bloc) => bloc.add(const CohortStudentRemoved('s1')),
    expect: () => const [
      CohortState(
        loading: false,
        cohort: cohort,
        members: [studentB],
        actionMessage: 'Student removed.',
      ),
    ],
    verify: (_) => verify(() => repo.removeStudent('s1')).called(1),
  );
}
