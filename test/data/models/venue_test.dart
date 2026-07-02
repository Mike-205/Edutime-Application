import 'package:edutime/data/models/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('venueTypeFromDb', () {
    test('maps each known type', () {
      expect(venueTypeFromDb('physical'), VenueType.physical);
      expect(venueTypeFromDb('online'), VenueType.online);
    });

    test('throws on an unknown type', () {
      expect(() => venueTypeFromDb('rooftop'), throwsArgumentError);
    });
  });

  group('Venue.fromMap', () {
    test('composes a physical venue name from building + room', () {
      final venue = Venue.fromMap({
        'id': 'v1',
        'type': 'physical',
        'label': null,
        'room': {
          'number': '101',
          'building': {'abbreviation': 'CC', 'name': 'Conflict Complex'},
        },
      });
      expect(venue.id, 'v1');
      expect(venue.type, VenueType.physical);
      expect(venue.displayName, 'CC-101');
    });

    test('uses the label for an online venue', () {
      final venue = Venue.fromMap({
        'id': 'v2',
        'type': 'online',
        'label': 'Google Meet — CS',
      });
      expect(venue.type, VenueType.online);
      expect(venue.displayName, 'Google Meet — CS');
    });

    test('falls back to "Online" when an online venue has no label', () {
      final venue = Venue.fromMap({'id': 'v3', 'type': 'online', 'label': null});
      expect(venue.displayName, 'Online');
    });
  });
}
