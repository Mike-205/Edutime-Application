import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/models/app_user.dart';
import 'package:edutime/data/models/lecture.dart';
import 'package:edutime/data/models/notification.dart';
import 'package:edutime/data/repositories/lecture_repository.dart';
import 'package:edutime/data/repositories/notification_repository.dart';
import 'package:edutime/features/auth/bloc/auth_bloc.dart';
import 'package:edutime/features/calendar/view/calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class MockLectureRepository extends Mock implements LectureRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockLectureRepository repo;
  late MockNotificationRepository notifRepo;
  late MockAuthBloc authBloc;

  const student = AppUser(
    id: 'u1',
    fullName: 'Sam',
    role: UserRole.student,
    cohortId: 'c1',
  );

  setUpAll(() => registerFallbackValue(DateTime(2000)));

  setUp(() {
    SharedPreferences.setMockInitialValues({}); // empty cache
    repo = MockLectureRepository();
    notifRepo = MockNotificationRepository();
    when(
      () => notifRepo.watchMine(),
    ).thenAnswer((_) => Stream.value(const <NotificationItem>[]));
    authBloc = MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthState(
        status: AuthStatus.authenticated,
        user: student,
      ),
    );
    when(() => repo.watchMyCohort()).thenAnswer((_) => const Stream.empty());
  });

  Widget pumpable() => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<LectureRepository>.value(value: repo),
      RepositoryProvider<NotificationRepository>.value(value: notifRepo),
    ],
    child: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const MaterialApp(home: CalendarPage()),
    ),
  );

  testWidgets('renders the calendar and the selected day\'s agenda', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = Lecture(
      id: 'l1',
      cohortId: 'c1',
      courseId: 'course-1',
      courseName: 'Algorithms',
      venueName: 'CC-101',
      lecturerName: 'Dr A',
      venueId: 'v1',
      startTime: DateTime(now.year, now.month, now.day, 10),
      endTime: DateTime(now.year, now.month, now.day, 12),
      status: LectureStatus.scheduled,
    );
    when(
      () => repo.loadCohortSchedule(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => [today]);

    await tester.pumpWidget(pumpable());
    await tester.pumpAndSettle();

    expect(find.byType(TableCalendar<Lecture>), findsOneWidget);
    expect(find.text('Algorithms'), findsOneWidget); // agenda tile for today
    expect(find.textContaining('Dr A'), findsOneWidget);
    expect(
      find.text('Offline — showing the last saved schedule.'),
      findsNothing,
    );
  });

  testWidgets('shows the offline banner when the fetch fails with no cache', (
    tester,
  ) async {
    when(
      () => repo.loadCohortSchedule(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenThrow(Exception('no network'));

    await tester.pumpWidget(pumpable());
    await tester.pumpAndSettle();

    expect(
      find.text('Offline — showing the last saved schedule.'),
      findsOneWidget,
    );
  });
}
