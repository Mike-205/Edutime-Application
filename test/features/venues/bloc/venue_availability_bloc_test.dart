import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/models/venue_availability.dart';
import 'package:edutime/data/repositories/lecture_repository.dart';
import 'package:edutime/features/venues/bloc/venue_availability_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLectureRepository extends Mock implements LectureRepository {}

void main() {
  late MockLectureRepository repo;
  final at = DateTime(2026, 2, 2, 10);
  final slots = [
    const VenueSlot(
      venueId: 'v1',
      displayName: 'CC-101',
      roomType: 'lecture_hall',
      occupied: false,
    ),
    VenueSlot(
      venueId: 'v2',
      displayName: 'CC-102',
      roomType: 'lab',
      occupied: true,
      busyUntil: DateTime(2026, 2, 2, 12),
    ),
  ];

  setUp(() {
    repo = MockLectureRepository();
    when(() => repo.watchMyCohort()).thenAnswer((_) => const Stream.empty());
  });

  VenueAvailabilityBloc build() =>
      VenueAvailabilityBloc(repository: repo, initialAt: at);

  blocTest<VenueAvailabilityBloc, VenueAvailabilityState>(
    'loads availability for the requested time',
    setUp: () =>
        when(() => repo.venueAvailability(at)).thenAnswer((_) async => slots),
    build: build,
    act: (bloc) => bloc.add(AvailabilityRequested(at)),
    expect: () => [
      VenueAvailabilityState(at: at, loading: true),
      VenueAvailabilityState(at: at, loading: false, venues: slots),
    ],
  );

  blocTest<VenueAvailabilityBloc, VenueAvailabilityState>(
    'surfaces a retryable error when the query fails',
    setUp: () =>
        when(() => repo.venueAvailability(at)).thenThrow(Exception('boom')),
    build: build,
    act: (bloc) => bloc.add(AvailabilityRequested(at)),
    expect: () => [
      VenueAvailabilityState(at: at, loading: true),
      VenueAvailabilityState(
        at: at,
        loading: false,
        errorMessage: 'Could not load availability. Pull to retry.',
      ),
    ],
  );
}
