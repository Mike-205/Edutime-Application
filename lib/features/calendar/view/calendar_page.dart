import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../data/models/app_user.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../cohort/view/cohort_page.dart';
import '../../scheduling/view/manage_lectures_page.dart';

/// Template calendar screen (Journey 2: student sees their schedule).
///
/// This shows the `table_calendar` wiring pattern only. Real data binding to a
/// Realtime lecture stream + day/week/semester views land in the calendar
/// milestone.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My schedule'),
        actions: [
          if (context.select<AuthBloc, bool>(
            (b) => b.state.user?.role == UserRole.classRep,
          ))
            IconButton(
              icon: const Icon(Icons.edit_calendar_outlined),
              tooltip: 'Manage schedule',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ManageLecturesPage(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'My cohort',
            onPressed: () {
              final cohortId = context.read<AuthBloc>().state.user?.cohortId;
              if (cohortId == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CohortPage(cohortId: cohortId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<void>(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
          ),
          const Expanded(
            child: Center(
              // Empty state per discovery: explain what's pending, don't look broken.
              child: Text('No lectures yet for the selected day.'),
            ),
          ),
        ],
      ),
    );
  }
}
