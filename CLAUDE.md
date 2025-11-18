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

## Code Best Practice

- ColorConsole logging: See scv-core/Sources/ColorConsole.swift for ok1/ok2/bad1/bad2 usage patterns

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

### Move SuttaView to scv-demo-ios as DemoSuttaView
**Status**: Complete (Build 1.1.447)

01. [x] Read SuttaView.swift to identify all dependencies
02. [x] Move SuttaView.swift from scv-ui to scv-demo-ios
03. [x] Rename struct SuttaView → DemoSuttaView
04. [x] Update ContentView.swift to use DemoSuttaView
05. [x] Remove MockResponseView from scv-ui/Package.swift
06. [x] Copy MockResponseView to scv-demo-ios and update to use DemoSuttaView
07. [x] Delete redundant MockResponseView directory and ScvDemo.swift
08. [x] Add missing import scvUI to DemoSuttaView.swift
09. [x] Verify all 244 tests pass with no regressions

## Backlog

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

### Consolidate iOS/macOS platform abstraction in scv-ui
**Status**: Backlog

01. [ ] Identify all platform-specific code patterns
    - URLOpener abstraction (already exists)
    - IdleTimerManager abstraction (created)
    - Alert handling (UIAlertController vs NSAlert)
    - Other iOS/macOS conditionals

02. [ ] Create unified Platform or Compatibility module
    - Combine IdleTimerManager, AlertManager, etc.
    - Single entry point for platform differences
    - Clear documentation for each abstraction

03. [ ] Refactor existing code to use unified module
    - Update SuttaPlayer to use unified module
    - Update AppController alert handling
    - Remove scattered #if os() conditionals

04. [ ] Add tests for platform abstractions
    - Verify no-ops work on macOS
    - Verify functionality works on iOS

### Create app privacy label
**Status**: Backlog

01. [ ] Identify data categories app collects (search queries, viewing history, etc.)

02. [ ] Map data to Apple privacy categories and purposes

03. [ ] Configure privacy manifest in Xcode

04. [ ] Add app privacy label to App Store Connect

05. [ ] Test privacy label accuracy against actual app behavior

### CardSidebarView Implementation
**Status**: Backlog

01. [ ] Clarify CardSidebarView visual behavior
    - How should selected card be indicated? (highlight, checkmark, background color)
    - How does delete work? (swipe, button, confirmation dialog)
    - Auto-select newly created card?

02. [ ] Implement CardSidebarView in scv-ui (See: scv-ui/Sources/scvUI/CardSidebarView.swift)
    - Already drafted: List with card names, icons, search query preview
    - Take CardManager as @Bindable dependency
    - Show selected state with proper visual indicator
    - Add button to create new SearchCard
    - Delete button/swipe for removal

03. [ ] Add CardSidebarView tests in scv-ui test target
    - Test card selection updates CardManager.selectedCardId
    - Test add card creates new SearchCard
    - Test delete card removes from list

04. [ ] Create ContentView with NavigationSplitView
    - Sidebar: CardSidebarView
    - Detail: Conditional view based on selected card type

05. [ ] Create scv-ios app (Xcode project)
    - Initialize SwiftData ModelContainer
    - Create CardManager with modelContext
    - Set up AppController for URL scheme handling
    - Root view: ContentView with NavigationSplitView

### Add WebView wrapper for selected segment
**Status**: Backlog

01. [ ] Design WebView integration for full HTML rendering of selected segments
02. [ ] Create WebView wrapper component
03. [ ] Handle navigation between segments in WebView
04. [ ] Style WebView content according to theme
05. [ ] Test WebView interaction and rendering

### AppRootView Implementation in scv-ui
**Status**: Backlog

01. [ ] Design AppRootView structure
    - NavigationSplitView with CardSidebarView on sidebar
    - Conditional detail view based on selected card type
    - Handle empty state (no cards selected)

02. [ ] Implement AppRootView in scv-ui
    - Take CardManager as generic dependency
    - Dispatch to appropriate detail view based on card.cardType
    - Route SearchCard to SearchCardView (when implemented)
    - Route SuttaCard to SuttaCardView (if applicable)
    - Pass card data and theme provider to detail views

03. [ ] Add AppRootView tests
    - Test NavigationSplitView layout on iOS (responsive)
    - Test NavigationSplitView layout on macOS (split view)
    - Test detail view changes when selectedCardId changes

04. [ ] Integrate AppRootView into scv-ios and scv-mac apps
    - scv-ios/App.swift uses AppRootView
    - scv-mac/App.swift uses AppRootView

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
