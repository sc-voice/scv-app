# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also ~/.claude/CLAUDE.md

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

## Permissions

- you can read any file in project except those in secret/

## Invariant Violation Counter

**TOTAL VIOLATIONS: 1**

## Invariant Violations

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

## Completed Work

### Investigate and fix ColorConsole errors
**Status**: Complete (Build 1.1.363)

01. [x] Identified 27 failing ColorConsoleTests
02. [x] Determined root cause: tests checking for ANSI codes but implementation uses emojis
03. [x] Updated all 27 test assertions to validate emoji output instead of ANSI codes
04. [x] All tests now passing (243/243) with no regressions

### Replace print statements with ColorConsole methods
**Status**: Complete (Build 1.1.357)

01. [x] Add instance variable `let cc = ColorConsole(#file, #function)` to SearchSuttasIntent and Settings
02. [x] Replace 6 print statements with ColorConsole methods (ok1, ok2, bad1, bad2)
03. [x] Add #line parameter to all ColorConsole calls
04. [x] Run make test to verify no regressions

## Backlog

### Fix main actor-isolated property access in SettingsModalController
**Status**: Backlog

01. [ ] Locate SettingsModalController.swift:126 with isPlaying warning
02. [ ] Identify the Sendable closure accessing main actor property
03. [ ] Fix thread safety by ensuring closure runs on main actor
04. [ ] Run make test to verify fix

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

