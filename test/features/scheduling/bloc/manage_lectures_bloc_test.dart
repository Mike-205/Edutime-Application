import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/models/lecture.dart';
import 'package:edutime/data/repositories/lecture_repository.dart';
import 'package:edutime/features/scheduling/bloc/manage_lectures_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLectureRepository extends Mock implements LectureRepository {}

Lecture _lecture(String id) => Lecture(
  id: id,
  cohortId: 'c1',
  unitName: 'Unit $id',
  lecturerName: 'Dr $id',
  venueId: 'v1',
  startTime: DateTime(2026, 2, 2, 10),
  endTime: DateTime(2026, 2, 2, 12),
  status: LectureStatus.scheduled,
);

void main() {
  late MockLectureRepository repo;
  final l1 = _lecture('1');
  final l2 = _lecture('2');

  setUp(() => repo = MockLectureRepository());

  blocTest<ManageLecturesBloc, ManageLecturesState>(
    'loads upcoming lectures on request',
    setUp: () => when(
      () => repo.upcomingForMyCohort(),
    ).thenAnswer((_) async => [l1, l2]),
    build: () => ManageLecturesBloc(repo),
    act: (bloc) => bloc.add(const LecturesRequested()),
    expect: () => [
      const ManageLecturesState(loading: true),
      ManageLecturesState(loading: false, lectures: [l1, l2]),
    ],
  );

  blocTest<ManageLecturesBloc, ManageLecturesState>(
    'cancel removes the lecture (via reload) and reports success',
    setUp: () {
      when(
        () => repo.cancelLecture(any(), series: any(named: 'series')),
      ).thenAnswer((_) async {});
      when(() => repo.upcomingForMyCohort()).thenAnswer((_) async => [l2]);
    },
    build: () => ManageLecturesBloc(repo),
    seed: () => ManageLecturesState(loading: false, lectures: [l1, l2]),
    act: (bloc) => bloc.add(const LectureCanceled('1')),
    expect: () => [
      ManageLecturesState(
        loading: false,
        lectures: [l2],
        actionMessage: 'Lecture canceled.',
      ),
    ],
    verify: (_) =>
        verify(() => repo.cancelLecture('1', series: false)).called(1),
  );
}
