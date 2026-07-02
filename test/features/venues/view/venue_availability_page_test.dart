import 'package:edutime/data/models/venue_availability.dart';
import 'package:edutime/data/repositories/lecture_repository.dart';
import 'package:edutime/features/venues/view/venue_availability_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLectureRepository extends Mock implements LectureRepository {}

void main() {
  late MockLectureRepository repo;

  setUpAll(() => registerFallbackValue(DateTime(2000)));

  setUp(() {
    repo = MockLectureRepository();
    when(() => repo.watchMyCohort()).thenAnswer((_) => const Stream.empty());
  });

  Widget pumpable() => RepositoryProvider<LectureRepository>.value(
    value: repo,
    child: const MaterialApp(home: VenueAvailabilityPage()),
  );

  testWidgets('shows free rooms first and busy rooms with their free time', (
    tester,
  ) async {
    when(() => repo.venueAvailability(any())).thenAnswer(
      (_) async => [
        VenueSlot(
          venueId: 'v2',
          displayName: 'CC-102',
          roomType: 'lab',
          occupied: true,
          busyUntil: DateTime(2026, 2, 2, 12),
        ),
        const VenueSlot(
          venueId: 'v1',
          displayName: 'CC-101',
          roomType: 'lecture_hall',
          occupied: false,
        ),
      ],
    );

    await tester.pumpWidget(pumpable());
    await tester.pumpAndSettle();

    expect(find.text('CC-101'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('CC-102'), findsOneWidget);
    expect(find.text('Busy until 12:00'), findsOneWidget);

    // Free room sorts above the busy one.
    final freeY = tester.getTopLeft(find.text('CC-101')).dy;
    final busyY = tester.getTopLeft(find.text('CC-102')).dy;
    expect(freeY, lessThan(busyY));
  });

  testWidgets('shows an empty state when no rooms are set up', (tester) async {
    when(() => repo.venueAvailability(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(pumpable());
    await tester.pumpAndSettle();

    expect(find.text('No rooms have been set up yet.'), findsOneWidget);
  });
}
