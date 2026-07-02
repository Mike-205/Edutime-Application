import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/lecture.dart';
import '../../../data/repositories/lecture_repository.dart';
import '../bloc/manage_lectures_bloc.dart';
import 'lecture_form_page.dart';

/// Class-rep schedule management: the cohort's upcoming lectures with add, edit
/// and cancel. (The student-facing day/week/semester calendar is the calendar
/// milestone.)
class ManageLecturesPage extends StatelessWidget {
  const ManageLecturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ManageLecturesBloc(context.read<LectureRepository>())
            ..add(const LecturesRequested()),
      child: const _ManageLecturesView(),
    );
  }
}

class _ManageLecturesView extends StatelessWidget {
  const _ManageLecturesView();

  Future<void> _openForm(BuildContext context, {Lecture? existing}) async {
    final bloc = context.read<ManageLecturesBloc>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LectureFormPage(existing: existing)),
    );
    if (saved ?? false) bloc.add(const LecturesRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New lecture'),
      ),
      body: BlocConsumer<ManageLecturesBloc, ManageLecturesState>(
        listenWhen: (prev, curr) =>
            prev.actionMessage != curr.actionMessage ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          final message = state.actionMessage ?? state.errorMessage;
          if (message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.lectures.isEmpty) {
            return const Center(
              child: Text('No upcoming lectures. Tap + to schedule one.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => context.read<ManageLecturesBloc>().add(
              const LecturesRequested(),
            ),
            child: ListView.separated(
              itemCount: state.lectures.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final lecture = state.lectures[i];
                return _LectureTile(
                  lecture: lecture,
                  onEdit: () => _openForm(context, existing: lecture),
                  onCancel: () => _confirmCancel(context, lecture),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, Lecture lecture) async {
    final bloc = context.read<ManageLecturesBloc>();
    final recurring = lecture.recurrenceGroupId != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_busy),
              title: const Text('Cancel this lecture'),
              onTap: () => Navigator.of(sheetContext).pop('single'),
            ),
            if (recurring)
              ListTile(
                leading: const Icon(Icons.event_repeat),
                title: const Text('Cancel the whole series'),
                onTap: () => Navigator.of(sheetContext).pop('series'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Keep it'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (choice == 'single') {
      bloc.add(LectureCanceled(lecture.id));
    } else if (choice == 'series') {
      bloc.add(LectureCanceled(lecture.id, series: true));
    }
  }
}

class _LectureTile extends StatelessWidget {
  const _LectureTile({
    required this.lecture,
    required this.onEdit,
    required this.onCancel,
  });

  final Lecture lecture;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final start = lecture.startTime.toLocal();
    final end = lecture.endTime.toLocal();
    final when = DateFormat('EEE d MMM, HH:mm').format(start);
    final endTime = DateFormat('HH:mm').format(end);
    return ListTile(
      title: Text(lecture.displayName),
      subtitle: Text(
        '${lecture.lecturerName}\n$when – $endTime'
        '${lecture.recurrenceGroupId != null ? ' • weekly' : ''}',
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.event_busy_outlined),
            tooltip: 'Cancel',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
