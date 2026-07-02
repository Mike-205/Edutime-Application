import 'package:bloc_test/bloc_test.dart';
import 'package:edutime/data/repositories/account_repository.dart';
import 'package:edutime/features/settings/bloc/settings_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  late MockAccountRepository repo;

  setUp(() => repo = MockAccountRepository());

  blocTest<SettingsBloc, SettingsState>(
    'loads the pending-deletion status on start',
    setUp: () =>
        when(() => repo.hasPendingDeletion()).thenAnswer((_) async => true),
    build: () => SettingsBloc(repo),
    act: (bloc) => bloc.add(const SettingsStarted()),
    expect: () => const [
      SettingsState(loading: false, pendingDeletion: true),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'requesting deletion submits then marks pending',
    setUp: () =>
        when(() => repo.requestDeletion()).thenAnswer((_) async {}),
    build: () => SettingsBloc(repo),
    seed: () => const SettingsState(loading: false),
    act: (bloc) => bloc.add(const DeletionRequested()),
    expect: () => const [
      SettingsState(loading: false, submitting: true),
      SettingsState(loading: false, pendingDeletion: true),
    ],
    verify: (_) => verify(() => repo.requestDeletion()).called(1),
  );

  blocTest<SettingsBloc, SettingsState>(
    'surfaces a failure message when the request fails',
    setUp: () => when(() => repo.requestDeletion()).thenThrow(
      const AccountFailure('Could not submit your request. Please try again.'),
    ),
    build: () => SettingsBloc(repo),
    seed: () => const SettingsState(loading: false),
    act: (bloc) => bloc.add(const DeletionRequested()),
    expect: () => const [
      SettingsState(loading: false, submitting: true),
      SettingsState(
        loading: false,
        errorMessage: 'Could not submit your request. Please try again.',
      ),
    ],
  );
}
