import 'package:equatable/equatable.dart';

/// Mirrors the `venue_type` enum: a physical room or an online meeting space.
enum VenueType { physical, online }

VenueType venueTypeFromDb(String value) => switch (value) {
  'physical' => VenueType.physical,
  'online' => VenueType.online,
  _ => throw ArgumentError('Unknown venue type: $value'),
};

/// A bookable location. Physical venues are shared reference data (one row per
/// room); their display name is composed as `<building abbrev>-<room number>`
/// (e.g. "CC-101") because the DB never stores it — a stored name would drift
/// from the building it belongs to. Online venues use their [label].
class Venue extends Equatable {
  const Venue({
    required this.id,
    required this.type,
    required this.displayName,
  });

  factory Venue.fromMap(Map<String, dynamic> map) {
    final type = venueTypeFromDb(map['type'] as String);
    return Venue(
      id: map['id'] as String,
      type: type,
      displayName: _composeName(map, type),
    );
  }

  static String _composeName(Map<String, dynamic> map, VenueType type) {
    final label = (map['label'] as String?)?.trim();
    if (type == VenueType.online) {
      return (label != null && label.isNotEmpty) ? label : 'Online';
    }
    final room = _embed(map['room']);
    final building = _embed(room?['building']);
    final abbr = building?['abbreviation'] as String?;
    final number = room?['number'] as String?;
    if (abbr != null && number != null) return '$abbr-$number';
    return (label != null && label.isNotEmpty) ? label : 'Venue';
  }

  /// PostgREST embeds a to-one join as an object, or a single-element list.
  static Map<String, dynamic>? _embed(Object? raw) => switch (raw) {
    final List l => l.isEmpty ? null : l.first as Map<String, dynamic>,
    final Map m => m.cast<String, dynamic>(),
    _ => null,
  };

  final String id;
  final VenueType type;
  final String displayName;

  @override
  List<Object?> get props => [id, type, displayName];
}
