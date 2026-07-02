import 'package:flutter/material.dart';

/// The Kenya DPA privacy notice + "independent student project" disclaimer,
/// shown at registration and in settings. Keep the wording in one place.
class PrivacyNotice extends StatelessWidget {
  const PrivacyNotice({super.key});

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
            Text('Privacy notice', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Edutime stores only what it needs to schedule your lectures: '
              'your name, email, cohort, role, and notification preferences '
              '(plus a registration number for students). Your email is visible '
              'only to you — never to classmates. Your data is not shared with '
              'third parties. You can request deletion of your account and data '
              'at any time below.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Edutime is an independent student project. It is not an official '
              'service of Chuka University.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
