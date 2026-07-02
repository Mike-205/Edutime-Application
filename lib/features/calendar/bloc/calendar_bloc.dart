import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/lecture.dart';
import '../../../data/repositories/lecture_repository.dart';
import '../../../data/repositories/schedule_cache.dart';

/// Drives the student's live calendar (Journey 2). Loads cache-first for an
/// instant offline render, then refetches the enriched schedule and subscribes
/// to a realtime nudge: every change re-runs [LectureRepository.loadCohortSchedule]
/// (the "nudge -> refetch window" pattern the Broadcast migration will reuse).
/// Calendar UI state (selected/focused day, format) lives in the widget, not here.

sealed class CalendarEvent extends Equatable {
  const CalendarEvent();
  @override
  List<Object?> get props => [];
}

/// Start loading + subscribing. Fired once when the calendar opens.
class CalendarStarted extends CalendarEvent {
  const CalendarStarted();
}

/// Manual refresh (pull-to-refresh / retry after offline).
class CalendarRefreshed extends CalendarEvent {
  const CalendarRefreshed();
}

/// Internal: the realtime stream signalled a change (refetch the window).
class _CalendarChanged extends CalendarEvent {
  const _CalendarChanged();
}

enum CalendarStatus { loading, ready }

class CalendarState extends Equatable {
  const CalendarState({
    this.status = CalendarStatus.loading,
    this.lectures = const [],
    this.offline = false,
    this.fromCache = false,
  });

  final CalendarStatus status;
  final List<Lecture> lectures;

  /// The last network refetch failed — showing cached/last-known data.
  final bool offline;

  /// The current data came from the offline cache, not a live fetch.
  final bool fromCache;

  CalendarState copyWith({
    CalendarStatus? status,
    List<Lecture>? lectures,
    bool? offline,
    bool? fromCache,
  }) {
    return CalendarState(
      status: status ?? this.status,
      lectures: lectures ?? this.lectures,
      offline: offline ?? this.offline,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  @override
  List<Object?> get props => [status, lectures, offline, fromCache];
}

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  CalendarBloc({
    required LectureRepository repository,
    required ScheduleCache cache,
    required this.cohortId,
  }) : _repository = repository,
       _cache = cache,
       super(const CalendarState()) {
    on<CalendarStarted>(_onStarted);
    on<CalendarRefreshed>((_, emit) => _refetch(emit));
    on<_CalendarChanged>((_, emit) => _refetch(emit));
  }

  final LectureRepository _repository;
  final ScheduleCache _cache;
  final String cohortId;
  StreamSubscription<void>? _sub;

  Future<void> _onStarted(
    CalendarStarted event,
    Emitter<CalendarState> emit,
  ) async {
    // Cache-first: render the last-known schedule immediately (works offline).
    final cached = await _cache.load(cohortId);
    if (cached.isNotEmpty) {
      emit(
        state.copyWith(
          status: CalendarStatus.ready,
          lectures: cached,
          fromCache: true,
        ),
      );
    }

    await _refetch(emit);

    // Subscribe to the realtime nudge; each change triggers a windowed refetch.
    _sub ??= _repository.watchMyCohort().listen(
      (_) => add(const _CalendarChanged()),
      onError: (_) {}, // transport hiccups surface as a failed refetch instead
    );
  }

  Future<void> _refetch(Emitter<CalendarState> emit) async {
    try {
      final lectures = await _repository.loadCohortSchedule();
      await _cache.save(cohortId, lectures);
      emit(
        state.copyWith(
          status: CalendarStatus.ready,
          lectures: lectures,
          offline: false,
          fromCache: false,
        ),
      );
    } catch (_) {
      // Keep whatever we're showing (cache or last fetch); flag offline.
      emit(state.copyWith(status: CalendarStatus.ready, offline: true));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
