import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import '../history/history_models.dart';
import '../location/sign_out.dart';
import 'data_export.dart';
import 'profile_models.dart';

/// Shown after sign-up (or whenever a signed-in user has no profile yet).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late final TextEditingController _birthYear;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final y = ref.read(signupBirthYearProvider);
    _birthYear = TextEditingController(text: y?.toString() ?? '');
    // Use the Google profile name as a convenience, while still requiring a birth year.
    _name.text = ref.read(authRepositoryProvider).currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _birthYear.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).create(
            uid: uid,
            displayName: _name.text,
            birthYear: int.parse(_birthYear.text.trim()),
            phone: _phone.text,
          );
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your profile. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
      body: SafeArea(
        child: FormPage(children: [
          const Text('This is how people in your circles will see you.'),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: validateDisplayName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthYear,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Birth year', border: OutlineInputBorder()),
                validator: validateBirthYear,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  helperText: 'International format, e.g. +923001234567',
                  border: OutlineInputBorder(),
                ),
                validator: validatePhone,
              ),
            ]),
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
                : const Text('Continue'),
          ),
        ]),
      ),
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  final Set<String> _phoneShareBusyCircles = <String>{};

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      await ref.read(profileRepositoryProvider).update(uid: uid, displayName: name, phone: _phone.text);
      await ref.read(circlesRepositoryProvider).syncDisplayName(uid: uid, displayName: name);
      if (mounted) showSnack(context, 'Profile saved');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPhoneSharing(Circle circle, UserProfile profile, bool share) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final phone = profile.phone?.trim() ?? '';
    if (share && !RegExp(r'^[+][1-9][0-9]{6,14}$').hasMatch(phone)) {
      showSnack(context, 'Save a valid international phone number (for example +923001234567) before sharing it.');
      return;
    }

    setState(() => _phoneShareBusyCircles.add(circle.id));
    try {
      await ref.read(circlesRepositoryProvider).setPhoneSharing(
            circleId: circle.id,
            uid: uid,
            phone: phone,
            share: share,
          );
      if (mounted) {
        showSnack(
          context,
          share
              ? 'Your phone number is now shared only with ${circle.name}.'
              : 'Phone sharing turned off for ${circle.name}.',
        );
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not update phone sharing. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _phoneShareBusyCircles.remove(circle.id));
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider).valueOrNull;
    final uid = ref.read(currentUidProvider);
    if (profile == null || uid == null) return;
    final email = ref.read(authStateProvider).valueOrNull?.email ?? '';
    try {
      final circles = ref.read(myCirclesProvider).valueOrNull ?? const [];
      final memberships = {for (final m in ref.read(myMembershipsProvider).valueOrNull ?? const []) m.circleId: m};
      final subs = ref.read(mySubscriptionsProvider).valueOrNull ?? const [];
      final repo = ref.read(historyRepositoryProvider);
      final days = await repo.myDays(uid, limit: 200);
      final tracks = <DayTrack>[];
      for (final d in days) {
        final t = await repo.getMine(uid, d);
        if (t != null) tracks.add(t);
      }
      final json = buildExportJson(
        exportedAt: DateTime.now(),
        email: email,
        profile: profile,
        circles: [
          for (final c in circles)
            {
              'name': c.name,
              'role': c.ownerUid == uid ? 'owner' : 'member',
              'sharingLocation': memberships[c.id]?.sharesLocation ?? false,
              'sharingHistory': memberships[c.id]?.historyShared ?? false,
              'sharingBattery': memberships[c.id]?.shareBattery ?? false,
            },
        ],
        placeAlerts: [
          for (final s in subs)
            {'circleId': s.circleId, 'placeId': s.placeId, 'arrive': s.arrive, 'leave': s.leave, 'allMembers': s.allMembers},
        ],
        history: tracks,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Your data'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(child: SelectableText(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (ctx.mounted) showSnack(ctx, 'Copied to clipboard');
              },
              child: const Text('Copy'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not prepare your data. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final circlesAsync = ref.watch(myCirclesProvider);
    final uid = ref.watch(currentUidProvider);
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => const MessageView(icon: Icons.error_outline, title: 'Could not load your profile'),
        data: (p) {
          if (p == null) return const LoadingView();
          if (!_loaded) {
            _name.text = p.displayName;
            _phone.text = p.phone ?? '';
            _loaded = true;
          }
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final displayName = p.displayName.trim();
          final initial = displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();
          return FormPage(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.65)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Text(
                      initial,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName.isEmpty ? 'Your profile' : displayName, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Personal account',
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Personal details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  validator: validateDisplayName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder()),
                  validator: validatePhone,
                ),
              ]),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save changes'),
            ),
            const SizedBox(height: 28),
            Text('Calls and texts', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Your phone number stays private unless you share it with a specific circle. '
              'Only members of that circle can see it. Turning sharing off removes that circle’s copy.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            circlesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const MessageView(
                icon: Icons.cloud_off,
                title: 'Could not load your circles',
                message: 'Your private phone number has not been changed.',
              ),
              data: (circles) => circles.isEmpty
                  ? const MessageView(
                      icon: Icons.groups_outlined,
                      title: 'No circles yet',
                      message: 'Create or join a circle before sharing your number.',
                    )
                  : Column(
                      children: [
                        for (final circle in circles)
                          _PhoneSharingTile(
                            circle: circle,
                            uid: uid,
                            busy: _phoneShareBusyCircles.contains(circle.id),
                            hasValidPhone: RegExp(r'^[+][1-9][0-9]{6,14}$').hasMatch((p.phone ?? '').trim()),
                            onChanged: (share) => _setPhoneSharing(circle, p, share),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 28),
            Text('Privacy & data', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/history/settings'),
              icon: const Icon(Icons.history),
              label: const Text('Travel history settings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/sharing'),
              icon: const Icon(Icons.share_location),
              label: const Text('Location sharing'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _export(context, ref),
              icon: const Icon(Icons.download),
              label: const Text('Export my data'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => signOutStoppingSharing(ref),
              child: const Text('Log out'),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => context.push('/account/delete'),
              icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
              label: Text('Delete account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ]);
        },
      ),
    );
  }
}


class _PhoneSharingTile extends ConsumerWidget {
  const _PhoneSharingTile({
    required this.circle,
    required this.uid,
    required this.busy,
    required this.hasValidPhone,
    required this.onChanged,
  });

  final Circle circle;
  final String? uid;
  final bool busy;
  final bool hasValidPhone;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(sharedContactsProvider(circle.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: contacts.when(
        loading: () => const ListTile(
          leading: Icon(Icons.phone_iphone_rounded),
          title: Text('Loading sharing settings'),
          trailing: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) => ListTile(
          leading: const Icon(Icons.phone_iphone_rounded),
          title: Text(circle.name),
          subtitle: const Text('Could not load this circle’s phone-sharing state.'),
          trailing: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        ),
        data: (list) {
          final shared = uid != null && list.any((contact) => contact.uid == uid);
          final subtitle = shared
              ? 'Your number is visible to this circle’s members.'
              : hasValidPhone
                  ? 'Your number is private in this circle.'
                  : 'Save your phone number above before enabling sharing.';
          return SwitchListTile(
            secondary: const Icon(Icons.phone_iphone_rounded),
            title: Text(circle.name),
            subtitle: Text(subtitle),
            value: shared,
            onChanged: busy || (!hasValidPhone && !shared) ? null : onChanged,
          );
        },
      ),
    );
  }
}
