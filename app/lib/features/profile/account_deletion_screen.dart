import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../auth/auth_repository.dart';
import 'account_deletion.dart';

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) => AccountDeletionService(
      db: FirebaseFirestore.instance,
      circles: ref.watch(circlesRepositoryProvider),
      history: ref.watch(historyRepositoryProvider),
    ));

final _blockingCirclesProvider = FutureProvider.autoDispose<List<OwnedCircle>>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const [];
  return ref.watch(accountDeletionServiceProvider).blockingCircles(uid);
});

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    if (_confirm.text.trim().toUpperCase() != 'DELETE') {
      setState(() => _error = 'Type DELETE to confirm.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      await auth.reauthenticate(_password.text); // before touching any data
      await ref.read(sharingStopperProvider)(); // stop location sharing first
      await ref.read(accountDeletionServiceProvider).deleteAllData(uid);
      await auth.deleteAuthUser();
      // Auth state changes to signed-out; the router moves to the login screen.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FirebaseException {
      if (mounted) {
        setState(() => _error = 'Could not finish deleting. Some data may already be removed. '
            'Check your connection and run it again.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocking = ref.watch(_blockingCirclesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: blocking.when(
          loading: () => const LoadingView(),
          error: (_, __) => MessageView(
            icon: Icons.cloud_off,
            title: 'Could not check your circles',
            actions: [FilledButton(onPressed: () => ref.invalidate(_blockingCirclesProvider), child: const Text('Retry'))],
          ),
          data: (owned) {
            if (owned.isNotEmpty) {
              return FormPage(children: [
                const Text('You own circles that still have other members. Transfer ownership or delete them first:'),
                const SizedBox(height: 12),
                for (final c in owned)
                  ListTile(
                    leading: const Icon(Icons.groups),
                    title: Text(c.name),
                    subtitle: Text('${c.memberCount} members'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/circles/${c.id}'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => ref.invalidate(_blockingCirclesProvider), child: const Text('Check again')),
              ]);
            }
            return FormPage(children: [
              const Text(
                'This permanently deletes your Circlo account and what the app can reach: your profile, '
                'memberships, shared location, travel history, place alerts and events, and any circle where you are the only member.\n\n'
                'Circlo has no server cleanup, so some copies that other circles hold may remain until they are removed '
                'by someone with access. If you lose your connection part-way, run this again.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Your password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                decoration: const InputDecoration(labelText: 'Type DELETE to confirm', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: _busy ? null : _delete,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Delete my account'),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
