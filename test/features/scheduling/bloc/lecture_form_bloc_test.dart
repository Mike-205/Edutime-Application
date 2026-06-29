import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/repositories/lecture_repository.dart';
import 'package:edutime/features/scheduling/bloc/lecture_form_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLectureRepository extends Mock implements LectureRepository {}

void main() {
  late MockLectureRepository repo;

  final start = DateTime(2026, 2, 2, 10, 0);
  final end = DateTime(2026, 2, 2, 12, 0);

  setUpAll(() => registerFallbackValue(DateTime(2000)));
  setUp(() => repo = MockLectureRepository());

  LectureCreateSubmitted createEvent() => LectureCreateSubmitted(
    unitName: 'Algorithms',
    lecturerName: 'Dr A',
    venueId: 'v1',
    start: start,
    end: end,
    weeks: 1,
  );

  blocTest<LectureFormBloc, LectureFormState>(
    'create: submitting -> success',
    setUp: () => when(
      () => repo.schedule(
        unitName: any(named: 'unitName'),
        lecturerName: any(named: 'lecturerName'),
        venueId: any(named: 'venueId'),
        start: any(named: 'start'),
        end: any(named: 'end'),
        weeks: any(named: 'weeks'),
      ),
    ).thenAnswer((_) async {}),
    build: () => LectureFormBloc(repo),
    act: (bloc) => bloc.add(createEvent()),
    expect: () => const [
      LectureFormState(status: LectureFormStatus.submitting),
      LectureFormState(status: LectureFormStatus.success),
    ],
  );

  blocTest<LectureFormBloc, LectureFormState>(
    'create: surfaces the readable conflict message on failure',
    setUp: () => when(
      () => repo.schedule(
        unitName: any(named: 'unitName'),
        lecturerName: any(named: 'lecturerName'),
        venueId: any(named: 'venueId'),
        start: any(named: 'start'),
        end: any(named: 'end'),
        weeks: any(named: 'weeks'),
      ),
    ).thenThrow(const LectureFailure('That venue is taken by Stats II.')),
    build: () => LectureFormBloc(repo),
    act: (bloc) => bloc.add(createEvent()),
    expect: () => const [
      LectureFormState(status: LectureFormStatus.submitting),
      LectureFormState(
        status: LectureFormStatus.failure,
        errorMessage: 'That venue is taken by Stats II.',
      ),
    ],
  );

  blocTest<LectureFormBloc, LectureFormState>(
    'edit: submitting -> success',
    setUp: () => when(
      () => repo.editLecture(
        lectureId: any(named: 'lectureId'),
        unitName: any(named: 'unitName'),
        lecturerName: any(named: 'lecturerName'),
        venueId: any(named: 'venueId'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async {}),
    build: () => LectureFormBloc(repo),
    act: (bloc) => bloc.add(
      LectureEditSubmitted(
        lectureId: 'l1',
        unitName: 'Algorithms',
        lecturerName: 'Dr A',
        venueId: 'v1',
        start: start,
        end: end,
      ),
    ),
    expect: () => const [
      LectureFormState(status: LectureFormStatus.submitting),
      LectureFormState(status: LectureFormStatus.success),
    ],
    verify: (_) => verify(
      () => repo.editLecture(
        lectureId: 'l1',
        unitName: 'Algorithms',
        lecturerName: 'Dr A',
        venueId: 'v1',
        start: start,
        end: end,
      ),
    ).called(1),
  );
}
