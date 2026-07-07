import 'package:equatable/equatable.dart';

/// A physical venue's occupancy at a queried instant, from the
/// `venue_availability(at_time)` DB function. Carries only room busy-ness — no
/// cohort/course/lecturer data (the cross-cohort DPA guarantee).
class VenueSlot extends Equatable {
  const VenueSlot({
    required this.venueId,
    required this.displayName,
    required this.roomType,
    required this.occupied,
    this.busyUntil,
  });

  factory VenueSlot.fromMap(Map<String, dynamic> map) => VenueSlot(
    venueId: map['venue_id'] as String,
    displayName: map['display_name'] as String,
    roomType: map['room_type'] as String,
    occupied: map['occupied'] as bool,
    busyUntil: map['busy_until'] == null
        ? null
        : DateTime.parse(map['busy_until'] as String),
  );

  final String venueId;
  final String displayName;
  final String roomType;
  final bool occupied;
  final DateTime? busyUntil;

  @override
  List<Object?> get props => [
    venueId,
    displayName,
    roomType,
    occupied,
    busyUntil,
  ];
}
