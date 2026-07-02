import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/notification.dart';
import '../../../data/repositories/notification_repository.dart';
import '../bloc/notification_bloc.dart';

/// In-app notification history: the lecture changes pushed to this student,
/// newest first, with unread highlighting and mark-read.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          NotificationBloc(context.read<NotificationRepository>())
            ..add(const NotificationsStarted()),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) => TextButton(
              onPressed: state.unread == 0
                  ? null
                  : () => context.read<NotificationBloc>().add(
                      const NotificationsAllRead(),
                    ),
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.items.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _NotificationTile(item: state.items[i]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(_icon(item.type), color: _color(item.type, scheme)),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: item.isRead ? FontWeight.normal : FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${item.message}\n${DateFormat('EEE d MMM, HH:mm').format(item.createdAt.toLocal())}',
      ),
      isThreeLine: true,
      trailing: item.isRead
          ? null
          : Icon(Icons.circle, size: 10, color: scheme.primary),
      onTap: item.isRead
          ? null
          : () => context.read<NotificationBloc>().add(
              NotificationRead(item.id),
            ),
    );
  }

  IconData _icon(NotifType type) => switch (type) {
    NotifType.created => Icons.event_available,
    NotifType.updated => Icons.edit_calendar,
    NotifType.canceled => Icons.event_busy,
  };

  Color _color(NotifType type, ColorScheme scheme) => switch (type) {
    NotifType.created => Colors.green,
    NotifType.updated => scheme.primary,
    NotifType.canceled => scheme.error,
  };
}
