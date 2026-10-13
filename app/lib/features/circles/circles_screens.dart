import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/join_code.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import 'circle_models.dart';

class CirclesScreen extends ConsumerWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Circles'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/circles/join'),
            icon: const Icon(Icons.vpn_key),
            label: const Text('Join'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/circles/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create circle'),
      ),
      body: circles.when(
        loading: () => const LoadingView(),
        error: (e, _) => MessageView(
          icon: Icons.cloud_off,
          title: 'Could not load your circles',
          message: 'Check your connection and try again.',
          actions: [FilledButton(onPressed: () => ref.invalidate(myCirclesProvider), child: const Text('Retry'))],
        ),
        data: (list) {
          if (list.isEmpty) {
            return MessageView(
              icon: Icons.group_add,
              title: 'No circles yet',
              message: 'Create a circle for your family or friends, or join one with a code.',
              actions: [
                FilledButton(onPressed: () => context.push('/circles/create'), child: const Text('Create a circle')),
                OutlinedButton(onPressed: () => context.push('/circles/join'), child: const Text('Join with a code')),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = list[i];
              return ListTile(
                leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase())),
                title: Text(c.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/circles/${c.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});
  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(profileProvider).valueOrNull;
    if (uid == null || profile == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(circlesRepositoryProvider).createCircle(
            uid: uid,
            displayName: profile.displayName,
            name: _name.text,
          );
      if (mounted) context.pushReplacement('/circles/$id');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create the circle. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a circle')),
      body: SafeArea(
        child: FormPage(children: [
          const Text('A circle is a private group. Only people you invite with the join code can see it.'),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Circle name', border: OutlineInputBorder()),
              validator: validateCircleName,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create circle'),
          ),
        ]),
      ),
    );
  }
}

class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key});
  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(profileProvider).valueOrNull;
    if (uid == null || profile == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(circlesRepositoryProvider).joinCircle(
            uid: uid,
            displayName: profile.displayName,
            rawCode: _code.text,
          );
      if (mounted) context.pushReplacement('/circles/$id');
    } on JoinFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FirebaseException {
      if (mounted) setState(() => _error = 'Could not join. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a circle')),
      body: SafeArea(
        child: FormPage(children: [
          const Text('Ask the circle owner for the join code and enter it below.'),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Join code', hintText: 'ABCDE-FGHJK', border: OutlineInputBorder()),
              validator: (v) => isValidJoinCode(normalizeJoinCode(v ?? '')) ? null : 'Enter the 10-character code',
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Join circle'),
          ),
        ]),
      ),
    );
  }
}

class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({super.key, required this.circleId});
  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleProvider(circleId));
    final membersAsync = ref.watch(membersProvider(circleId));
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(title: Text(circleAsync.valueOrNull?.name ?? 'Circle')),
      body: circleAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => MessageView(
          icon: Icons.lock_outline,
          title: 'This circle is not available',
          message: 'You may have left it or been removed.',
          actions: [FilledButton(onPressed: () => context.go('/circles'), child: const Text('Back to my circles'))],
        ),
        data: (circle) {
          if (circle == null) {
            return MessageView(
              icon: Icons.search_off,
              title: 'Circle not found',
              actions: [FilledButton(onPressed: () => context.go('/circles'), child: const Text('Back to my circles'))],
            );
          }
          final isOwner = circle.ownerUid == uid;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JoinCodeCard(circle: circle, isOwner: isOwner, uid: uid),
              const SizedBox(height: 16),
              Text('Members', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: LoadingView()),
                error: (e, _) => const Text('Could not load members.'),
                data: (members) => Column(
                  children: [
                    for (final m in members)
                      ListTile(
                        leading: CircleAvatar(child: Text(m.displayName.isEmpty ? '?' : m.displayName[0].toUpperCase())),
                        title: Text(m.uid == uid ? '${m.displayName} (you)' : m.displayName),
                        subtitle: Text(m.isOwner ? 'Owner' : 'Member'),
                        trailing: (isOwner && m.uid != uid)
                            ? IconButton(
                                tooltip: 'Remove ${m.displayName}',
                                icon: const Icon(Icons.person_remove),
                                onPressed: () => _remove(context, ref, m),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!isOwner && uid != null)
                OutlinedButton.icon(
                  onPressed: () => _leave(context, ref, circle, uid),
                  icon: const Icon(Icons.logout),
                  label: const Text('Leave circle'),
                )
              else
                const Text(
                  'As the owner you cannot leave yet. Transferring ownership and deleting a circle are coming in a later update.',
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Circle circle, String uid) async {
    final ok = await confirmAction(
      context,
      title: 'Leave ${circle.name}?',
      message: 'You will stop seeing this circle and the members will stop seeing you here.',
      confirmLabel: 'Leave',
    );
    if (!ok) return;
    try {
      await ref.read(circlesRepositoryProvider).leaveCircle(circleId: circle.id, uid: uid);
      if (context.mounted) context.go('/circles');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not leave. Check your connection and try again.');
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Member m) async {
    final ok = await confirmAction(
      context,
      title: 'Remove ${m.displayName}?',
      message: 'They will immediately lose access to this circle.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await ref.read(circlesRepositoryProvider).removeMember(circleId: circleId, memberUid: m.uid);
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not remove the member. Try again.');
    }
  }
}

class _JoinCodeCard extends ConsumerWidget {
  const _JoinCodeCard({required this.circle, required this.isOwner, required this.uid});
  final Circle circle;
  final bool isOwner;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join code', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              formatJoinCode(circle.joinCode),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            const Text('Only share this code with people you trust. Anyone with it can join this circle.'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: circle.joinCode));
                  if (context.mounted) showSnack(context, 'Code copied');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              if (isOwner && uid != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Create a new code?',
                      message: 'The current code stops working immediately. People already in the circle are not affected.',
                      confirmLabel: 'New code',
                    );
                    if (!ok) return;
                    try {
                      await ref.read(circlesRepositoryProvider).rotateJoinCode(
                            circleId: circle.id,
                            oldCode: circle.joinCode,
                            uid: uid!,
                          );
                      if (context.mounted) showSnack(context, 'New code created');
                    } catch (_) {
                      if (context.mounted) showSnack(context, 'Could not create a new code. Try again.');
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('New code'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
