import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/lecture.dart';
import '../../../data/repositories/lecture_repository.dart';

/// Loads the cohort's upcoming lectures and handles cancellation. Reloads after
/// a cancel (lecture realtime is wired in the calendar milestone).

sealed class ManageLecturesEvent extends Equatable {
  const ManageLecturesEvent();
  @override
  List<Object?> get props => [];
}

class LecturesRequested extends ManageLecturesEvent {
  const LecturesRequested();
}

class LectureCanceled extends ManageLecturesEvent {
  const LectureCanceled(this.lectureId, {this.series = false});
  final String lectureId;
  final bool series;
  @override
  List<Object?> get props => [lectureId, series];
}

class ManageLecturesState extends Equatable {
  const ManageLecturesState({
    this.loading = true,
    this.lectures = const [],
    this.errorMessage,
    this.actionMessage,
  });

  final bool loading;
  final List<Lecture> lectures;
  final String? errorMessage;
  final String? actionMessage;

  ManageLecturesState copyWith({
    bool? loading,
    List<Lecture>? lectures,
    String? errorMessage,
    String? actionMessage,
    bool clearMessages = false,
  }) {
    return ManageLecturesState(
      loading: loading ?? this.loading,
      lectures: lectures ?? this.lectures,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      actionMessage: clearMessages
          ? null
          : (actionMessage ?? this.actionMessage),
    );
  }

  @override
  List<Object?> get props => [loading, lectures, errorMessage, actionMessage];
}

class ManageLecturesBloc
    extends Bloc<ManageLecturesEvent, ManageLecturesState> {
  ManageLecturesBloc(this._repository) : super(const ManageLecturesState()) {
    on<LecturesRequested>(_onRequested);
    on<LectureCanceled>(_onCanceled);
  }

  final LectureRepository _repository;

  Future<void> _onRequested(
    LecturesRequested event,
    Emitter<ManageLecturesState> emit,
  ) async {
    emit(state.copyWith(loading: true, clearMessages: true));
    try {
      final lectures = await _repository.upcomingForMyCohort();
      emit(state.copyWith(loading: false, lectures: lectures));
    } on Exception {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Could not load lectures. Pull to retry.',
        ),
      );
    }
  }

  Future<void> _onCanceled(
    LectureCanceled event,
    Emitter<ManageLecturesState> emit,
  ) async {
    emit(state.copyWith(clearMessages: true));
    try {
      await _repository.cancelLecture(event.lectureId, series: event.series);
      final lectures = await _repository.upcomingForMyCohort();
      emit(
        state.copyWith(
          lectures: lectures,
          actionMessage: event.series
              ? 'Series canceled.'
              : 'Lecture canceled.',
        ),
      );
    } on LectureFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }
}
