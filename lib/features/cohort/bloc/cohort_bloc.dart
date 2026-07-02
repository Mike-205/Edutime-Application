import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/cohort.dart';
import '../../../data/repositories/cohort_repository.dart';

/// Loads the caller's cohort (with program/faculty names) and, for a class rep,
/// the member directory (name + role only). Also handles the rep actions:
/// regenerating the join code and removing a student.

sealed class CohortEvent extends Equatable {
  const CohortEvent();
  @override
  List<Object?> get props => [];
}

class CohortRequested extends CohortEvent {
  const CohortRequested(this.cohortId);
  final String cohortId;
  @override
  List<Object?> get props => [cohortId];
}

class CohortJoinCodeRegenerated extends CohortEvent {
  const CohortJoinCodeRegenerated();
}

class CohortStudentRemoved extends CohortEvent {
  const CohortStudentRemoved(this.userId);
  final String userId;
  @override
  List<Object?> get props => [userId];
}

class CohortState extends Equatable {
  const CohortState({
    this.loading = true,
    this.cohort,
    this.members = const [],
    this.errorMessage,
    this.actionMessage,
  });

  final bool loading;
  final Cohort? cohort;
  final List<AppUser> members;
  final String? errorMessage;

  /// Transient feedback for a completed action (e.g. "Join code updated").
  final String? actionMessage;

  CohortState copyWith({
    bool? loading,
    Cohort? cohort,
    List<AppUser>? members,
    String? errorMessage,
    String? actionMessage,
    bool clearMessages = false,
  }) {
    return CohortState(
      loading: loading ?? this.loading,
      cohort: cohort ?? this.cohort,
      members: members ?? this.members,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      actionMessage: clearMessages
          ? null
          : (actionMessage ?? this.actionMessage),
    );
  }

  @override
  List<Object?> get props => [
    loading,
    cohort,
    members,
    errorMessage,
    actionMessage,
  ];
}

class CohortBloc extends Bloc<CohortEvent, CohortState> {
  CohortBloc(this._repository) : super(const CohortState()) {
    on<CohortRequested>(_onRequested);
    on<CohortJoinCodeRegenerated>(_onRegenerated);
    on<CohortStudentRemoved>(_onRemoved);
  }

  final CohortRepository _repository;

  Future<void> _onRequested(
    CohortRequested event,
    Emitter<CohortState> emit,
  ) async {
    emit(state.copyWith(loading: true, clearMessages: true));
    try {
      final cohort = await _repository.loadCohort(event.cohortId);
      // Returns [] for non-class-reps (RLS), so this is safe for any role.
      final members = await _repository.cohortMembers();
      emit(state.copyWith(loading: false, cohort: cohort, members: members));
    } on Exception {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Could not load your cohort. Pull to retry.',
        ),
      );
    }
  }

  Future<void> _onRegenerated(
    CohortJoinCodeRegenerated event,
    Emitter<CohortState> emit,
  ) async {
    emit(state.copyWith(clearMessages: true));
    try {
      final code = await _repository.regenerateJoinCode();
      emit(
        state.copyWith(
          cohort: state.cohort?.copyWith(joinCode: code),
          actionMessage: 'Join code updated.',
        ),
      );
    } on CohortFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> _onRemoved(
    CohortStudentRemoved event,
    Emitter<CohortState> emit,
  ) async {
    emit(state.copyWith(clearMessages: true));
    try {
      await _repository.removeStudent(event.userId);
      emit(
        state.copyWith(
          members: state.members.where((m) => m.id != event.userId).toList(),
          actionMessage: 'Student removed.',
        ),
      );
    } on CohortFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }
}
