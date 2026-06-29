import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../calendar/view/calendar_page.dart';
import 'join_cohort_page.dart';

/// For an authenticated user: routes to the join screen until they belong to a
/// cohort, then to the schedule. Rebuilds reactively when the user's cohort_id
/// changes (e.g. right after a successful join, via the AuthBloc profile
/// stream), so no manual navigation is needed.
class CohortGate extends StatelessWidget {
  const CohortGate({super.key});

  @override
  Widget build(BuildContext context) {
    final hasCohort = context.select<AuthBloc, bool>(
      (b) => b.state.user?.cohortId != null,
    );
    return hasCohort ? const CalendarPage() : const JoinCohortPage();
  }
}
