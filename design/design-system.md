# Circlo Design System (DRAFT)

## Principles
1. **Trust first:** sharing state is always visible and reversible within two taps.
2. **Calm, clear, friendly:** family-oriented, not surveillance-like. Plain language.
3. **Map is the home:** everything else supports the map.
4. **Accessible by default.**

## Color (proposed; to be validated for contrast)
| Token | Light | Dark | Use |
|---|---|---|---|
| primary | #2563EB | #7BA4F7 | primary actions, selected |
| secondary | #0D9488 | #5EEAD4 | places, success accents |
| surface | #FFFFFF | #121826 | cards, sheets |
| background | #F5F7FB | #0B0F1A | screens |
| text-primary | #111827 | #F3F4F6 | body |
| status-online | #16A34A | #4ADE80 | sharing |
| status-paused | #D97706 | #FBBF24 | paused |
| status-unavailable | #6B7280 | #9CA3AF | unavailable |
| error | #DC2626 | #F87171 | errors |
Status is always shown with **icon + text**, never color alone.

## Typography
Inter (or platform default). Scale: Display 28/34, Title 22/28, Heading 18/24, Body 16/24, Caption 13/18. Support OS text scaling up to 200%.

## Spacing and layout
8-pt grid (4, 8, 12, 16, 24, 32). Min touch target 48×48 dp. Corner radius 12 (cards), 28 (bottom sheets), full (avatars).

## Components
App bar with circle switcher; bottom navigation (Map, Circles, Places, History, Profile); member avatar marker with status ring; member bottom sheet; place card; timeline item; join-code input (segmented); status chip; consent card; empty-state illustration + CTA; snackbar/banner for offline and errors; confirmation dialog for destructive actions.

## Accessibility
Semantic labels for markers and chips; map has an equivalent **list view** of members; focus order logical; contrast ≥4.5:1; reduce-motion respected; error text programmatically associated with fields.

## Responsive behavior
Phones primary (portrait). Tablets: two-pane (list + map). Landscape supported.
