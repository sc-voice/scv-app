# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also ~/.claude/CLAUDE.md

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

## Permissions

- you can read any file in project except those in secret/

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
**Status**: Planning phase

01. [ ] Design theme system (light, dark, custom color schemes)

02. [ ] Implement theme provider/context for SwiftUI app

03. [ ] Apply themes to existing views (ContentView, SettingsView, SuttaView)

04. [ ] Add theme selection to Settings

05. [ ] Test theme switching and persistence

### Create app privacy label
**Status**: Backlog

01. [ ] Identify data categories app collects (search queries, viewing history, etc.)

02. [ ] Map data to Apple privacy categories and purposes

03. [ ] Configure privacy manifest in Xcode

04. [ ] Add app privacy label to App Store Connect

05. [ ] Test privacy label accuracy against actual app behavior

### Refactor Segment struct for language-aware text
**Status**: Completed

01. [x] Refactor Segment properties: doc/ref/pli (optional) instead of en/pli/ref
02. [x] Add CodingKeys for all ScvLanguage codes
03. [x] Update Segment decoder with docLang mapping
04. [x] Fix displayText property
05. [x] Fix 15+ test compilation errors (Segment() calls with en: parameter)
06. [x] Update MLDocument decoder to transform segMap keys
07. [x] Replace segment.en with segment.doc in:
    - SearchResponseTests.swift (15+ occurrences)
    - CardTests.swift (2+ occurrences)
    - SuttaView.swift (3 occurrences)
    - SuttaPlayer.swift (3 occurrences)
08. [x] Run make test to verify all tests pass
09. [x] Commit changes with approval

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

### Completed
- [x] Create scv-ui Swift package with scv-core dependency and re-export
- [x] Create ScvDemo iOS app that loads scv-ui package
- [x] Implement SuttaCentralId.swift in scv-core based on scv-esm/src/sutta-central-id.mjs
- [x] Create SuttaView in ScvDemo that displays sn42.11
  - Added segments() method to MLDocument for SuttaCentralId-ordered display
  - Created SuttaView.swift component displaying title and segments
  - Updated ScvDemo to display SuttaView with sn42.11
  - Made MLDocument, Segment properties public for cross-package access
  - Made segments() method public
  - Added three unit tests verifying correct ordering and content preservation
  - ScvDemo builds successfully
- [x] Update SuttaView to display only language-matched segment text
  - Implement getSegmentText() method that matches segment text to docLang
  - Display segments with fallback to English if language property is empty
  - Add blue scid prefix to each segment row
  - Updated main ScvDemo app to display SuttaView (in scv-demo/Sources/ScvDemo/ContentView.swift)
- date respond with "Hello today is {datetime}"
