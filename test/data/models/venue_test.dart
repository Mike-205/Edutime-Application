import 'package:edutime/data/models/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('venueTypeFromDb', () {
    test('maps each known type', () {
      expect(venueTypeFromDb('lecture_hall'), VenueType.lectureHall);
      expect(venueTypeFromDb('lab'), VenueType.lab);
      expect(venueTypeFromDb('tutorial_room'), VenueType.tutorialRoom);
      expect(venueTypeFromDb('online'), VenueType.online);
    });

    test('throws on an unknown type', () {
      expect(() => venueTypeFromDb('rooftop'), throwsArgumentError);
    });
  });

  test('Venue.fromMap parses a row', () {
    final venue = Venue.fromMap({
      'id': 'v1',
      'name': 'LH1',
      'type': 'lecture_hall',
      'building': 'Main Block',
    });
    expect(venue.id, 'v1');
    expect(venue.name, 'LH1');
    expect(venue.type, VenueType.lectureHall);
    expect(venue.building, 'Main Block');
  });
}
