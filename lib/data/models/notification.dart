import 'package:equatable/equatable.dart';

/// Mirrors the `notif_type` enum: what kind of lecture change this announces.
enum NotifType { created, updated, canceled }

NotifType notifTypeFromDb(String value) => switch (value) {
  'created' => NotifType.created,
  'updated' => NotifType.updated,
  'canceled' => NotifType.canceled,
  _ => throw ArgumentError('Unknown notification type: $value'),
};

/// An in-app notification row (history + unread state). Written by the dispatch
/// path (service role); read/marked-read by the owning user under RLS.
class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.eventId,
    this.readAt,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) => NotificationItem(
    id: map['id'] as String,
    title: map['title'] as String,
    message: map['message'] as String,
    type: notifTypeFromDb(map['type'] as String),
    eventId: map['event_id'] as String?,
    readAt: map['read_at'] == null
        ? null
        : DateTime.parse(map['read_at'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  final String id;
  final String title;
  final String message;
  final NotifType type;
  final String? eventId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  @override
  List<Object?> get props => [
    id,
    title,
    message,
    type,
    eventId,
    readAt,
    createdAt,
  ];
}
