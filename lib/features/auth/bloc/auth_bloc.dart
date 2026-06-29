import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/app_user.dart';
import '../../../data/repositories/auth_repository.dart';

/// Owns authentication session state and the current user's profile.
///
/// Session restore + sign-in/out are driven by [AuthRepository.userIdChanges];
/// the form actions (sign in / sign up) only toggle [AuthState.isSubmitting]
/// and surface errors — the resulting authenticated state arrives via the
/// stream. A separate subscription on the user's own row flips [AuthState.user]
/// live when the role changes (promotion), with no re-login.

// --- Events ---
sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

/// Start listening to auth-session and profile changes. Dispatch once at start.
class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested(this.email, this.password);
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  const AuthSignUpRequested(this.email, this.password, this.fullName);
  final String email;
  final String password;
  final String fullName;
  @override
  List<Object?> get props => [email, password, fullName];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// Internal: the signed-in user's id changed (sign-in, restore, or sign-out).
class _AuthUserIdChanged extends AuthEvent {
  const _AuthUserIdChanged(this.userId);
  final String? userId;
  @override
  List<Object?> get props => [userId];
}

/// Internal: the current user's profile row changed (e.g. a live promotion).
class _AuthProfileChanged extends AuthEvent {
  const _AuthProfileChanged(this.user);
  final AppUser? user;
  @override
  List<Object?> get props => [user];
}

// --- State ---
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, user, isSubmitting, errorMessage];
}

// --- Bloc ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSignOutRequested>(_onSignOut);
    on<_AuthUserIdChanged>(_onUserIdChanged);
    on<_AuthProfileChanged>(_onProfileChanged);
  }

  final AuthRepository _authRepository;
  StreamSubscription<String?>? _userIdSub;
  StreamSubscription<AppUser?>? _profileSub;

  void _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) {
    _userIdSub ??= _authRepository.userIdChanges().listen(
      (userId) => add(_AuthUserIdChanged(userId)),
    );
  }

  Future<void> _onUserIdChanged(
    _AuthUserIdChanged event,
    Emitter<AuthState> emit,
  ) async {
    await _profileSub?.cancel();
    _profileSub = null;

    final userId = event.userId;
    if (userId == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    final profile = await _authRepository.loadMyProfile();
    emit(AuthState(status: AuthStatus.authenticated, user: profile));

    // Keep the profile live so a promotion flips controls without re-login.
    _profileSub = _authRepository
        .watchMyProfile(userId)
        .listen((user) => add(_AuthProfileChanged(user)));
  }

  void _onProfileChanged(_AuthProfileChanged event, Emitter<AuthState> emit) {
    if (state.status == AuthStatus.authenticated && event.user != null) {
      emit(state.copyWith(user: event.user));
    }
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      emit(state.copyWith(isSubmitting: false));
    } on AuthFailure catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _authRepository.signUp(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
      );
      emit(state.copyWith(isSubmitting: false));
    } on AuthFailure catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
  }

  @override
  Future<void> close() {
    _userIdSub?.cancel();
    _profileSub?.cancel();
    return super.close();
  }
}
