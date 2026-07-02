import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/models/cohort.dart';
import 'package:edutime/data/repositories/cohort_repository.dart';
import 'package:edutime/features/cohort/bloc/join_cohort_bloc.dart';
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
  );

  setUp(() => repo = MockCohortRepository());

  blocTest<JoinCohortBloc, JoinCohortState>(
    'submitting -> success on a valid code',
    setUp: () =>
        when(() => repo.joinByCode(any())).thenAnswer((_) async => cohort),
    build: () => JoinCohortBloc(repo),
    act: (bloc) => bloc.add(const JoinCodeSubmitted('DEVCS1')),
    expect: () => const [
      JoinCohortState(status: JoinStatus.submitting),
      JoinCohortState(status: JoinStatus.success),
    ],
    verify: (_) => verify(() => repo.joinByCode('DEVCS1')).called(1),
  );

  blocTest<JoinCohortBloc, JoinCohortState>(
    'submitting -> failure with a friendly message on an invalid code',
    setUp: () => when(
      () => repo.joinByCode(any()),
    ).thenThrow(const CohortFailure("That join code didn't match any cohort.")),
    build: () => JoinCohortBloc(repo),
    act: (bloc) => bloc.add(const JoinCodeSubmitted('NOPE')),
    expect: () => const [
      JoinCohortState(status: JoinStatus.submitting),
      JoinCohortState(
        status: JoinStatus.failure,
        errorMessage: "That join code didn't match any cohort.",
      ),
    ],
  );
}
