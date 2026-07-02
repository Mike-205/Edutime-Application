import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/lecture.dart';
import '../../../data/repositories/lecture_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/schedule_cache.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../cohort/view/cohort_page.dart';
import '../../notifications/bloc/notification_bloc.dart';
import '../../notifications/view/notifications_page.dart';
import '../../scheduling/view/manage_lectures_page.dart';
import '../../settings/view/settings_page.dart';
import '../../venues/view/venue_availability_page.dart';
import '../bloc/calendar_bloc.dart';

/// The student's live schedule (Journey 2): a `table_calendar` with semester /
/// week views and a per-day agenda, driven by [CalendarBloc]. Updates within
/// seconds of a rep's change and renders the cached schedule when offline.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cohortId = context.select<AuthBloc, String?>(
      (b) => b.state.user?.cohortId,
    );
    if (cohortId == null) {
      return const Scaffold(
        body: Center(child: Text('Join a cohort to see its schedule.')),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => CalendarBloc(
            repository: context.read<LectureRepository>(),
            cache: const ScheduleCache(),
            cohortId: cohortId,
          )..add(const CalendarStarted()),
        ),
        BlocProvider(
          create: (context) =>
              NotificationBloc(context.read<NotificationRepository>())
                ..add(const NotificationsStarted()),
        ),
      ],
      child: const _CalendarView(),
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Group lectures by local day, sorted within each day. Built once per build
  /// so the calendar's per-cell `eventLoader` is an O(1) map lookup, not a scan.
  Map<DateTime, List<Lecture>> _groupByDay(List<Lecture> all) {
    final byDay = <DateTime, List<Lecture>>{};
    for (final l in all) {
      byDay.putIfAbsent(_dayKey(l.startTime.toLocal()), () => []).add(l);
    }
    for (final day in byDay.values) {
      day.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return byDay;
  }

  @override
  Widget build(BuildContext context) {
    final isRep = context.select<AuthBloc, bool>(
      (b) => b.state.user?.role == UserRole.classRep,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('My schedule'),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, notif) => IconButton(
              tooltip: 'Notifications',
              icon: Badge(
                isLabelVisible: notif.unread > 0,
                label: Text('${notif.unread}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsPage(),
                ),
              ),
            ),
          ),
          if (isRep)
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
            icon: const Icon(Icons.meeting_room_outlined),
            tooltip: 'Find a free room',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const VenueAvailabilityPage(),
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
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
          ),
        ],
      ),
      body: BlocBuilder<CalendarBloc, CalendarState>(
        builder: (context, state) {
          if (state.status == CalendarStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final byDay = _groupByDay(state.lectures);
          final dayLectures = byDay[_dayKey(_selectedDay)] ?? const [];
          return Column(
            children: [
              if (state.offline) const _OfflineBanner(),
              TableCalendar<Lecture>(
                firstDay: DateTime.utc(2020),
                lastDay: DateTime.utc(2030),
                focusedDay: _focusedDay,
                calendarFormat: _format,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Semester',
                  CalendarFormat.week: 'Week',
                },
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => byDay[_dayKey(day)] ?? const [],
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                onFormatChanged: (format) => setState(() => _format = format),
                onPageChanged: (focused) => _focusedDay = focused,
              ),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      context.read<CalendarBloc>().add(const CalendarRefreshed()),
                  child: _Agenda(day: _selectedDay, lectures: dayLectures),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            'Offline — showing the last saved schedule.',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}

class _Agenda extends StatelessWidget {
  const _Agenda({required this.day, required this.lectures});

  final DateTime day;
  final List<Lecture> lectures;

  @override
  Widget build(BuildContext context) {
    if (lectures.isEmpty) {
      // AlwaysScrollable so pull-to-refresh works even on an empty day.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text(
                'No lectures on ${DateFormat('EEE d MMM').format(day)}.',
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: lectures.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _LectureTile(lecture: lectures[i]),
    );
  }
}

class _LectureTile extends StatelessWidget {
  const _LectureTile({required this.lecture});

  final Lecture lecture;

  @override
  Widget build(BuildContext context) {
    final start = DateFormat('HH:mm').format(lecture.startTime.toLocal());
    final end = DateFormat('HH:mm').format(lecture.endTime.toLocal());
    final where = lecture.venueName ?? '—';
    final recurring = lecture.recurrenceGroupId != null;
    return ListTile(
      leading: CircleAvatar(child: Text(start.substring(0, 2))),
      title: Text(lecture.displayName),
      subtitle: Text(
        '${lecture.lecturerName} • $where\n$start – $end'
        '${recurring ? ' • weekly' : ''}',
      ),
      isThreeLine: true,
    );
  }
}
