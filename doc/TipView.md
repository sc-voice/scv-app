# TipView Proposal

## Purpose

A reusable modal component that presents contextual guidance to the user with a
title, body text, an "X" close icon, and a "Got it" dismiss button.

## Visual Design

```
┌─────────────────────────────┐
│ Title text              [X] │  ← tipBackground / tipForeground
├─────────────────────────────┤
│                             │
│  Body text goes here.       │  ← tipBackground / tipForeground
│                             │
├─────────────────────────────┤
│         [ Got it ]          │  ← tipBackground / tipForeground
└─────────────────────────────┘
```

- Background: `tipBackground` (dark green)
- All text and icons: `tipForeground` (bright yellow)
- Presented as a `.sheet` overlay (`.medium` detent), consistent with
  `BackgroundPlaybackInfoModal` pattern in SettingsView.swift:774

## Theme Changes

Add two new properties to `Theme` struct (Themes.swift:13):

```
tipBackground: Color   // dark green, both themes
tipForeground: Color   // bright yellow, both themes
```

Suggested values:

| Token           | Hex       | RGB                    |
|-----------------|-----------|------------------------|
| `tipBackground` | `#1B4D2E` | (0.106, 0.302, 0.180)  |
| `tipForeground` | `#FFE000` | (1.0, 0.878, 0.0)      |

These are theme-independent (same for light and dark) because the tip modal
overrides the ambient theme entirely.

## API

```swift
struct TipView: View {
  let title: String
  let text: String
  @Binding var isPresented: Bool
}
```

Caller controls presentation via `isPresented` binding — same pattern as
`BackgroundPlaybackInfoModal` (SettingsView.swift:774).

Usage example:

```swift
.sheet(isPresented: $showAddCardTip) {
  TipView(
    title: "tip.add_card.title".localized,
    text:  "tip.add_card.body".localized,
    isPresented: $showAddCardTip,
  )
  .presentationDetents([.medium])
}
```

## Dismiss Behavior

Two dismiss paths, both set `isPresented = false`:

1. "X" button in header (top-right)
2. "OK" button in footer (system-localized, no Localizable.strings entry needed)

No auto-dismiss timer. No connection to `Tips.active()` — that is the caller's
responsibility.

## Files to Change

1. `scv-core/Sources/Themes.swift` — add `tipBackground`, `tipForeground` to
   `Theme` struct and both `AppTheme` cases
2. `scv-core/Tests/ThemesTests.swift` — add assertions for new color properties
3. `scv-ui/Sources/scvUI/TipView.swift` — new file, `TipView` struct
4. `scv-core/Sources/Resources/en.lproj/Localizable.strings` — no changes
   needed; "OK" is system-localized

## Out of Scope

- Integration with `Tips.active()` — separate task
- Localization of specific tip content — caller's responsibility
- Animation on present/dismiss — use SwiftUI sheet default
