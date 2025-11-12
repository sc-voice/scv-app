# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also ~/.claude/CLAUDE.md

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

## Permissions

- you can read any file in project except those in secret/

## Invariant Violations

**Total Count: 1**

### Violation #1 (2025-11-12)
- Invariant: wend workflow (must create .commit-msg before stopping)
- Issue: Did not create .commit-msg at wend. Developer had to point out the omission.
- Root Cause: Completed wend tasks but forgot to create .commit-msg file with commit message and details
- Impact: Developer could not run `make commit` without first requesting the missing file

## Testing

### scv-core Package Tests

Run tests with:
```bash
make test-core
```

**Important:** Tests must run **serially** (not in parallel) because scv-core uses a global mutable localization bundle for testing. The `withLocalizationBundle()` helper in CardTests.swift swaps bundles to test multiple languages, which causes conflicts if tests run in parallel.

For verbose output:
```bash
make test-core-verbose
```

To run a specific test:
```bash
cd scv-core && swift test --filter CardTests
```

## Backlog

### Set up themes
**Status**: Complete

01. [x] Design theme system (light, dark, custom color schemes)

02. [x] Implement theme provider/context for SwiftUI app

03. [x] Apply themes to existing views (ContentView, SettingsView, SuttaView)

04. [x] Add theme selection to Settings

05. [x] Test theme switching and persistence

### Create app privacy label
**Status**: Backlog

01. [ ] Identify data categories app collects (search queries, viewing history, etc.)

02. [ ] Map data to Apple privacy categories and purposes

03. [ ] Configure privacy manifest in Xcode

04. [ ] Add app privacy label to App Store Connect

05. [ ] Test privacy label accuracy against actual app behavior

### Render segment text as HTML
**Status**: Complete

01. [x] Research HTML structure in segment data (found `<span class="scv-matched">` tags)
02. [x] Implement HTMLParser with AttributedString for inline colored text
03. [x] Update SuttaView to use HTMLParser (matched text shown with accentColor)

### Add WebView wrapper for selected segment
**Status**: Backlog

01. [ ] Design WebView integration for full HTML rendering of selected segments
02. [ ] Create WebView wrapper component
03. [ ] Handle navigation between segments in WebView
04. [ ] Style WebView content according to theme
05. [ ] Test WebView interaction and rendering

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

### Refactor Segment struct for language-aware text
**Status**: Complete

01. [x] Review current Segment implementation (no refactoring needed - already language-aware)

### Track current segment selection in MLDocument
**Status**: Complete

01. [x] Add currentScid: String? property to MLDocument
02. [x] Update SuttaView to set currentScid when user taps a segment
03. [x] Display dashed border around currently selected segment
04. [x] Persist currentScid selection in document state
05. [x] Test segment selection and highlighting

### Set currentScid when playing audio segment
**Status**: Complete

01. [x] Locate audio playback trigger in SuttaPlayer
02. [x] Update currentScid when segment starts playing
03. [x] Add test case to verify currentScid tracking during playback
04. [x] Verify no regressions (all 203 tests pass)

### Use currentScid to indicate current segment during playback
**Status**: Complete

01. [x] Refactor MLDocument from struct to @Model class for shared reference
02. [x] Modify SuttaView.shouldHighlight() to use scid-based comparison
03. [x] Update SuttaPlayer.play() to start at currentScid if set
04. [x] Add jumpToSegment() for tapping during playback
05. [x] Verify UI highlights stay in sync with playback

### Synchronize SuttaPlayer audio with currentScid
**Status**: Complete

01. [x] Fix audio/currentScid desynchronization when user jumps to segment during playback
02. [x] Implement nextIndexToPlay as single source of truth for next segment
03. [x] Update jumpToSegment to set nextIndexToPlay without calling playSegmentAt
04. [x] Add indexOfScid() method to MLDocument for segment index lookup
05. [x] Add tests for indexOfScid and audio synchronization behavior
06. [x] Verify all 207 tests pass

### Show DE MLDocument when docLang is DE and EN MLDocument otherwise
**Status**: Complete

01. [x] Examine Settings for docLang property
02. [x] Locate mock responses for DE and EN MLDocuments
03. [x] Review how SuttaView currently loads/displays MLDocument
04. [x] Implement language-based document selection logic
05. [x] Test switching between DE and EN documents
06. [x] Improve make test-all output to show test results

### Synchronize docSpeech with docLang using Settings.validate()
**Status**: Complete

01. [x] Examine Settings implementation (properties, current structure, location)
02. [x] Examine SpeechConfig structure and how to retrieve SpeechConfig for a language
03. [x] Implement validate() method with synchronization logic (docSpeech ← docLang)
04. [x] Add validate() calls to property observers for setting changes
05. [x] Add validate() call at app launch after Settings deserialization
06. [x] Write tests for validate() scenarios (matching, non-matching, missing SpeechConfig)
07. [x] Run make test to verify implementation

### Change iOS home screen display name to SCV-Demo
**Status**: Complete

01. [x] Locate current display name configuration in scv-demo-ios (Info.plist or project.pbxproj)
02. [x] Update CFBundleDisplayName to "SCV-Demo"
03. [x] Build and verify display name appears as "SCV-Demo"
04. [x] Run make test to verify no regressions

### Fix French sutta not showing in scv-demo-ios
**Status**: Complete

01. [x] Verify fr.lproj is registered in scv-core Package.swift resources
02. [x] Examine SearchResponse.createMockResponse(language:) implementation
03. [x] Check ContentView.loadMockResponse() uses Settings.shared.docLang
04. [x] Test with Settings.docLang set to French
05. [x] Run make test to verify no regressions

### Add phrase-based search filtering to EbtData
**Status**: Complete

01. [x] Identify false positives in keyword search (an4.257, mn9 for "root of suffering")
02. [x] Verify an4.257 doesn't contain exact phrase "root of suffering"
03. [x] Implement searchPhrase() two-step filtering (keyword + phrase match)
04. [x] Add searchKeywordsWithScores() helper for debugging/display
05. [x] Fix Settings.reset() to include maxDoc reset
06. [x] Write tests for phrase search functionality
07. [x] Display search results with scores and timing (0.033 seconds total)
08. [x] Verify all 228 tests pass

### Show search results from SearchSuttasIntent in app dialog
**Status**: Complete

01. [x] Create SearchIntentResults struct for inter-process communication
02. [x] Implement app group UserDefaults to share results between intent and app
03. [x] Add app group entitlements (Debug and Release builds)
04. [x] Update ContentView to detect and display results in sheet dialog
05. [x] Implement Timer polling for app group UserDefaults changes
06. [x] Refactor SearchResultsView to display intent results correctly
07. [x] Update SearchSuttasIntent to store results via app groups
08. [x] Test on device and verify results display in sheet
