import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumBrandMark(size: 52),
            const SizedBox(height: 18),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary)),
            const SizedBox(height: 14),
            Text(label ?? 'Getting things ready…', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
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
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: CircloPalette.heroGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: CircloPalette.brand.withValues(alpha: .20), blurRadius: 26, offset: const Offset(0, 10))],
                ),
                child: Icon(icon, size: 40, color: Colors.white),
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
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children),
          ),
        ),
      );
}


/// Calm, colorful design tokens shared across Circlo's feature screens.
abstract final class CircloPalette {
  static const brand = Color(0xFF2563EB);
  static const brandDark = Color(0xFF60A5FA);
  static const mint = Color(0xFF17C7A1);
  static const violet = Color(0xFF8B7CFF);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const orange = Color(0xFFF59E0B);
  static const rose = Color(0xFFF472B6);
  static const ink = Color(0xFF10203A);
  static const muted = Color(0xFF65738B);
  static const canvas = Color(0xFFF5F8FD);
  static const darkCanvas = Color(0xFF07111F);
  static const darkSurface = Color(0xFF101B2C);
  static const inputLight = Color(0xFFEEF3F9);
  static const borderLight = Color(0xFFDDE6F1);
  static const borderDark = Color(0xFF2B3B52);
  static const heroGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF17C7A1)]);
  static const accents = <Color>[brand, mint, violet, orange, rose];
  static Color accent(int index) => accents[index % accents.length];
  static Color forCategory(String? value) => switch ((value ?? '').trim().toLowerCase()) {
    'home' || 'family' => const Color(0xFF2563EB),
    'places' || 'travel' => const Color(0xFF0D9488),
    'history' => const Color(0xFF8B7CFF),
    'people' || 'members' => const Color(0xFFE772A1),
    'safety' || 'sos' => const Color(0xFFDC3F4D),
    'notifications' || 'alerts' => const Color(0xFFD97706),
    _ => brand,
  };
}

class PremiumIconChip extends StatelessWidget {
  const PremiumIconChip({super.key, required this.icon, this.color, this.size = 40});
  final IconData icon;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: tint.withValues(alpha: .14), borderRadius: BorderRadius.circular(size * .31), border: Border.all(color: tint.withValues(alpha: .09))),
      alignment: Alignment.center,
      child: Icon(icon, color: tint, size: size * .52),
    );
  }
}

class PremiumReveal extends StatelessWidget {
  const PremiumReveal({super.key, required this.child, this.delay = Duration.zero, this.offset = 12});
  final Widget child;
  final Duration delay;
  final double offset;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final duration = const Duration(milliseconds: 360) + delay;
    final start = duration.inMilliseconds == 0 ? 0.0 : delay.inMilliseconds / duration.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: duration,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, (1 - value) * offset), child: child)),
      child: child,
    );
  }
}

class PremiumHeroCard extends StatelessWidget {
  const PremiumHeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 28});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) => PremiumReveal(
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: CircloPalette.heroGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        boxShadow: [BoxShadow(color: CircloPalette.brand.withValues(alpha: .24), blurRadius: 28, offset: const Offset(0, 11))],
      ),
      child: child,
    ),
  );
}

class PremiumBrandMark extends StatelessWidget {
  const PremiumBrandMark({super.key, this.size = 68});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: CircloPalette.heroGradient,
      borderRadius: BorderRadius.circular(size * .32),
      boxShadow: [BoxShadow(color: CircloPalette.brand.withValues(alpha: .22), blurRadius: 22, offset: const Offset(0, 8))],
    ),
    child: Icon(Icons.hub_rounded, size: size * .48, color: Colors.white),
  );
}

class PremiumPageHeader extends StatelessWidget {
  const PremiumPageHeader({super.key, required this.title, this.subtitle, this.trailing, this.eyebrow});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? eyebrow;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (eyebrow != null) ...[
          Text(eyebrow!.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, letterSpacing: 1.25)),
          const SizedBox(height: 5),
        ],
        Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.95)),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ])),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ]);
  }
}

class PremiumGlassCard extends StatelessWidget {
  const PremiumGlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.onTap, this.radius = 24});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: dark ? [const Color(0xFF17263E).withValues(alpha: .98), const Color(0xFF101B2C).withValues(alpha: .96)] : [Colors.white.withValues(alpha: .98), const Color(0xFFF2F7FF).withValues(alpha: .94)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: .08) : const Color(0xFFDDE7F5).withValues(alpha: .9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? .16 : .035), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return ClipRRect(borderRadius: BorderRadius.circular(radius), child: card);
    return Material(color: Colors.transparent, borderRadius: BorderRadius.circular(radius), child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: card));
  }
}

class PremiumProfileHero extends StatelessWidget {
  const PremiumProfileHero({super.key, required this.title, required this.subtitle, required this.initial, this.trailing});
  final String title;
  final String subtitle;
  final String initial;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => PremiumHeroCard(child: Row(children: [
    CircleAvatar(radius: 29, backgroundColor: Colors.white.withValues(alpha: .18), foregroundColor: Colors.white, child: Text(initial, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -.3)),
      const SizedBox(height: 4),
      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 12.5)),
    ])),
    if (trailing != null) ...[const SizedBox(width: 8), trailing!],
  ]));
}

class PremiumMetricCard extends StatelessWidget {
  const PremiumMetricCard({super.key, required this.label, required this.value, required this.icon, this.color, this.caption});
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? caption;
  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    final theme = Theme.of(context);
    return PremiumGlassCard(padding: const EdgeInsets.all(17), child: Row(children: [
      PremiumIconChip(icon: icon, color: tint, size: 44),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(color: tint, fontWeight: FontWeight.w900)),
        if (caption != null) Text(caption!, style: theme.textTheme.labelSmall),
      ])),
    ]));
  }
}

/// Small semantic status capsule used for sharing, role and activity states.
class PremiumStatusPill extends StatelessWidget {
  const PremiumStatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: .20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 13 : 15, color: tint),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w900,
              letterSpacing: .15,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Reusable settings / navigation row with a category-coloured icon.
class PremiumTile extends StatelessWidget {
  const PremiumTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
    onTap: enabled ? onTap : null,
    leading: PremiumIconChip(icon: icon, color: color, size: 42),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
  );
}

/// Uppercase section label and grouped premium surface used by settings pages.
class PremiumSection extends StatelessWidget {
  const PremiumSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumReveal(
      delay: const Duration(milliseconds: 70),
      offset: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PremiumGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 68,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: .42),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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
