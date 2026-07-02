import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/models/notification.dart';
import 'package:edutime/data/repositories/notification_repository.dart';
import 'package:edutime/features/notifications/bloc/notification_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

NotificationItem _item(String id, {DateTime? readAt}) => NotificationItem(
  id: id,
  title: 'New lecture',
  message: 'DBMS · Mon',
  type: NotifType.created,
  createdAt: DateTime(2026, 2, 2, 10),
  readAt: readAt,
);

void main() {
  late MockNotificationRepository repo;

  setUp(() {
    repo = MockNotificationRepository();
    when(() => repo.markRead(any())).thenAnswer((_) async {});
    when(() => repo.markAllRead()).thenAnswer((_) async {});
  });

  blocTest<NotificationBloc, NotificationState>(
    'emits stream items and counts unread',
    setUp: () => when(() => repo.watchMine()).thenAnswer(
      (_) => Stream.value([
        _item('1'),
        _item('2', readAt: DateTime(2026, 2, 2, 11)),
      ]),
    ),
    build: () => NotificationBloc(repo),
    act: (bloc) => bloc.add(const NotificationsStarted()),
    expect: () => [
      isA<NotificationState>()
          .having((s) => s.loading, 'loading', false)
          .having((s) => s.items.length, 'items', 2)
          .having((s) => s.unread, 'unread', 1),
    ],
  );

  blocTest<NotificationBloc, NotificationState>(
    'mark-read delegates to the repository',
    setUp: () =>
        when(() => repo.watchMine()).thenAnswer((_) => const Stream.empty()),
    build: () => NotificationBloc(repo),
    act: (bloc) => bloc.add(const NotificationRead('1')),
    verify: (_) => verify(() => repo.markRead('1')).called(1),
  );

  blocTest<NotificationBloc, NotificationState>(
    'mark-all-read delegates to the repository',
    setUp: () =>
        when(() => repo.watchMine()).thenAnswer((_) => const Stream.empty()),
    build: () => NotificationBloc(repo),
    act: (bloc) => bloc.add(const NotificationsAllRead()),
    verify: (_) => verify(() => repo.markAllRead()).called(1),
  );
}
