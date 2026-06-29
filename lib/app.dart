import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/env.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/cohort_repository.dart';
import 'data/repositories/lecture_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/view/auth_gate.dart';

/// Root widget. Provides the auth repository + BLoC and gates the UI on session
/// state via [AuthGate]. When Supabase config is missing (a dev misconfig),
/// degrades to a setup-instructions screen instead of crashing.
class EdutimeApp extends StatelessWidget {
  const EdutimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Env.isConfigured) {
      return const _SetupRequiredApp();
    }

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => AuthRepository(SupabaseClientProvider.client),
        ),
        RepositoryProvider(
          create: (_) => CohortRepository(SupabaseClientProvider.client),
        ),
        RepositoryProvider(
          create: (_) => LectureRepository(SupabaseClientProvider.client),
        ),
      ],
      child: BlocProvider(
        create: (context) =>
            AuthBloc(context.read<AuthRepository>())
              ..add(const AuthSubscriptionRequested()),
        child: MaterialApp(
          title: 'Edutime',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class _SetupRequiredApp extends StatelessWidget {
  const _SetupRequiredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edutime',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Supabase is not configured.\n\n'
              'Run with --dart-define=SUPABASE_URL=... and '
              '--dart-define=SUPABASE_ANON_KEY=... (see README).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
