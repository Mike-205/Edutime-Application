import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Template BLoC showing the project's state-management pattern. The real
/// authentication wiring (Supabase Auth sign-in/up, session restore, role load
/// via the users table) lands in the auth milestone.

// --- Events ---
sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested(this.email, this.password);
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

// --- State ---
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.unknown, this.userId});

  final AuthStatus status;
  final String? userId;

  AuthState copyWith({AuthStatus? status, String? userId}) =>
      AuthState(status: status ?? this.status, userId: userId ?? this.userId);

  @override
  List<Object?> get props => [status, userId];
}

// --- Bloc ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthState()) {
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignOutRequested>(_onSignOut);
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    // TODO(auth milestone): call Supabase Auth, then load role from users table.
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
