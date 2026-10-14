import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import 'auth_repository.dart';

/// Shown to signed-in users whose email is not verified yet (FR-007). Server rules also require
/// a verified email to create or join circles.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;
  String? _message;
  bool _sentOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send(auto: true));
  }

  Future<void> _send({bool auto = false}) async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendVerificationEmail();
      if (mounted) setState(() {
            _sentOnce = true;
            _message = 'We sent a verification link. Open it, then come back and tap "I have verified".';
          });
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = auto ? 'Tap "Send again" to get a verification email.' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ok = await ref.read(authRepositoryProvider).refreshVerification();
      if (!mounted) return;
      if (ok) {
        ref.invalidate(authStateProvider); // router re-evaluates and lets the user in
      } else {
        setState(() => _message = 'Not verified yet. Open the link in the email first.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not check. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? 'your email';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        actions: [TextButton(onPressed: () => ref.read(authRepositoryProvider).signOut(), child: const Text('Log out'))],
      ),
      body: SafeArea(
        child: FormPage(children: [
          const Icon(Icons.mark_email_unread_outlined, size: 48),
          const SizedBox(height: 16),
          Text('Please verify $email to keep your circles safe.', textAlign: TextAlign.center),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _check, child: const Text('I have verified')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _send, child: Text(_sentOnce ? 'Send again' : 'Send verification email')),
        ]),
      ),
    );
  }
}
