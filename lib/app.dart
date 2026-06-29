import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/calendar/view/calendar_page.dart';

/// Root widget. Routing/auth-gating is wired up in later milestones; for now it
/// lands on the calendar template screen.
class EdutimeApp extends StatelessWidget {
  const EdutimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edutime',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const CalendarPage(),
    );
  }
}
