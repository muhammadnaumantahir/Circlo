# Circlo Design System

**Status:** Implemented baseline, aligned with the FinMate / Stockly shared premium kit.  
**Updated:** 2026-10-30.

## Design direction

Circlo uses the same polished visual language as FinMate and Stockly while retaining a distinct family-safety identity: confident blue, fresh mint, restrained violet, neutral surfaces and clear privacy cues.

- **Trust first:** sharing state stays visible and reversible; never make location sharing appear enabled by default.
- **Calm, clear and friendly:** family-oriented, not surveillance-like. Plain language.
- **Map is the home:** map controls remain lightweight and legible above the map.
- **Premium, not noisy:** large page titles, soft tinted page surfaces, 24px cards, colourful icon chips and restrained gradient hero panels.
- **Responsive by default:** mobile navigation on narrow screens; a persistent workspace sidebar on desktop; content widths remain readable.
- **Accessible by default:** icon plus text for status, visible focus, contrast, reduced-motion support and 44px minimum touch targets.

## Brand and semantic tokens

| Token | Value | Use |
|---|---|---|
| Brand blue | `#2563EB` | Primary actions, selected navigation, focus |
| Deep blue | `#1D4ED8` | Gradient hero start |
| Mint | `#17C7A1` | Secondary actions, positive accents |
| Violet | `#8B7CFF` | Supporting feature accents |
| Success | `#16A34A` | Active / successful status |
| Warning | `#D97706` | Caution / pending status |
| Danger | `#DC2626` | Errors and emergency actions |
| Light canvas | `#F5F8FD` | App page background |
| Light input | `#EEF3F9` | Filled form controls |
| Dark canvas | `#07111F` | Dark-mode page background |
| Dark card | `#101B2C` | Dark-mode surface |
| Light border | `#DDE6F1` | Cards and controls |
| Dark border | `#2B3B52` | Dark-mode separators |

The canonical source is `app/lib/core/widgets.dart` (`CircloPalette`). Avoid local colour literals when a semantic token exists.

## Typography and spacing

- Use the platform sans-serif stack. Page titles are heavy (w900), slightly tightened and large enough to establish hierarchy.
- Body copy has a comfortable 1.4–1.5 line height. Secondary copy uses `onSurfaceVariant`.
- Use an 8pt rhythm: 8, 12, 16, 20, 24, 32.
- Cards use 24px radius, subtle outline and no heavy elevation.
- Hero panels use 28px radius, blue → blue → mint gradient, restrained brand glow.
- Controls use 16–17px radius, filled neutral backgrounds and clear focus borders.
- Icon chips use 40–50px sizes with category/status tint at low opacity.
- Page gutters are 20px on mobile and 24px on desktop; content remains readable.
- Minimum touch target: 44px.

## Shared components

| Component | Purpose |
|---|---|
| `PremiumPageHeader` | Page title, eyebrow, subtitle and optional trailing action |
| `PremiumHeroCard` | Gradient hero panel |
| `PremiumProfileHero` | Branded account header |
| `PremiumGlassCard` | Soft white/tinted card with subtle border and shadow |
| `PremiumMetricCard` | Dashboard metric with icon and semantic colour |
| `PremiumIconChip` | Consistent coloured icon tile |
| `PremiumStatusPill` | Semantic status capsule for sharing, roles and activity, with optional action |
| `PremiumTile` | Category-coloured settings and navigation row |
| `PremiumSection` | Uppercase section label with a grouped glass-card surface |
| `PremiumReveal` | Short fade/slide entrance respecting reduced motion |
| `LoadingView`, `MessageView` | Branded loading and recovery states |

Keep screen-specific UI in its feature module; reuse these shared components rather than creating a new style for every page.

## Navigation and responsive layout

- Mobile: Material 3 bottom navigation with persistent labels and a selected brand indicator.
- Desktop (1000px+): extended workspace rail, account card and privacy reminder.
- Main pages use a visible page heading and keep list content at a readable maximum width.
- Map remains full-bleed; controls use shared tokens without a full page card over the map.
- Create / Join and first-use onboarding use the responsive two-panel composition and stack on narrow screens.

## Premium refinement (2026-10-30)

The follow-up polish extends the FinMate / Stockly kit across the daily Circlo surfaces:

- Map: active-circle selector, visible sharing-state capsule, unified People search/filter panel and elevated people preview.
- Circles: ownership/member role capsules and large touch-friendly glass cards.
- Places: current-circle selector and saved-place capacity indicator.
- Profile: grouped profile form, category-coloured privacy rows and a separate destructive account action.
- Authentication: contained sign-in panel with an inline error surface and clear primary action.
- Theme: selected/unselected states for switches, checkboxes, radios and segmented controls.

These are presentation changes only. Sharing defaults, member access, backend data and navigation destinations must stay unchanged.

## Accessibility and motion

- Status is shown using icon + label, not colour alone.
- Keep keyboard focus visible and all primary taps at least 44px.
- Preserve semantic labels for map markers and controls.
- `PremiumReveal` returns the child immediately when the operating system requests reduced motion.
- Respect OS text scaling; avoid fixed-height text containers.
