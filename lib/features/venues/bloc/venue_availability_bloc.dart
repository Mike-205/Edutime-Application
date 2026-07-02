import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/venue_availability.dart';
import '../../../data/repositories/lecture_repository.dart';

/// Venue availability browser (Journey 3). Queries `venue_availability` for a
/// chosen instant and re-queries on a realtime nudge so the caller's own-cohort
/// bookings flip rooms live. Cross-cohort flips still need a manual/time refresh
/// (RLS gives no nudge for other cohorts) — the planned Broadcast path closes that.

sealed class VenueAvailabilityEvent extends Equatable {
  const VenueAvailabilityEvent();
  @override
  List<Object?> get props => [];
}

/// Query availability at [at] (also used when the user changes the time).
class AvailabilityRequested extends VenueAvailabilityEvent {
  const AvailabilityRequested(this.at);
  final DateTime at;
  @override
  List<Object?> get props => [at];
}

/// Internal: a cohort change nudged us — re-query the current instant.
class _AvailabilityNudged extends VenueAvailabilityEvent {
  const _AvailabilityNudged();
}

class VenueAvailabilityState extends Equatable {
  const VenueAvailabilityState({
    required this.at,
    this.loading = true,
    this.venues = const [],
    this.errorMessage,
  });

  final DateTime at;
  final bool loading;
  final List<VenueSlot> venues;
  final String? errorMessage;

  VenueAvailabilityState copyWith({
    DateTime? at,
    bool? loading,
    List<VenueSlot>? venues,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VenueAvailabilityState(
      at: at ?? this.at,
      loading: loading ?? this.loading,
      venues: venues ?? this.venues,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [at, loading, venues, errorMessage];
}

class VenueAvailabilityBloc
    extends Bloc<VenueAvailabilityEvent, VenueAvailabilityState> {
  VenueAvailabilityBloc({
    required LectureRepository repository,
    required DateTime initialAt,
  }) : _repository = repository,
       super(VenueAvailabilityState(at: initialAt)) {
    on<AvailabilityRequested>(_onRequested);
    on<_AvailabilityNudged>((_, emit) => _load(state.at, emit));
    // Debounce the nudge so a burst (e.g. a recurring series) is one re-query.
    _sub = _repository.watchMyCohort().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => add(const _AvailabilityNudged()),
      );
    }, onError: (_) {});
  }

  final LectureRepository _repository;
  StreamSubscription<void>? _sub;
  Timer? _debounce;

  Future<void> _onRequested(
    AvailabilityRequested event,
    Emitter<VenueAvailabilityState> emit,
  ) => _load(event.at, emit);

  Future<void> _load(
    DateTime at,
    Emitter<VenueAvailabilityState> emit,
  ) async {
    emit(state.copyWith(at: at, loading: true, clearError: true));
    try {
      final venues = await _repository.venueAvailability(at);
      emit(state.copyWith(loading: false, venues: venues));
    } catch (_) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Could not load availability. Pull to retry.',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _sub?.cancel();
    return super.close();
  }
}
