import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/app_user.dart';
import '../../../data/repositories/cohort_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/cohort_bloc.dart';

/// Cohort details + (for a class rep) the join code and member management.
/// Reached from the schedule screen. Students see read-only cohort info;
/// the member directory and rep actions render only for a class rep.
class CohortPage extends StatelessWidget {
  const CohortPage({super.key, required this.cohortId});

  final String cohortId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CohortBloc(context.read<CohortRepository>())
            ..add(CohortRequested(cohortId)),
      child: const _CohortView(),
    );
  }
}

class _CohortView extends StatelessWidget {
  const _CohortView();

  @override
  Widget build(BuildContext context) {
    final isClassRep = context.select<AuthBloc, bool>(
      (b) => b.state.user?.role == UserRole.classRep,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('My cohort')),
      body: BlocConsumer<CohortBloc, CohortState>(
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
          final cohort = state.cohort;
          if (cohort == null) {
            return const Center(child: Text('Could not load your cohort.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CohortSummary(
                programName: cohort.programName ?? 'Your program',
                facultyName: cohort.facultyName,
                intakeYear: cohort.intakeYear,
                currentSemester: cohort.currentSemester,
              ),
              if (isClassRep) ...[
                const SizedBox(height: 16),
                _JoinCodeCard(joinCode: cohort.joinCode),
                const SizedBox(height: 16),
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...state.members.map((m) => _MemberTile(member: m)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CohortSummary extends StatelessWidget {
  const _CohortSummary({
    required this.programName,
    required this.facultyName,
    required this.intakeYear,
    required this.currentSemester,
  });

  final String programName;
  final String? facultyName;
  final int intakeYear;
  final int currentSemester;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(programName, style: theme.textTheme.titleLarge),
            if (facultyName != null)
              Text(facultyName!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('Intake $intakeYear • Semester $currentSemester'),
          ],
        ),
      ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.joinCode});

  final String? joinCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join code', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Share this with your cohort. Regenerate it if it leaks.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    joinCode ?? '—',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 2,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.read<CohortBloc>().add(
                    const CohortJoinCodeRegenerated(),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final AppUser member;

  @override
  Widget build(BuildContext context) {
    final isStudent = member.role == UserRole.student;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(member.fullName),
      subtitle: Text(_roleLabel(member.role)),
      trailing: isStudent
          ? IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Remove from cohort',
              onPressed: () => _confirmRemove(context),
            )
          : null,
    );
  }

  void _confirmRemove(BuildContext context) async {
    final bloc = context.read<CohortBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(
          '${member.fullName} will lose access to this cohort\'s schedule. '
          'They can rejoin with the code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      bloc.add(CohortStudentRemoved(member.id));
    }
  }

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.student => 'Student',
    UserRole.classRep => 'Class rep',
    UserRole.facultyRep => 'Faculty rep',
  };
}
