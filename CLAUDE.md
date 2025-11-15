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

### Research zstd for database compression in app
**Status**: Complete (Build 1.1.372)

01. [x] Review ZstdDecompression.swift implementation
02. [x] Review changes to Package.swift (dependency added)
03. [x] Run zstd integration tests to validate decompression works
04. [x] Review compressed database files (size, decompression time)
05. [x] Document findings: performance, integration approach, bundle size impact, viability assessment
06. [x] Run make test-all and verified no regressions

### Investigate zstd warnings in test-all.log
**Status**: Complete (Build 1.1.381)

01. [x] Investigated zstd configuration macro warnings (lines 30-36 in test-all.log)
02. [x] Researched Facebook zstd recommendations and Swift Package Manager integration
03. [x] Removed ineffective cSettings macro definitions from Package.swift
04. [x] Removed unused test-db.db.zst file from scv-core/Tests/Data
05. [x] Added defaultLocalization: "en" to Package.swift for localized resources
06. [x] Changed resource declarations from .copy() to .process() in both targets
07. [x] Identified root cause of "Found unhandled resource" warnings (Resources/ outside target paths)
08. [x] Added backlog item to reorganize Resources directory structure
09. [x] Verified all 244 tests pass with no zstd configuration macro warnings

### Reorganize scv-core Resources to eliminate SPM warnings
**Status**: Complete (Build 1.1.395)

01. [x] Move Resources/ directory from scv-core/Resources/ to scv-core/Sources/Resources/
02. [x] Update Package.swift resource paths from ../Resources/ to Resources/
03. [x] Update any code that references Bundle.module resources
04. [x] Run make test-all to verify resources load correctly
05. [x] Verify "Found unhandled resource" warnings are eliminated

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

### Add self-identifying metadata to databases with SHA256 Dictionary ID
**Status**: Backlog

01. [ ] Add metadata header to databases during build-ebt-data (language, locale, COMMIT#)
02. [ ] Compute SHA256 hash of metadata string (e.g., "en/sujato-COMMIT#")
03. [ ] Store hash as zstd Dictionary ID during compression
04. [ ] Update ZstdDecompression to validate Dictionary ID on decompression
05. [ ] Log or report database source/version on successful decompression
06. [ ] Test decompression with multiple database versions

### Implement zstd database decompression on app launch
**Status**: Backlog

01. [ ] Integrate zstd decompression into app launch sequence
02. [ ] Decompress databases (de:sabbamitta, en:sujato, fr:noeismet) on first app run
03. [ ] Cache decompressed databases to avoid re-decompression
04. [ ] Test decompression and database functionality offline
05. [ ] Measure app launch time impact
06. [ ] Document database distribution strategy for multi-language support

