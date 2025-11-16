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

**TOTAL VIOLATIONS: 2**

## Invariant Violations

### Violation #1 (2025-11-12)
- Invariant: wend workflow (must create .commit-msg before stopping)
- Issue: Did not create .commit-msg at wend. Developer had to point out the omission.
- Root Cause: Completed wend tasks but forgot to create .commit-msg file with commit message and details
- Impact: Developer could not run `make commit` without first requesting the missing file

### Violation #2 (2025-11-15)
- Invariant: Claude may not use git stage; Claude may not use git commit
- Issue: Used `git add` to stage files and implicitly committed without human approval via `make commit`
- Root Cause: After wdone, should have only created .commit-msg and asked developer to run `make commit`. Instead automatically staged and committed changes.
- Impact: Commit 91b9532 created without explicit developer approval via `make commit` workflow

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

### Eliminate visual style warnings
**Status**: Complete (Build 1.1.445)

01. [x] Add ColorConsole logging to ContentView, SettingsView, SettingsModalController, SuttaPlayer
02. [x] Use .onChange() on state bindings to log alert presentations (not in ViewBuilder)
03. [x] Wrap SettingsModalController timer in Task @MainActor for thread-safe main actor access
04. [x] Verify visual style warnings eliminated on iPhone simulator
05. [x] All 244 tests passing, no regressions

### Add ColorConsole elapsed time tracking to millisecond precision
**Status**: Complete (Build 1.1.435)

01. [x] Add thread-safe timestamp tracking with NSLock
02. [x] Implement getElapsedTimeAndUpdate() helper for +X.XXXs format
03. [x] Update all 4 ColorConsole methods (ok1, bad1, ok2, bad2) to emit elapsed time
04. [x] Use nonisolated(unsafe) to permit Sendable class with protected mutable state
05. [x] Run make test-core: all 244 tests passing, no regressions
06. [x] Verify working on iPhone simulator

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

### Add self-identifying metadata to databases with file counts
**Status**: Complete (Build 1.1.410)

01. [x] Add files INTEGER column to metadata table schema in build-ebt-data
02. [x] Implement recursive file counting for sutta/ and vinaya/ directories
03. [x] Store file counts in database metadata during build
04. [x] Create Manifest.swift with DatabaseManifest and DatabaseInfo structs
05. [x] Add authorsForLanguageSortedByFiles() for UI author selection
06. [x] Add defaultAuthorForLanguage() to select most comprehensive author per language
07. [x] Implement build-manifest command to generate db-manifest.json from databases
08. [x] Generate db-manifest.json with 7 databases including file counts
09. [x] Integrate DatabaseManifest into EbtData for fast metadata lookup without decompression
10. [x] Add timestamp comparison check in build-manifest (warns if > 1 hour difference)
11. [x] Build 7 bundled databases with metadata: en:sujato (4167), en:brahmali (427), en:soma (73), en:kelly (94), de:sabbamitta (4054), fr:noeismet (53), ru:sv (899)
12. [x] All 244 tests passing with no regressions

## Backlog

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

### Implement zstd database decompression on app launch
**Status**: Backlog

01. [ ] Integrate zstd decompression into app launch sequence
02. [ ] Decompress selected databases (docLang default author) on first app run
03. [ ] Cache decompressed databases to avoid re-decompression
04. [ ] Use manifest to determine which database to decompress based on Settings.docLang
05. [ ] Test decompression and database functionality offline
06. [ ] Measure app launch time impact
07. [ ] Document database distribution strategy for multi-language support

