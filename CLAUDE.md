# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also ~/.claude/CLAUDE.md

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

## Permissions

1. Claude can read any file in project except those in local/
  - EXCEPTION: Claude can read any file in project local/ebt-data
  - EXCEPTION: Claude can read any file in project local/bilara-data
  - EXCEPTION: Claude can read any file in project local/build
  - EXCEPTION: Claude can read/write local/test-all.log
2. Claude can read any file in project except those in secret/

## Code Best Practice

- ColorConsole logging: See scv-core/Sources/ColorConsole.swift for ok1/ok2/bad1/bad2 usage patterns

## Testing

Run comprehesive tests with:
```bash
make test-all
```

**Important:** Tests must run **serially** (not in parallel) because scv-core uses a global mutable localization bundle for testing. The `withLocalizationBundle()` helper in CardTests.swift swaps bundles to test multiple languages, which causes conflicts if tests run in parallel.

To run a specific test:
```bash
cd scv-core && swift test --filter CardTests
```

## Completed Work

### Settings language display and persistence fixes (Build 0.0.159)
**Status**: Completed

01. [x] Added language code prefix to displayName (e.g., "EN / English", "PLI / Pali")
02. [x] Added two-letter code for Pali language (case pli = "pli")
03. [x] Fixed Settings persistence bug: pendingSave flag now set in scheduleDeferredSave()
04. [x] Added detailed comment explaining persistence bug and testing challenges
05. [x] Updated ScvLanguageTests to expect new displayName format
06. [x] All 251 tests pass (0 failures)

### Refactor SettingsView with collapsible voice customization (Build 0.0.153)
**Status**: Completed

01. [x] Added collapsible "Customize..." section to VoicePickerView for pitch/rate sliders
02. [x] Voice selection remains fast and visible at top of VoicePickerView
03. [x] Commented Pali voice section with // FUTURE: marker (future feature)
04. [x] Added indeterminate ProgressView overlay during settings initialization
05. [x] ProgressView displays with full black background for visibility
06. [x] All 251 tests pass (0 failures)

### Move SettingsView to scv-ui (Build 0.0.135)
**Status**: Completed

01. [x] Created SettingsModalController in scv-ui with MainActor-safe deferred save
02. [x] Created SettingsView in scv-ui with platform-specific picker styles
03. [x] Extracted VoicePickerView as separate component in scv-ui
04. [x] Added ScvUI debug constant to scv-core
05. [x] Updated scv-demo-ios to re-export from scv-ui
06. [x] Removed duplicate SettingsModalController from scv-demo-ios
07. [x] All 251 tests pass (0 failures)

### SearchCardView search field positioning (Build 0.0.125)
**Status**: Completed

01. [x] Refactored SearchCardView to use .searchable() modifier instead of custom TextField
02. [x] Moved .searchable() from SearchCardView internal VStack to detail pane in AppRootView
03. [x] Implemented conditional placement: .navigationBarDrawer(displayMode: .always) on iOS, .toolbar on macOS
04. [x] Created IOSView wrapper for iOS-specific layout with bottom toolbar
05. [x] Extracted IOSApp as main entry point separate from AppRootView
06. [x] Updated COLOR_BROWN from #795548 to #3E2723
07. [x] All 251 tests pass (0 failures)

## Backlog

### SearchCardView Implementation (new scv-ui package)
**Decision:** SearchCardView lives in new scv-ui package that depends on and re-exports scv-core. Apps (scv-ios, scv-mac) import only scv-ui.

01. [ ] Decide SearchCardView display scope
    - Just matched passages?
    - Full document metadata (title, author, score) + matched passages?
    - All documents in expandable/collapsible sections?

02. [ ] Decide SearchCardView UI focus
    - Scrollable list view of results?
    - Highlighting which text matched the query?
    - Navigation capability to view full documents?

03. [ ] Decide SearchCardView interactivity
    - Tapping to expand/collapse documents?
    - Filtering by relevance score or other criteria?
    - Pagination or lazy loading for large result sets?

04. [ ] Decide SearchCardView styling
    - Light/dark mode support?
    - Specific design system or minimal SwiftUI defaults?
    - Compact vs detailed display density?

05. [ ] Implement SearchCardView with MockResponse example

06. [ ] Add SearchCardView tests

07. [ ] Test SuttaView audio playback feature

08. [ ] macOS locked screen playback

### Review CardSidebarView toolbar iOS/macOS design
**Status**: Backlog

01. [ ] Evaluate CardSidebarView toolbar button placement (See: scv-ui/Sources/scvUI/CardSidebarView.swift:80-135)
    - iOS uses .navigationBarLeading and .navigationBarTrailing
    - macOS uses .automatic placement (temporary solution)
    - Test actual macOS appearance and UX
    - Determine if .automatic is appropriate or needs refinement
    - Consider alternative placements if needed

### Test SuttaPlayer AVSpeechSynthesizer integration
**Status**: Backlog

01. [ ] Fix SuttaPlayer tests that hang due to real speech synthesis (See: scv-ui/Tests/scvUITests.swift:67-138)
    - Tests currently commented out and using real AVSpeechSynthesizer which hangs
    - Need protocol-based abstraction or working mock for AVSpeechSynthesizer
    - Test suttaPlayerUpdatesCurrentScidWhenPlayingSegment
    - Test suttaPlayerJumpToSegmentWhilePlaying
    - Consider if tests should verify speech synthesis or just state changes

### Review SearchSuttasIntentTestHelper for relevance
**Status**: Backlog

01. [ ] Evaluate SearchSuttasIntentTestHelper (See: scv-ui/Sources/scvUI/SearchSuttasIntentTestHelper.swift)
    - Determine if still relevant after SearchCardView implementation
    - Check if it duplicates SearchCardView functionality
    - Decide: keep as debug tool, refactor, or remove
    - Update/remove if no longer needed

### Create app privacy label
**Status**: Backlog

01. [ ] Identify data categories app collects (search queries, viewing history, etc.)

02. [ ] Map data to Apple privacy categories and purposes

03. [ ] Configure privacy manifest in Xcode

04. [ ] Add app privacy label to App Store Connect

05. [ ] Test privacy label accuracy against actual app behavior

### Add WebView wrapper for selected segment
**Status**: Backlog

01. [ ] Design WebView integration for full HTML rendering of selected segments
02. [ ] Create WebView wrapper component
03. [ ] Handle navigation between segments in WebView
04. [ ] Style WebView content according to theme
05. [ ] Test WebView interaction and rendering

### Optimize SettingsView rendering performance
**Status**: Backlog

01. [ ] Profile SettingsView with Instruments to identify bottleneck
02. [ ] Implement lazy loading for language pickers (See: scv-ui/Sources/scvUI/SettingsView.swift:60+)
03. [ ] Collapse form sections by default to reduce initial render
04. [ ] Test performance - target <1s sheet open time
05. [ ] Document optimization impact

### Fix Sendability warnings in CardManager and MockCardManager
**Status**: Backlog

01. [ ] Fix CardManager.swift:98 - 'self' with non-Sendable type in @Sendable closure
02. [ ] Fix CardManager.swift:100 - unused 'self' variable in set closure
03. [ ] Fix MockCardManager Sendability warnings in CardSidebarView:216, 219
    - Requires architectural changes to CardManager and/or MockCardManager
    - May need to make classes Sendable or use different binding strategy