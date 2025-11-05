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
**Status**: Backlog

01. [ ] Parse HTML tags in segment text (currently only extracts matched spans)
02. [ ] Implement proper HTML rendering for semantic markup
03. [ ] Style HTML elements according to theme

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
