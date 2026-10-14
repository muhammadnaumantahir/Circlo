import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import '../location/sign_out.dart';

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

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
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
          return FormPage(children: [
            Text(email, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
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
