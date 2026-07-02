import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/venue_availability.dart';
import '../../../data/repositories/lecture_repository.dart';
import '../bloc/venue_availability_bloc.dart';

/// "Which rooms are free?" (Journey 3). Pick a time; rooms show free/occupied,
/// updating live when the user's own cohort books or frees a room.
class VenueAvailabilityPage extends StatelessWidget {
  const VenueAvailabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return BlocProvider(
      create: (context) => VenueAvailabilityBloc(
        repository: context.read<LectureRepository>(),
        initialAt: now,
      )..add(AvailabilityRequested(now)),
      child: const _VenueAvailabilityView(),
    );
  }
}

class _VenueAvailabilityView extends StatelessWidget {
  const _VenueAvailabilityView();

  Future<void> _pickTime(BuildContext context, DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !context.mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    context.read<VenueAvailabilityBloc>().add(AvailabilityRequested(at));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a free room')),
      body: BlocBuilder<VenueAvailabilityBloc, VenueAvailabilityState>(
        builder: (context, state) {
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(
                  'At ${DateFormat('EEE d MMM, HH:mm').format(state.at.toLocal())}',
                ),
                trailing: TextButton(
                  onPressed: () => _pickTime(context, state.at),
                  child: const Text('Change'),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _body(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, VenueAvailabilityState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final bloc = context.read<VenueAvailabilityBloc>();
    if (state.errorMessage != null) {
      return _Retryable(
        message: state.errorMessage!,
        onRetry: () => bloc.add(AvailabilityRequested(state.at)),
      );
    }
    if (state.venues.isEmpty) {
      return const Center(child: Text('No rooms have been set up yet.'));
    }
    // Free rooms first — the whole point is finding one.
    final sorted = [...state.venues]
      ..sort((a, b) {
        if (a.occupied != b.occupied) return a.occupied ? 1 : -1;
        return a.displayName.compareTo(b.displayName);
      });
    return RefreshIndicator(
      onRefresh: () async => bloc.add(AvailabilityRequested(state.at)),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => _VenueTile(slot: sorted[i]),
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.slot});

  final VenueSlot slot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final free = !slot.occupied;
    final until = slot.busyUntil;
    return ListTile(
      leading: Icon(
        free ? Icons.meeting_room_outlined : Icons.no_meeting_room_outlined,
        color: free ? Colors.green : scheme.error,
      ),
      title: Text(slot.displayName),
      subtitle: Text(_roomTypeLabel(slot.roomType)),
      trailing: Text(
        free
            ? 'Free'
            : until != null
            ? 'Busy until ${DateFormat('HH:mm').format(until.toLocal())}'
            : 'Busy',
        style: TextStyle(
          color: free ? Colors.green : scheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _roomTypeLabel(String raw) => switch (raw) {
    'lecture_hall' => 'Lecture hall',
    'lab' => 'Lab',
    'conference_hall' => 'Conference hall',
    _ => raw,
  };
}

class _Retryable extends StatelessWidget {
  const _Retryable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
