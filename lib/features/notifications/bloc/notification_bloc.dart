import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/notification.dart';
import '../../../data/repositories/notification_repository.dart';

/// Drives the in-app notification history + unread badge. Subscribes to the
/// user's live notifications; mark-read/all fire against the DB and the change
/// comes back through the same realtime stream, so the badge and list stay in
/// sync (including across separate bloc instances on the calendar and history).

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class NotificationsStarted extends NotificationEvent {
  const NotificationsStarted();
}

class NotificationRead extends NotificationEvent {
  const NotificationRead(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class NotificationsAllRead extends NotificationEvent {
  const NotificationsAllRead();
}

class _NotificationsUpdated extends NotificationEvent {
  const _NotificationsUpdated(this.items);
  final List<NotificationItem> items;
  @override
  List<Object?> get props => [items];
}

class NotificationState extends Equatable {
  const NotificationState({this.loading = true, this.items = const []});

  final bool loading;
  final List<NotificationItem> items;

  int get unread => items.where((n) => !n.isRead).length;

  NotificationState copyWith({bool? loading, List<NotificationItem>? items}) =>
      NotificationState(
        loading: loading ?? this.loading,
        items: items ?? this.items,
      );

  @override
  List<Object?> get props => [loading, items];
}

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc(this._repository) : super(const NotificationState()) {
    on<NotificationsStarted>(_onStarted);
    on<_NotificationsUpdated>(
      (e, emit) => emit(state.copyWith(loading: false, items: e.items)),
    );
    on<NotificationRead>((e, _) => _repository.markRead(e.id));
    on<NotificationsAllRead>((_, _) => _repository.markAllRead());
  }

  final NotificationRepository _repository;
  StreamSubscription<List<NotificationItem>>? _sub;

  void _onStarted(NotificationsStarted event, Emitter<NotificationState> emit) {
    _sub ??= _repository.watchMine().listen(
      (items) => add(_NotificationsUpdated(items)),
      onError: (_) {},
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
