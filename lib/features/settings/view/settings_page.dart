import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/privacy_notice.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/account_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/settings_bloc.dart';

/// Profile + account settings: who you are, the privacy notice, and the DPA
/// account-deletion path.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SettingsBloc(context.read<AccountRepository>())
            ..add(const SettingsStarted()),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthBloc, AppUser?>((b) => b.state.user);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listenWhen: (p, c) => p.errorMessage != c.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (user != null) _ProfileCard(user: user),
              const SizedBox(height: 16),
              const PrivacyNotice(),
              const SizedBox(height: 16),
              _DeletionSection(state: state),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(user.fullName),
        subtitle: Text(_roleLabel(user.role)),
      ),
    );
  }

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.student => 'Student',
    UserRole.classRep => 'Class representative',
    UserRole.facultyRep => 'Faculty representative',
  };
}

class _DeletionSection extends StatelessWidget {
  const _DeletionSection({required this.state});

  final SettingsState state;

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'We will delete your account and personal data. Your cohort\'s '
          'schedule stays intact. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Request deletion'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      context.read<SettingsBloc>().add(const DeletionRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (state.loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ));
    }
    if (state.pendingDeletion) {
      return Card(
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.hourglass_top, color: scheme.onErrorContainer),
          title: Text(
            'Deletion requested',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          subtitle: Text(
            'Your request is pending. The team will erase your account and data.',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: state.submitting ? null : () => _confirm(context),
      icon: state.submitting
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.delete_outline, color: scheme.error),
      label: Text(
        'Request account deletion',
        style: TextStyle(color: scheme.error),
      ),
    );
  }
}
