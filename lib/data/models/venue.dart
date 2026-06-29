import 'package:equatable/equatable.dart';

/// Mirrors the `venue_type` enum.
enum VenueType { lectureHall, lab, tutorialRoom, online }

VenueType venueTypeFromDb(String value) => switch (value) {
  'lecture_hall' => VenueType.lectureHall,
  'lab' => VenueType.lab,
  'tutorial_room' => VenueType.tutorialRoom,
  'online' => VenueType.online,
  _ => throw ArgumentError('Unknown venue type: $value'),
};

/// A bookable room or online space.
class Venue extends Equatable {
  const Venue({
    required this.id,
    required this.name,
    required this.type,
    this.building,
  });

  factory Venue.fromMap(Map<String, dynamic> map) => Venue(
    id: map['id'] as String,
    name: map['name'] as String,
    type: venueTypeFromDb(map['type'] as String),
    building: map['building'] as String?,
  );

  final String id;
  final String name;
  final VenueType type;
  final String? building;

  @override
  List<Object?> get props => [id, name, type, building];
}
