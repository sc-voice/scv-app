# Accessibility in SC-Voice

## Overview

SC-Voice implements core accessibility features supporting users with vision, motor, and motion-sensitivity needs. This document describes implemented features, known limitations, and recommendations for future enhancements.

**Last Updated**: 2026-01-05
**Status**: Ready for App Store v1.0 submission with declared features

---

## Implemented Features ✅

### 1. VoiceOver Support (Screen Reader)

All interactive elements have accessibility labels:

**Buttons:**
- Search button (magnifying glass): `a11y.button.search`
- Add card: `a11y.button.add_card`
- Settings: `a11y.button.settings`
- Delete card: `a11y.button.delete_card`
- Play/Pause: `a11y.button.play_audio` / `a11y.button.pause_audio`
- External links: `a11y.button.external_link`

**Search Results:**
- Results labeled as `a11y.result` for VoiceOver navigation

**Implementation:**
- Localization strings: scv-core/Sources/Resources/en.lproj/Localizable.strings:325-347
- Label assignments: SearchCardView:194,525-528; CardSidebarView:176,187,199,211; SuttaHeaderView:71-72; AboutCardView:346-347,427

### 2. Dynamic Type / Large Text Support

Views adapt layout for accessibility text sizes (via `sizeCategory.isAccessibilityCategory`):

**SearchCardView**
- Stacks vertically when accessibility sizes active
- See: SearchCardView.swift:131,137-138

**SliderSettingRow**
- Stacks label above slider for large text
- See: SliderSettingRow.swift:18,27-29

**Text Rendering**
- All text uses system fonts that automatically scale with Dynamic Type settings
- Applied across: SearchCardView, CardSidebarView, SuttaCardView, SettingsView, AboutCardView

### 3. Reduce Motion Support

Animations respect system accessibility settings via `accessibilityReduceMotion`:

**Implemented In:**
- CardSidebarView: Sidebar slide animations (224, 229, 310, 314)
- SuttaCardView: Sutta content animations (112-113, 131-132)
- CollapsibleSection: Expand/collapse animations (71)
- ScvBackgroundsView: Background transitions (92)

**Pattern:**
```swift
withAnimation(reduceMotion ? nil : .linear(duration: 30)) {
  // animation
}
```

### 4. Color Contrast (WCAG AA Compliant)

Theme colors verified for WCAG AA contrast ratios:

- **Brown Accent** (#8b4513): Used for highlights in light theme
- **Teal Dark** (#065f73): Used for accents in light theme
- Explicitly documented in scv-core/Sources/Themes.swift:89-98

### 5. Minimum Touch Targets

All buttons meet Apple's 44x44 point minimum tap target size:

- Icon-only buttons: Explicit `.frame(minWidth: 44, minHeight: 44)`
- Standard buttons: Native SwiftUI sizing

**Files:** SearchCardView:191; CardSidebarView:127,173,184,195,207; SuttaHeaderView:68

### 6. Keyboard Navigation Basics

- Search result rows activatable with keyboard shortcut (`.defaultAction`)
- All standard SwiftUI buttons support Tab navigation
- See: SearchCardView.swift:530

### 7. Focus Ring Support

- Blue focus rings appear on keyboard navigation
- Customizable via Theme.focusColor
- See: scv-core/Sources/Themes.swift:50-51

---

## Partial / Incomplete Features ⚠️

### 1. Color-Only Information

**Issue:** Star ratings in search results use only color (★) without text labels.

**Location:** SearchCardView.swift:466,489

**Impact:** Users with color blindness can't distinguish score levels

**Fix:** Add `accessibilityValue` showing numeric score
```swift
.accessibilityValue("\(Int(result.score)) out of 10")
```

### 2. Layout Adaptation in AboutCardView & SettingsView

**Issue:** Unlike SearchCardView, AboutCardView and SettingsView don't stack vertically for accessibility text sizes.

**Location:** AboutCardView.swift; SettingsView.swift

**Impact:** Large text may overlap or become unreadable in multi-column layouts

**Fix:** Add `sizeCategory` checks and conditional layout stacking (similar to SearchCardView:137-138)

### 3. Semantic Link Traits

**Issue:** External links in AboutCardView lack accessibility traits indicating they are links.

**Location:** AboutCardView.swift:344,346-347,427

**Impact:** Screen reader users don't know links open external apps

**Fix:** Add `.accessibilityAddTraits(.isLink)` to link buttons

### 4. Link Hover Effects

**Issue:** Links are colored and underlined but show no hover effect on mouse/trackpad.

**Location:** AboutCardView.swift:344

**Status:** Known limitation - hover effects don't trigger on Mac Catalyst iPad apps (investigated, no solution found)

**Workaround:** Links remain visually distinct via color and underline

### 5. Keyboard Support for Collapsible Sections

**Issue:** CollapsibleSection buttons work with keyboard but no Enter/Space to expand/collapse.

**Location:** CollapsibleSection.swift

**Impact:** Keyboard-only users must use Tab + Return on button instead of standard Space/Enter pattern

### 6. Accessibility Hints and Values

**Not Implemented:**
- `accessibilityHint` for additional context (e.g., "Double-tap to open sutta")
- `accessibilityValue` for complex components (e.g., slider values, segment positions)

**Recommendation:** Add hints to buttons with non-obvious functions

---

## Localization

Accessibility labels are fully localized. Currently supported:
- English: scv-core/Sources/Resources/en.lproj/Localizable.strings:325-347
- Portuguese: scv-core/Sources/Resources/pt-PT.lproj/Localizable.strings

Keys:
```
a11y.button.search
a11y.button.add_card
a11y.button.settings
a11y.button.delete_card
a11y.button.play_audio
a11y.button.pause_audio
a11y.button.external_link
a11y.result
```

---

## Testing

### Manual Testing Checklist

- [ ] VoiceOver on iOS device: All buttons announced correctly
- [ ] VoiceOver: Search results read with appropriate context
- [ ] Dynamic Type: App readable at maximum accessibility text size
- [ ] Reduce Motion: Animations disabled when system setting active
- [ ] Keyboard Only: All search, navigation, and delete functions accessible
- [ ] Color Contrast: Text readable on light and dark backgrounds

### Accessibility Inspector Tools

Use Xcode's Accessibility Inspector (Xcode → Open Developer Tools → Accessibility Inspector) to:
- Verify all interactive elements are discoverable
- Check contrast ratios
- Validate touch target sizes
- Test with keyboard navigation

---

## App Store Declaration

### Recommended Features to Declare ✅

Can declare these with confidence:

1. **Supports VoiceOver** - Accessibility labels on all interactive elements
2. **Supports Dynamic Type** - Text scales with system settings; layouts adapt
3. **Respects Reduce Motion** - Animations honor system accessibility settings
4. **Color Contrast Compliant** - WCAG AA verified
5. **Minimum Touch Targets** - All buttons meet 44x44pt standard
6. **Basic Keyboard Navigation** - Can search and navigate with keyboard

### Features to NOT Declare ❌

Do not claim these until improvements made:

1. **Full Keyboard Navigation** - Some features (collapsible sections) need work
2. **Color-Independent Content** - Star ratings lack text labels
3. **Optimal Large Text Layout** - AboutCardView/SettingsView need layout work

---

## Future Enhancements (Backlog)

### v1.1 Priorities

1. **Add accessibilityValue to star ratings** (5 min fix)
2. **Add accessibilityHint to complex buttons** (15 min)
3. **Implement vertical stacking in AboutCardView** (30 min)
4. **Add keyboard support to CollapsibleSection** (30 min)
5. **Mark links with .isLink trait** (5 min)

### v1.2+ Nice-to-Have

1. Custom `AccessibilityRepresentation` for multi-column segment layout
2. Audio descriptions for images (if added)
3. Comprehensive keyboard shortcuts (Cmd+N for new card, etc.)
4. Accessibility snapshot tests
5. VoiceOver integration tests

---

## References

- **Apple Accessibility Guidelines**: https://developer.apple.com/accessibility/
- **WCAG 2.1 Standards**: https://www.w3.org/WAI/WCAG21/quickref/
- **SwiftUI Accessibility**: https://developer.apple.com/documentation/swiftui/accessibility
- **macOS/iOS Accessibility Inspector**: Xcode Developer Tools

---

## Code References

**Core Accessibility Implementation:**
- scv-core/Sources/Themes.swift:50-51, 89-98 (colors, focus)
- scv-core/Sources/Resources/*/Localizable.strings (a11y labels)
- scv-ui/Sources/scvUI/SearchCardView.swift:131-138, 194, 525-528
- scv-ui/Sources/scvUI/CardSidebarView.swift:25, 130, 176, 187, 199, 211, 224, 229, 310, 314
- scv-ui/Sources/scvUI/SuttaHeaderView.swift:71-72
- scv-ui/Sources/scvUI/AboutCardView.swift:344, 346-347, 427
- scv-ui/Sources/scvUI/SliderSettingRow.swift:27-29
- scv-ui/Sources/scvUI/SuttaCardView.swift:28, 112-113, 131-132
- scv-ui/Sources/scvUI/CollapsibleSection.swift:18, 71
- scv-ui/Sources/scvUI/ScvBackgroundsView.swift:80, 92

**Related Backlog Items:** See CLAUDE.md "Add VoiceOver accessibility labels" and "Fix accessibility layout adaptation"
