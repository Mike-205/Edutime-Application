import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../calendar/view/calendar_page.dart';
import '../bloc/auth_bloc.dart';
import 'login_page.dart';

/// Top-level router: shows the calendar when authenticated, the sign-in flow
/// when not, and a splash while the session is being restored. Switching is
/// driven entirely by [AuthBloc] session state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) => prev.status != curr.status,
      builder: (context, state) {
        return switch (state.status) {
          AuthStatus.authenticated => const CalendarPage(),
          AuthStatus.unauthenticated => const LoginPage(),
          AuthStatus.unknown => const _SplashScreen(),
        };
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
