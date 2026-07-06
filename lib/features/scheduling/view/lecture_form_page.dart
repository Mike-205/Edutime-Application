import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/course.dart';
import '../../../data/models/lecture.dart';
import '../../../data/models/venue.dart';
import '../../../data/repositories/lecture_repository.dart';
import '../bloc/lecture_form_bloc.dart';

/// Create a lecture, or edit a single occurrence when [existing] is provided.
/// Class-rep-only (the entry points are gated). Pops `true` on success so the
/// caller can refresh.
class LectureFormPage extends StatelessWidget {
  const LectureFormPage({super.key, this.existing});

  final Lecture? existing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LectureFormBloc(context.read<LectureRepository>()),
      child: _LectureForm(existing: existing),
    );
  }
}

class _LectureForm extends StatefulWidget {
  const _LectureForm({this.existing});
  final Lecture? existing;

  @override
  State<_LectureForm> createState() => _LectureFormState();
}

class _LectureFormState extends State<_LectureForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lecturerController;
  late final Future<List<Venue>> _venuesFuture;
  late final Future<List<Course>> _coursesFuture;

  String? _venueId;
  String? _courseId;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  int _weeks = 1;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _lecturerController = TextEditingController(
      text: existing?.lecturerName ?? '',
    );
    _venueId = existing?.venueId;
    _courseId = existing?.courseId;
    final start = existing?.startTime.toLocal() ?? DateTime.now();
    final end =
        existing?.endTime.toLocal() ??
        DateTime.now().add(const Duration(hours: 2));
    _date = DateTime(start.year, start.month, start.day);
    _start = TimeOfDay.fromDateTime(start);
    _end = TimeOfDay.fromDateTime(end);
    _venuesFuture = context.read<LectureRepository>().loadVenues();
    _coursesFuture = context.read<LectureRepository>().loadCoursesForMyCohort();
  }

  @override
  void dispose() {
    _lecturerController.dispose();
    super.dispose();
  }

  DateTime _combine(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_courseId == null) {
      _snack('Choose a unit.');
      return;
    }
    if (_venueId == null) {
      _snack('Choose a venue.');
      return;
    }
    final start = _combine(_start);
    final end = _combine(_end);
    if (!end.isAfter(start)) {
      _snack('The end time must be after the start time.');
      return;
    }
    FocusScope.of(context).unfocus();
    final bloc = context.read<LectureFormBloc>();
    if (_isEditing) {
      bloc.add(
        LectureEditSubmitted(
          lectureId: widget.existing!.id,
          courseId: _courseId!,
          lecturerName: _lecturerController.text.trim(),
          venueId: _venueId!,
          start: start,
          end: end,
        ),
      );
    } else {
      bloc.add(
        LectureCreateSubmitted(
          courseId: _courseId!,
          lecturerName: _lecturerController.text.trim(),
          venueId: _venueId!,
          start: start,
          end: end,
          weeks: _weeks,
        ),
      );
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit lecture' : 'New lecture')),
      body: BlocListener<LectureFormBloc, LectureFormState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          if (state.status == LectureFormStatus.success) {
            Navigator.of(context).pop(true);
          } else if (state.status == LectureFormStatus.failure &&
              state.errorMessage != null) {
            _snack(state.errorMessage!);
          }
        },
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CoursePicker(
                  future: _coursesFuture,
                  selectedId: _courseId,
                  onChanged: (id) => setState(() => _courseId = id),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lecturerController,
                  decoration: const InputDecoration(
                    labelText: 'Lecturer',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _VenuePicker(
                  future: _venuesFuture,
                  selectedId: _venueId,
                  onChanged: (id) => setState(() => _venueId = id),
                ),
                const SizedBox(height: 16),
                _DateField(
                  date: _date,
                  onPick: (d) => setState(() => _date = d),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'Start',
                        time: _start,
                        onPick: (t) => setState(() => _start = t),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TimeField(
                        label: 'End',
                        time: _end,
                        onPick: (t) => setState(() => _end = t),
                      ),
                    ),
                  ],
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 16),
                  _WeeksField(
                    weeks: _weeks,
                    onChanged: (w) => setState(() => _weeks = w),
                  ),
                ],
                const SizedBox(height: 24),
                BlocBuilder<LectureFormBloc, LectureFormState>(
                  buildWhen: (prev, curr) => prev.status != curr.status,
                  builder: (context, state) {
                    final submitting =
                        state.status == LectureFormStatus.submitting;
                    return FilledButton(
                      onPressed: submitting ? null : _submit,
                      child: submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Schedule'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoursePicker extends StatelessWidget {
  const _CoursePicker({
    required this.future,
    required this.selectedId,
    required this.onChanged,
  });

  final Future<List<Course>> future;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Course>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final courses = snapshot.data!;
        if (courses.isEmpty) {
          return const Text(
            'No units available yet. A faculty rep must add courses for your '
            'program before you can schedule.',
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: selectedId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Unit',
            border: OutlineInputBorder(),
          ),
          items: courses
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'Choose a unit' : null,
        );
      },
    );
  }
}

class _VenuePicker extends StatelessWidget {
  const _VenuePicker({
    required this.future,
    required this.selectedId,
    required this.onChanged,
  });

  final Future<List<Venue>> future;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Venue>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }
        final venues = snapshot.data!;
        return DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: 'Venue',
            border: OutlineInputBorder(),
          ),
          items: venues
              .map(
                (v) =>
                    DropdownMenuItem(value: v.id, child: Text(v.displayName)),
              )
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'Choose a venue' : null,
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onPick});
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(),
        ),
        child: Text('${date.year}-${_two(date.month)}-${_two(date.day)}'),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onPick,
  });
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(time.format(context)),
      ),
    );
  }
}

class _WeeksField extends StatelessWidget {
  const _WeeksField({required this.weeks, required this.onChanged});
  final int weeks;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: weeks,
      decoration: const InputDecoration(
        labelText: 'Repeat weekly for',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final w in [1, 2, 4, 8, 12, 14, 16])
          DropdownMenuItem(
            value: w,
            child: Text(w == 1 ? 'One-time (no repeat)' : '$w weeks'),
          ),
      ],
      onChanged: (w) => onChanged(w ?? 1),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
