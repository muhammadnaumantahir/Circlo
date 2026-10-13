import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../location/sharing_status.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationFeedProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: feed.when(
        loading: () => const LoadingView(),
        error: (_, __) => const MessageView(icon: Icons.cloud_off, title: 'Could not load notifications'),
        data: (items) => ListView(
          children: [
            const Card(
              margin: EdgeInsets.all(12),
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Alerts appear here while Circlo is open.'),
                subtitle: Text('Phone push notifications about other people\'s movements are not available yet.'),
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No arrivals or departures yet.\nTurn on alerts for a place in the Places tab.', textAlign: TextAlign.center)),
              )
            else
              for (final i in items)
                ListTile(
                  leading: Icon(i.isArrival ? Icons.login : Icons.logout),
                  title: Text(i.text),
                  subtitle: Text('${i.circleName} · ${formatAgo(i.at, now)}'),
                ),
          ],
        ),
      ),
    );
  }
}
