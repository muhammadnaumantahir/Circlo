import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

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
      body: Column(
        children: [
          const _MyPendingRequests(),
          Expanded(child: circles.when(
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
          final scheme = Theme.of(context).colorScheme;
          const icons = [
            Icons.home_rounded,
            Icons.diversity_3_rounded,
            Icons.group_work_rounded,
          ];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 104),
            itemCount: list.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0) return _CircleCollectionHero(count: list.length);
              final c = list[i - 1];
              final tone = (i - 1) % backgrounds.length;
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  minVerticalPadding: 12,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: PremiumIconChip(
                    icon: icons[tone],
                    color: CircloPalette.accent(tone),
                    size: 50,
                  ),
                  title: Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                    '${c.ownerUid == ref.watch(currentUidProvider) ? 'Owner' : 'Member'} · Members and sharing settings',
                  ),
                  trailing: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant.withOpacity(0.65)),
                    ),
                    child: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20),
                  ),
                  onTap: () => context.push('/circles/${c.id}'),
                ),
              );
            },
          );
        },
          ),
          ),
        ],
      ),
    );
  }
}

class _CircleCollectionHero extends StatelessWidget {
  const _CircleCollectionHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: PremiumHeroCard(
        padding: const EdgeInsets.all(20),
        radius: 26,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white.withValues(alpha: .22)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'PRIVATE BY DESIGN',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Your people,\ntogether.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '$count ${count == 1 ? 'circle' : 'circles'} · Invite people you trust and choose when to share.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .88),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .24), width: 1.5),
              ),
              child: const Icon(Icons.diversity_3_rounded, size: 38, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Join requests the user sent to approval-only circles that have not been answered yet.
class _MyPendingRequests extends ConsumerWidget {
  const _MyPendingRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final requests = ref.watch(myJoinRequestsProvider).valueOrNull ?? const <JoinRequest>[];
    final pending = [for (final r in requests) if (!r.approved) r];
    if (pending.isEmpty || uid == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          for (final r in pending)
            ListTile(
              leading: const Icon(Icons.hourglass_top),
              title: const Text('Waiting for approval'),
              subtitle: Text('Request with code ${formatJoinCode(r.joinCode)}'),
              trailing: TextButton(
                onPressed: () => ref
                    .read(circlesRepositoryProvider)
                    .cancelRequest(circleId: r.circleId, uid: uid)
                    .catchError((_) {
                  if (context.mounted) showSnack(context, 'Could not cancel. Try again.');
                }),
                child: const Text('Cancel'),
              ),
            ),
        ],
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
  const JoinCircleScreen({super.key, this.initialCode});
  final String? initialCode;

  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialCode = widget.initialCode;
    if (initialCode != null && initialCode.trim().isNotEmpty) {
      _code.text = formatJoinCode(normalizeJoinCode(initialCode));
    }
  }

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
      final outcome = await ref.read(circlesRepositoryProvider).joinCircle(
            uid: uid,
            displayName: profile.displayName,
            rawCode: _code.text,
          );
      if (!mounted) return;
      if (outcome.requested) {
        showSnack(context, 'Request sent. The owner has to approve it before you can join.');
        context.pop();
      } else {
        context.pushReplacement('/circles/${outcome.circleId}');
      }
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
          final members = membersAsync.valueOrNull ?? const <Member>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JoinCodeCard(circle: circle, isOwner: isOwner, uid: uid),
              if (isOwner) ...[
                SwitchListTile(
                  title: const Text('Require approval to join'),
                  subtitle: const Text('New people need your OK after entering the code.'),
                  value: circle.requiresApproval,
                  onChanged: (v) async {
                    try {
                      await ref.read(circlesRepositoryProvider).setRequiresApproval(circleId: circle.id, value: v);
                    } catch (_) {
                      if (context.mounted) showSnack(context, 'Could not change this setting. Try again.');
                    }
                  },
                ),
                _PendingRequests(circleId: circle.id),
              ],
              const SizedBox(height: 16),
              Text('Members', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: LoadingView()),
                error: (e, _) => const Text('Could not load members.'),
                data: (list) => Column(
                  children: [
                    for (final m in list)
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
              else if (uid != null) ...[
                OutlinedButton.icon(
                  onPressed: members.length > 1 ? () => _transfer(context, ref, circle, uid, members) : null,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Transfer ownership'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteCircle(context, ref, circle, uid),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete circle'),
                ),
                if (members.length <= 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('You are the only member. Delete the circle to leave it, or invite someone to transfer it to.'),
                  ),
              ],
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
      await ref.read(historyRepositoryProvider).removeCopies(uid: uid, circleId: circle.id);
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
      await ref.read(circlesRepositoryProvider).removeMember(circleId: circleId, memberUid: m.uid, ownerUid: ref.read(currentUidProvider)!);
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not remove the member. Try again.');
    }
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref, Circle circle, String uid, List<Member> members) async {
    final candidates = [for (final m in members) if (m.uid != uid) m];
    final chosen = await showDialog<Member>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Make who the new owner?'),
        children: [
          for (final m in candidates)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, m), child: Text(m.displayName)),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    final ok = await confirmAction(
      context,
      title: 'Transfer ownership to ${chosen.displayName}?',
      message: 'They will manage ${circle.name}, its join code and its members. You become a regular member.',
      confirmLabel: 'Transfer',
    );
    if (!ok) return;
    try {
      await ref.read(circlesRepositoryProvider).transferOwnership(circleId: circle.id, ownerUid: uid, newOwnerUid: chosen.uid);
      if (context.mounted) showSnack(context, 'Ownership transferred.');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not transfer ownership. Try again.');
    }
  }

  Future<void> _deleteCircle(BuildContext context, WidgetRef ref, Circle circle, String uid) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${circle.name}?',
      message: 'This removes the circle, its members, places, alerts and shared locations for everyone. It cannot be undone. '
          'If you lose your connection part-way, run it again.',
      confirmLabel: 'Delete circle',
    );
    if (!ok) return;
    try {
      await ref.read(circlesRepositoryProvider).deleteCircle(circleId: circle.id, ownerUid: uid);
      if (context.mounted) context.go('/circles');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not delete the circle. Check your connection and try again.');
    }
  }
}

class _PendingRequests extends ConsumerWidget {
  const _PendingRequests({required this.circleId});
  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(circleRequestsProvider(circleId)).valueOrNull ?? const <JoinRequest>[];
    final pending = [for (final r in requests) if (!r.approved) r];
    if (pending.isEmpty) return const SizedBox.shrink();
    final repo = ref.read(circlesRepositoryProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Join requests', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final r in pending)
            ListTile(
              title: Text(r.displayName),
              subtitle: const Text('Wants to join this circle'),
              trailing: Wrap(spacing: 4, children: [
                IconButton(
                  tooltip: 'Reject ${r.displayName}',
                  icon: const Icon(Icons.close),
                  onPressed: () => repo.rejectRequest(circleId: circleId, memberUid: r.uid).catchError((_) {
                    if (context.mounted) showSnack(context, 'Could not reject. Try again.');
                  }),
                ),
                IconButton(
                  tooltip: 'Approve ${r.displayName}',
                  icon: const Icon(Icons.check),
                  onPressed: () => repo.approveRequest(circleId: circleId, memberUid: r.uid).catchError((_) {
                    if (context.mounted) showSnack(context, 'Could not approve. Try again.');
                  }),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _JoinCodeCard extends ConsumerWidget {
  const _JoinCodeCard({required this.circle, required this.isOwner, required this.uid});
  final Circle circle;
  final bool isOwner;
  final String? uid;

  String _inviteLink() {
    if (!kIsWeb) return '';
    final base = Uri.base;
    if ((base.scheme != 'http' && base.scheme != 'https') || base.host.isEmpty) {
      return '';
    }
    return base.replace(
      path: '/circles/join',
      queryParameters: {'code': normalizeJoinCode(circle.joinCode)},
      fragment: '',
    ).toString();
  }

  String _inviteMessage() {
    final link = _inviteLink();
    if (link.isNotEmpty) {
      return 'Join "${circle.name}" on Circlo:\n$link\n\n'
          'Only share this invite with people you trust. The circle owner may require approval.';
    }
    return 'Join "${circle.name}" on Circlo.\n\n'
        'Open My Circles → Join and enter this code: ${formatJoinCode(circle.joinCode)}\n\n'
        'Only share this invite with people you trust. The circle owner may require approval.';
  }

  Future<void> _share(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _inviteMessage(),
          subject: 'Join ${circle.name} on Circlo',
        ),
      );
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not open the share sheet. Copy the join code instead.');
    }
  }

  Future<void> _showQr(BuildContext context) async {
    final link = _inviteLink();
    final data = link.isNotEmpty ? link : normalizeJoinCode(circle.joinCode);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Circle invite'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Theme.of(dialogContext).colorScheme.outlineVariant),
                ),
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 224,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR code to join ${circle.name}',
                  errorStateBuilder: (context, error) => const SizedBox(
                    width: 224,
                    height: 224,
                    child: Center(child: Text('Could not create the QR code.')),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                formatJoinCode(circle.joinCode),
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                link.isNotEmpty
                    ? 'Scan to open Circlo on this website with the code filled in.'
                    : 'Scan to read the join code, then open Circlo and choose My Circles → Join.',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.secondaryContainer.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 20),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text('Anyone with this code may join or request to join, depending on the circle settings.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: circle.joinCode));
              if (dialogContext.mounted) showSnack(dialogContext, 'Code copied');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiryAsync = ref.watch(codeExpiryProvider(circle.joinCode));
    final expiry = expiryAsync.valueOrNull;
    final expired = expiry != null && expiry.isBefore(DateTime.now());
    final inviteAvailable = !expiryAsync.isLoading && !expiryAsync.hasError && !expired;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const PremiumIconChip(icon: Icons.group_add_rounded, color: CircloPalette.brand, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Invite people', style: Theme.of(context).textTheme.titleLarge),
                ),
                if (expired)
                  const Chip(
                    avatar: Icon(Icons.schedule_rounded, size: 16),
                    label: Text('Expired'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              formatJoinCode(circle.joinCode),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 2.2, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            if (expiry != null)
              Text(expired ? 'This code has expired. Create a new one.' : 'Expires ${expiry.toLocal().toString().substring(0, 16)}')
            else if (expiryAsync.hasError)
              Text(
                'Could not check code expiry. Copy is still available; refresh before sharing.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Text(
              'Only share this code with people you trust. The owner can require approval before a new member joins.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: circle.joinCode));
                    if (context.mounted) showSnack(context, 'Code copied');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy code'),
                ),
                OutlinedButton.icon(
                  onPressed: inviteAvailable ? () => _showQr(context) : null,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Show QR'),
                ),
                OutlinedButton.icon(
                  onPressed: inviteAvailable ? () => _share(context) : null,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share invite'),
                ),
                if (isOwner && uid != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final choice = await showDialog<_ExpiryChoice>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('New join code'),
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                              child: Text('The current code stops working immediately. People already in the circle are not affected.'),
                            ),
                            for (final choice in _ExpiryChoice.values)
                              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, choice), child: Text(choice.label)),
                          ],
                        ),
                      );
                      if (choice == null) return;
                      try {
                        await ref.read(circlesRepositoryProvider).rotateJoinCode(
                              circleId: circle.id,
                              oldCode: circle.joinCode,
                              uid: uid,
                              expiry: choice.duration,
                            );
                        ref.invalidate(codeExpiryProvider);
                        if (context.mounted) showSnack(context, 'New code created');
                      } catch (_) {
                        if (context.mounted) showSnack(context, 'Could not create a new code. Try again.');
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('New code'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ExpiryChoice {
  never('No expiry', null),
  day('Expires in 24 hours', Duration(hours: 24)),
  week('Expires in 7 days', Duration(days: 7));

  const _ExpiryChoice(this.label, this.duration);
  final String label;
  final Duration? duration;
}
