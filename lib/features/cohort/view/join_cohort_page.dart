import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/cohort_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/join_cohort_bloc.dart';

/// Shown to an authenticated user who is not yet in a cohort. On a successful
/// join, CohortGate switches away from this page automatically (the join
/// updates the user's cohort_id, which streams back through AuthBloc).
class JoinCohortPage extends StatelessWidget {
  const JoinCohortPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => JoinCohortBloc(context.read<CohortRepository>()),
      child: const _JoinCohortView(),
    );
  }
}

class _JoinCohortView extends StatefulWidget {
  const _JoinCohortView();

  @override
  State<_JoinCohortView> createState() => _JoinCohortViewState();
}

class _JoinCohortViewState extends State<_JoinCohortView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<JoinCohortBloc>().add(
      JoinCodeSubmitted(_codeController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join your cohort'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
          ),
        ],
      ),
      body: BlocListener<JoinCohortBloc, JoinCohortState>(
        listenWhen: (prev, curr) => prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter the join code from your class rep to see your '
                    "cohort's schedule.",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Join code',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter the join code'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<JoinCohortBloc, JoinCohortState>(
                    buildWhen: (prev, curr) => prev.status != curr.status,
                    builder: (context, state) {
                      final submitting = state.status == JoinStatus.submitting;
                      return FilledButton(
                        onPressed: submitting ? null : _submit,
                        child: submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Join'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
