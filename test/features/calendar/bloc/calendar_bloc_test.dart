import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/models/lecture.dart';
import 'package:edutime/data/repositories/lecture_repository.dart';
import 'package:edutime/data/repositories/schedule_cache.dart';
import 'package:edutime/features/calendar/bloc/calendar_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLectureRepository extends Mock implements LectureRepository {}

class MockScheduleCache extends Mock implements ScheduleCache {}

Lecture _lecture(String id) => Lecture(
  id: id,
  cohortId: 'c1',
  courseId: 'course-$id',
  courseName: 'Unit $id',
  lecturerName: 'Dr $id',
  venueId: 'v1',
  startTime: DateTime(2026, 2, 2, 10),
  endTime: DateTime(2026, 2, 2, 12),
  status: LectureStatus.scheduled,
);

void main() {
  late MockLectureRepository repo;
  late MockScheduleCache cache;
  final fresh = [_lecture('1'), _lecture('2')];

  setUp(() {
    repo = MockLectureRepository();
    cache = MockScheduleCache();
    when(() => repo.watchMyCohort()).thenAnswer((_) => const Stream.empty());
    when(() => cache.save(any(), any())).thenAnswer((_) async {});
  });

  CalendarBloc build() =>
      CalendarBloc(repository: repo, cache: cache, cohortId: 'c1');

  blocTest<CalendarBloc, CalendarState>(
    'renders cache first, then the fresh fetch, and saves the snapshot',
    setUp: () {
      when(() => cache.load('c1')).thenAnswer((_) async => [_lecture('1')]);
      when(() => repo.loadCohortSchedule()).thenAnswer((_) async => fresh);
    },
    build: build,
    act: (bloc) => bloc.add(const CalendarStarted()),
    expect: () => [
      CalendarState(
        status: CalendarStatus.ready,
        lectures: [_lecture('1')],
        fromCache: true,
      ),
      CalendarState(status: CalendarStatus.ready, lectures: fresh),
    ],
    verify: (_) => verify(() => cache.save('c1', fresh)).called(1),
  );

  blocTest<CalendarBloc, CalendarState>(
    'flags offline and keeps cached data when the fetch fails',
    setUp: () {
      when(() => cache.load('c1')).thenAnswer((_) async => [_lecture('1')]);
      when(() => repo.loadCohortSchedule()).thenThrow(Exception('no network'));
    },
    build: build,
    act: (bloc) => bloc.add(const CalendarStarted()),
    expect: () => [
      CalendarState(
        status: CalendarStatus.ready,
        lectures: [_lecture('1')],
        fromCache: true,
      ),
      CalendarState(
        status: CalendarStatus.ready,
        lectures: [_lecture('1')],
        fromCache: true,
        offline: true,
      ),
    ],
  );
}
