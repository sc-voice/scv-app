# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

IMPORTANT! READ IMMEDIATELY WITHOUT ASKING PERMISSION: 
  - global CLAUDE.md
  - WORK.md

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

## Permissions

1. Claude can read any file in project except those in local/
  - EXCEPTION: Claude can read any file in project local/ebt-data
  - EXCEPTION: Claude can read any file in project local/bilara-data
  - EXCEPTION: Claude can read any file in project local/build
  - EXCEPTION: Claude can read/write local/*.log
2. Claude can read any file in project except those in secret/

## Code Best Practice

### ColorConsole Logging

ColorConsole (See: scv-core/Sources/ColorConsole.swift) handles output filtering internally via verbosity levels. Do NOT use conditional checks.

**Initialization:**
- Pass verbosity level at init: `let cc = ColorConsole(#file, #function, dbg.Module.level)`
- Use `dbg` constants from codebase (e.g., `dbg.SuttaPlayer.other`)
- Each module/class can have its own verbosity level

**Usage patterns:**
- `ok1()`: End of happy path, just before leaving method. Output if verbosity >= 1
- `bad1()`: End of sad path (error/exception), just before leaving method. Output if verbosity >= 1
- `ok2()`: Anywhere else on happy path (entry, intermediate steps, branches). Output if verbosity >= 2
- `bad2()`: Anywhere else on sad path (non-fatal errors, error diagnostics). Output if verbosity >= 2

**Pattern to AVOID:**
```swift
if dbgSearch > 1 {
  cc.ok2(#line, "message")  // Wrong - redundant conditional
}
```

**Pattern to USE:**
```swift
cc.ok2(#line, "message")  // Correct - ColorConsole checks verbosity internally
```

ColorConsole returns nil if output is filtered, allowing `@discardableResult` to silence unused value warnings.

### Protocol Naming Convention

Protocols use the "I" prefix (Microsoft convention) to make intent explicit at first glance.

**Examples:**
- `ISpeechSynthesizer` (not `SpeechSynthesizer`)
- `ICardManager` (not `CardManager`)

This convention applies to all new protocols in the codebase.

## Claude commands

Always read user Claude.md at beginning of chat or whenever existing chat is cleared.

- rtf means READ THE FILE

## Directory Context (CRITICAL)

Claude must be explicit and intentional about working directory for EVERY command:

1. BEFORE running any command, explicitly determine which directory it must run in
2. Use absolute paths or `-C` flag to run commands from correct directory
3. NEVER assume current working directory is correct
4. Especially critical for: make, git, swift build, swift test, and scripts
5. Examples:
   - `make -C /Users/visakha/dev/scv-app clean-build` (correct)
   - `cd /Users/visakha/dev/scv-app/scv-core && swift test --filter LemmatizerTests` (correct)
   - `swift test` without specifying directory (WRONG - violates this rule)

## Testing

To test build tools:
```bash
make test-tools
```

To test application:
```bash
make test-app
```

**Important:** Tests must run **serially** (not in parallel) because scv-core uses a global mutable localization bundle for testing. The `withLocalizationBundle()` helper in CardTests.swift swaps bundles to test multiple languages, which causes conflicts if tests run in parallel.

To run a specific test:
```bash
cd scv-core && swift test --filter CardTests
```

## Known Issues and Limitations

### Hover effects not working on links in AboutCardView
**Status**: Investigated, no solution found

1. [x] Attempted `.pointerStyle(.pointingHand)` - not available/not working
2. [x] Attempted `NSCursor.pointingHand.push/pop()` with `onHover()` - never triggered
3. [x] Attempted `NSCursor.pointingHand.push/pop()` with `onContinuousHover()` - never triggered
4. [x] Attempted `.defaultHoverEffect(.highlight)` - compiles but no visible effect
5. [x] Research confirmed hover effects should work in Mac Catalyst iPad apps

Links in AboutCardView (See: scv-ui/Sources/scvUI/AboutCardView.swift) are colored (linkColor) and underlined but do not show hover effects. The feature is not essential since the links are already visually distinct.

## Backlog

### Fix EbtSeeker LIKE pattern string length assertions
**Status**: Backlog

01. [ ] Fix test expectations in EbtSeekerTests.swift:218-243 (commented out)
    - String count assertions are off by 1
    - "% root %suffer %".count is 16, not 17
    - "% root %of% suffer %".count is 20, not 21
    - "% lemma1 %lemma2%lemma3% lemma4 %".count is 33, not 34
    - Determine if test expectations are wrong or implementation is wrong
    - Update test assertions to match actual string lengths or fix EbtSeeker pattern generation

### Add VoiceOver accessibility labels
**Status**: Complete (labels implemented, testing pending)

01. [x] Add accessibilityLabel to all icon-only buttons (See: SearchCardView.swift:195, CardSidebarView.swift:176/187/130, SuttaHeaderView.swift:71-72, AboutCardView.swift:376/449)
    - [x] Search toolbar button: "a11y.button.search" (SearchCardView:195)
    - [x] Add card button: "a11y.button.add_card" (CardSidebarView:176)
    - [x] Settings button: "a11y.button.settings" (CardSidebarView:187)
    - [x] Delete card button: "a11y.button.delete_card" (CardSidebarView:130)
    - [x] Play/pause button: "a11y.button.play_audio" / "a11y.button.pause_audio" (SuttaHeaderView:71-72)
    - [x] Link buttons in AboutCardView: "a11y.button.external_link" (AboutCardView:376, 449)
    - [ ] Test with VoiceOver enabled on iOS device (post-launch testing)

### Fix accessibility layout adaptation
**Status**: Backlog

01. [ ] Add accessibilityCategory checks to AboutCardView and SettingsView (similar to SearchCardView:122-128)
    - AboutCardView: Stack sections vertically when accessibility sizes active
    - SettingsView: Improve spacing and layout for large text sizes
    - Verify readability in VoiceOver with large text

### Add keyboard accessibility
**Status**: Backlog

01. [ ] Add keyboard shortcuts for common actions (See: SearchCardView, CardSidebarView, AboutCardView)
    - Command+F: Focus search field in SearchCardView
    - Command+N: Add new card
    - Tab order and focus management for all interactive elements
    - Keyboard support for collapsible sections (collapse/expand with Enter/Space)

02. [ ] Remove color-only information conveyance
    - Star ratings in SearchCardView: Add text label or accessibility value
    - Ensure all semantic information is accessible to screen readers

### Investigate phrase search vs keyword search score differences
**Status**: Backlog

01. [ ] Verify whether phrase search scores differ from keyword search scores (See: scv-core/Sources/EbtData.swift:788-815)
    - Current assumption: phrase results use same scores as keyword results
    - Reality: sutta matching phrase may have different scores than keyword-only match
    - Currently performPhraseSearch hardcodes score: 1.0 for all results
    - Need to calculate actual scores for phrase matches or inherit from keyword results
    - Update phraseSearchRootOfSuffering test with actual discovered scores
    - Consider whether phrase matches should score differently than keyword matches

### Mark matched segments in MLDocument with lemmaRegexp
**Status**: Backlog

01. [ ] Use lemmaRegexp() to set matched: true on Segment objects (See: Segment.swift:27)
    - Currently matched field is never set to true anywhere
    - populateSuttaInfo() creates header segments but can't mark matches (no query/method)
    - populateQuotes() has query/method but doesn't update Segment.matched field
    - Determine best place to mark matched segments (in populateQuotes or separate method)
    - Update MLDocument segments to reflect which ones matched the lemma search
    - This enables UI to highlight matched segments in search results

### Redesign Lemmatizer cache for performance
**Status**: Backlog

01. [ ] Profile and redesign lemmatizer caching strategy (See: EbtSeeker.swift:152-194)
    - Current bottleneck: lemmatization takes 192ms for "root of suffering" → "root, of, suffer"
    - SQL query execution only takes 28ms (7x faster than lemmatization)
    - Investigate current lemmatizer cache implementation
    - Evaluate caching strategies: pre-build common queries, use trie-based cache, parallel lemmatization
    - Benchmark different approaches to reduce lemmatization overhead
    - Target: reduce lemmatization time below SQL execution time

### Make EbtData SQL query methods async
**Status**: In Progress (Partial)

01. [x] Create static async wrapper for getMLDocument() - delegates to instance method
    - See: scv-core/Sources/EbtData.swift:136-143
    - CardManager uses async version (line 340)

02. [ ] Convert instance methods to fully async (See: scv-core/Sources/EbtData.swift:594-1180)
    - Current: `getMLDocument()`, `getDocument()`, `availableAuthors()`, `suttaUidsForAuthor()` are sync
    - Problem: Sync database queries block MainActor when called from UI code
    - Solution: Make instance methods async to avoid UI freezing
    - Status of metadata(): Already removed (commit be81534), replaced with getMetaprop()
    - getMetaprop() has both sync (line 1094) and async (via EbtDb wrapper, line 1500) versions
    - Need to complete async conversion of remaining methods
    - Update all internal callsites to use await
    - Keep actor serialization to maintain thread safety

