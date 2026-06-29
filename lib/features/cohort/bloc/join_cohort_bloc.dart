import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/cohort_repository.dart';

/// Drives the join-by-code form. On success it does not navigate: the join sets
/// the caller's cohort_id server-side, the users-row realtime stream updates
/// AuthBloc, and CohortGate switches to the cohort view reactively.

sealed class JoinCohortEvent extends Equatable {
  const JoinCohortEvent();
  @override
  List<Object?> get props => [];
}

class JoinCodeSubmitted extends JoinCohortEvent {
  const JoinCodeSubmitted(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

enum JoinStatus { idle, submitting, success, failure }

class JoinCohortState extends Equatable {
  const JoinCohortState({this.status = JoinStatus.idle, this.errorMessage});

  final JoinStatus status;
  final String? errorMessage;

  JoinCohortState copyWith({
    JoinStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return JoinCohortState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}

class JoinCohortBloc extends Bloc<JoinCohortEvent, JoinCohortState> {
  JoinCohortBloc(this._repository) : super(const JoinCohortState()) {
    on<JoinCodeSubmitted>(_onSubmitted);
  }

  final CohortRepository _repository;

  Future<void> _onSubmitted(
    JoinCodeSubmitted event,
    Emitter<JoinCohortState> emit,
  ) async {
    emit(state.copyWith(status: JoinStatus.submitting, clearError: true));
    try {
      await _repository.joinByCode(event.code);
      emit(state.copyWith(status: JoinStatus.success));
    } on CohortFailure catch (e) {
      emit(state.copyWith(status: JoinStatus.failure, errorMessage: e.message));
    }
  }
}
