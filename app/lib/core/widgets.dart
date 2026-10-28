import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (label != null) ...[const SizedBox(height: 16), Text(label!)],
          ],
        ),
      );
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
  });
  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 26),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Centers content with a readable max width (works on phones and wide web screens).
class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children),
          ),
        ),
      );
}


/// Calm, colorful design tokens shared across Circlo's feature screens.
abstract final class CircloPalette {
  static const brand = Color(0xFF5B4FE8);
  static const mint = Color(0xFF18B8A5);
  static const violet = Color(0xFF9B8AFB);
  static const orange = Color(0xFFF59E0B);
  static const rose = Color(0xFFF472B6);
  static const ink = Color(0xFF171B3B);
  static const muted = Color(0xFF68708A);
  static const canvas = Color(0xFFF7F7FC);
  static const darkCanvas = Color(0xFF0D1524);
  static const darkSurface = Color(0xFF111C2D);
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4338CA), Color(0xFF665BEA), Color(0xFF18B8A5)],
  );

  static const accents = <Color>[brand, mint, violet, orange, rose];

  static Color accent(int index) => accents[index % accents.length];
}

/// Colored icon tile inspired by the shared FinMate/Stockly premium kit.
class PremiumIconChip extends StatelessWidget {
  const PremiumIconChip({
    super.key,
    required this.icon,
    this.color,
    this.size = 48,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(size * .31),
        border: Border.all(color: tint.withValues(alpha: .10)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: tint, size: size * .5),
    );
  }
}

/// Gradient feature card for brand-led entry points and summary panels.
class PremiumHeroCard extends StatelessWidget {
  const PremiumHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: CircloPalette.heroGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: CircloPalette.brand.withValues(alpha: .20),
              blurRadius: 28,
              offset: const Offset(0, 11),
            ),
          ],
        ),
        child: child,
      );
}

class PremiumBrandMark extends StatelessWidget {
  const PremiumBrandMark({super.key, this.size = 68});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: CircloPalette.heroGradient,
          borderRadius: BorderRadius.circular(size * .32),
          boxShadow: [
            BoxShadow(
              color: CircloPalette.brand.withValues(alpha: .22),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(Icons.hub_rounded, size: size * .48, color: Colors.white),
      );
}

class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      );
}

/// Firebase-backed Google provider button; behavior is supplied by the auth layer.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF202124),
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: Color(0xFFDADCE0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const SizedBox(
                width: 23,
                height: 23,
                child: Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Text(busy ? 'Connecting to Google…' : 'Continue with Google'),
          ],
        ),
      );
}
