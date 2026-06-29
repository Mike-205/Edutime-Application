import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/models/app_user.dart';
import 'package:edutime/data/repositories/auth_repository.dart';
import 'package:edutime/features/auth/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;

  const aliceStudent = AppUser(
    id: 'uid1',
    fullName: 'Alice',
    role: UserRole.student,
  );
  const aliceClassRep = AppUser(
    id: 'uid1',
    fullName: 'Alice',
    role: UserRole.classRep,
  );

  setUp(() {
    repo = MockAuthRepository();
    // Safe defaults; individual tests override what they exercise.
    when(() => repo.userIdChanges()).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchMyProfile(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(() => repo.loadMyProfile()).thenAnswer((_) async => null);
    when(
      () => repo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        fullName: any(named: 'fullName'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.signOut()).thenAnswer((_) async {});
  });

  group('AuthSignInRequested', () {
    blocTest<AuthBloc, AuthState>(
      'toggles isSubmitting on success (auth state arrives via the stream)',
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthSignInRequested('a@test.dev', 'pw')),
      expect: () => const [
        AuthState(isSubmitting: true),
        AuthState(isSubmitting: false),
      ],
      verify: (_) => verify(
        () => repo.signIn(email: 'a@test.dev', password: 'pw'),
      ).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'surfaces the failure message and clears submitting',
      setUp: () => when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthFailure('Invalid login credentials')),
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthSignInRequested('a@test.dev', 'pw')),
      expect: () => const [
        AuthState(isSubmitting: true),
        AuthState(
          isSubmitting: false,
          errorMessage: 'Invalid login credentials',
        ),
      ],
    );
  });

  group('AuthSignUpRequested', () {
    blocTest<AuthBloc, AuthState>(
      'toggles isSubmitting on success',
      build: () => AuthBloc(repo),
      act: (bloc) =>
          bloc.add(const AuthSignUpRequested('a@test.dev', 'password1', 'Al')),
      expect: () => const [
        AuthState(isSubmitting: true),
        AuthState(isSubmitting: false),
      ],
      verify: (_) => verify(
        () => repo.signUp(
          email: 'a@test.dev',
          password: 'password1',
          fullName: 'Al',
        ),
      ).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'surfaces the failure message',
      setUp: () => when(
        () => repo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fullName: any(named: 'fullName'),
        ),
      ).thenThrow(const AuthFailure('User already registered')),
      build: () => AuthBloc(repo),
      act: (bloc) =>
          bloc.add(const AuthSignUpRequested('a@test.dev', 'password1', 'Al')),
      expect: () => const [
        AuthState(isSubmitting: true),
        AuthState(isSubmitting: false, errorMessage: 'User already registered'),
      ],
    );
  });

  group('AuthSignOutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'delegates to the repository (state transition comes via the stream)',
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => const <AuthState>[],
      verify: (_) => verify(() => repo.signOut()).called(1),
    );
  });

  group('session subscription', () {
    blocTest<AuthBloc, AuthState>(
      'becomes authenticated with the loaded profile when a user id arrives',
      setUp: () {
        when(
          () => repo.userIdChanges(),
        ).thenAnswer((_) => Stream.value('uid1'));
        when(() => repo.loadMyProfile()).thenAnswer((_) async => aliceStudent);
      },
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthSubscriptionRequested()),
      expect: () => const [
        AuthState(status: AuthStatus.authenticated, user: aliceStudent),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'becomes unauthenticated when the user id is null',
      setUp: () => when(
        () => repo.userIdChanges(),
      ).thenAnswer((_) => Stream.value(null)),
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthSubscriptionRequested()),
      expect: () => const [AuthState(status: AuthStatus.unauthenticated)],
    );

    blocTest<AuthBloc, AuthState>(
      'is authenticated with a null profile when the profile read fails',
      setUp: () {
        when(
          () => repo.userIdChanges(),
        ).thenAnswer((_) => Stream.value('uid1'));
        when(() => repo.loadMyProfile()).thenThrow(Exception('network'));
      },
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthSubscriptionRequested()),
      expect: () => const [AuthState(status: AuthStatus.authenticated)],
    );

    blocTest<AuthBloc, AuthState>(
      'updates the user live when the profile row changes (promotion)',
      setUp: () {
        when(
          () => repo.userIdChanges(),
        ).thenAnswer((_) => Stream.value('uid1'));
        when(() => repo.loadMyProfile()).thenAnswer((_) async => aliceStudent);
        when(
          () => repo.watchMyProfile(any()),
        ).thenAnswer((_) => Stream.value(aliceClassRep));
      },
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthSubscriptionRequested()),
      wait: const Duration(milliseconds: 200),
      expect: () => const [
        AuthState(status: AuthStatus.authenticated, user: aliceStudent),
        AuthState(status: AuthStatus.authenticated, user: aliceClassRep),
      ],
    );
  });
}
