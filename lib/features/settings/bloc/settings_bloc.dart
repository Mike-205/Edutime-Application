import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/account_repository.dart';

/// Backs the settings screen: loads whether a deletion request is already
/// pending, and submits a new one (the surfaced DPA path).

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

class DeletionRequested extends SettingsEvent {
  const DeletionRequested();
}

class SettingsState extends Equatable {
  const SettingsState({
    this.loading = true,
    this.pendingDeletion = false,
    this.submitting = false,
    this.errorMessage,
  });

  final bool loading;
  final bool pendingDeletion;
  final bool submitting;
  final String? errorMessage;

  SettingsState copyWith({
    bool? loading,
    bool? pendingDeletion,
    bool? submitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      loading: loading ?? this.loading,
      pendingDeletion: pendingDeletion ?? this.pendingDeletion,
      submitting: submitting ?? this.submitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    loading,
    pendingDeletion,
    submitting,
    errorMessage,
  ];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._repository) : super(const SettingsState()) {
    on<SettingsStarted>(_onStarted);
    on<DeletionRequested>(_onDeletionRequested);
  }

  final AccountRepository _repository;

  Future<void> _onStarted(
    SettingsStarted event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      final pending = await _repository.hasPendingDeletion();
      emit(state.copyWith(loading: false, pendingDeletion: pending));
    } catch (_) {
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> _onDeletionRequested(
    DeletionRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await _repository.requestDeletion();
      emit(state.copyWith(submitting: false, pendingDeletion: true));
    } on AccountFailure catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: e.message));
    }
  }
}
