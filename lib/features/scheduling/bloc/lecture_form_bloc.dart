import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/lecture_repository.dart';

/// Submits the lecture form — create (one-time or weekly recurring) or edit a
/// single occurrence. Surfaces the readable conflict message from the Edge
/// Function as [LectureFormState.errorMessage].

sealed class LectureFormEvent extends Equatable {
  const LectureFormEvent();
  @override
  List<Object?> get props => [];
}

class LectureCreateSubmitted extends LectureFormEvent {
  const LectureCreateSubmitted({
    required this.unitName,
    required this.lecturerName,
    required this.venueId,
    required this.start,
    required this.end,
    required this.weeks,
  });

  final String unitName;
  final String lecturerName;
  final String venueId;
  final DateTime start;
  final DateTime end;
  final int weeks;

  @override
  List<Object?> get props => [
    unitName,
    lecturerName,
    venueId,
    start,
    end,
    weeks,
  ];
}

class LectureEditSubmitted extends LectureFormEvent {
  const LectureEditSubmitted({
    required this.lectureId,
    required this.unitName,
    required this.lecturerName,
    required this.venueId,
    required this.start,
    required this.end,
  });

  final String lectureId;
  final String unitName;
  final String lecturerName;
  final String venueId;
  final DateTime start;
  final DateTime end;

  @override
  List<Object?> get props => [
    lectureId,
    unitName,
    lecturerName,
    venueId,
    start,
    end,
  ];
}

enum LectureFormStatus { idle, submitting, success, failure }

class LectureFormState extends Equatable {
  const LectureFormState({
    this.status = LectureFormStatus.idle,
    this.errorMessage,
  });

  final LectureFormStatus status;
  final String? errorMessage;

  LectureFormState copyWith({
    LectureFormStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LectureFormState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}

class LectureFormBloc extends Bloc<LectureFormEvent, LectureFormState> {
  LectureFormBloc(this._repository) : super(const LectureFormState()) {
    on<LectureCreateSubmitted>(_onCreate);
    on<LectureEditSubmitted>(_onEdit);
  }

  final LectureRepository _repository;

  Future<void> _onCreate(
    LectureCreateSubmitted event,
    Emitter<LectureFormState> emit,
  ) async {
    emit(
      state.copyWith(status: LectureFormStatus.submitting, clearError: true),
    );
    try {
      await _repository.schedule(
        unitName: event.unitName,
        lecturerName: event.lecturerName,
        venueId: event.venueId,
        start: event.start,
        end: event.end,
        weeks: event.weeks,
      );
      emit(state.copyWith(status: LectureFormStatus.success));
    } on LectureFailure catch (e) {
      _fail(emit, e.message);
    }
  }

  Future<void> _onEdit(
    LectureEditSubmitted event,
    Emitter<LectureFormState> emit,
  ) async {
    emit(
      state.copyWith(status: LectureFormStatus.submitting, clearError: true),
    );
    try {
      await _repository.editLecture(
        lectureId: event.lectureId,
        unitName: event.unitName,
        lecturerName: event.lecturerName,
        venueId: event.venueId,
        start: event.start,
        end: event.end,
      );
      emit(state.copyWith(status: LectureFormStatus.success));
    } on LectureFailure catch (e) {
      _fail(emit, e.message);
    }
  }

  void _fail(Emitter<LectureFormState> emit, String message) {
    emit(
      state.copyWith(status: LectureFormStatus.failure, errorMessage: message),
    );
  }
}
