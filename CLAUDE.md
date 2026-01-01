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

- ColorConsole logging: See scv-core/Sources/ColorConsole.swift for ok1/ok2/bad1/bad2 usage patterns

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

Run comprehesive tests with:
```bash
make test-all
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

### Recreate Settings serialization fixtures
**Status**: Backlog

01. [ ] Regenerate Settings v1 serialization fixtures before app store submittal (See: scripts/generate-fixtures.swift, scv-core/Tests/Fixtures/)
    - Settings serialization format changed: docAuthor/docSpeech now stored in docLangSettings dictionary
    - Disabled tests: SerializationV1Tests (settingsV1MinimalDeserialization, settingsV1WithVoiceDeserialization, settingsV1RoundTrip)
    - Disabled test: SettingsTests.docAuthorEncodedAndDecoded
    - Run: `swift scripts/generate-fixtures.swift` to regenerate fixtures with new format
    - Re-enable and verify all serialization tests pass
    - Verify fixture JSON structure reflects new docLangSettings[language]: LangSettings format

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

### Create app privacy label
**Status**: In Progress

01. [x] Identify data categories app collects (search queries, viewing history, etc.)

02. [x] Map data to Apple privacy categories and purposes

03. [x] Configure privacy manifest in Xcode (See: scv-ios/scv-ios/PrivacyInfo.xcprivacy)

04. [ ] Add app privacy label to App Store Connect (manual step)

05. [ ] Test privacy label accuracy against actual app behavior

### Add VoiceOver accessibility labels
**Status**: Backlog

01. [ ] Add accessibilityLabel to all icon-only buttons (See: SearchCardView.swift:511-523, CardSidebarView.swift:98-107, SuttaHeaderView.swift:62-74, AboutCardView.swift:333-345,417-425)
    - Search toolbar button: "Search"
    - Add card button: "Add new search card"
    - Settings button: "Open settings"
    - Delete card button: "Delete card"
    - Play/pause button: "Play audio" / "Pause audio"
    - Link buttons in AboutCardView: descriptive labels for external links
    - Test with VoiceOver enabled on iOS device

### Add Reduce Motion support
**Status**: Backlog

01. [ ] Wrap all animations with @Environment(\.accessibilityReduceMotion) check (See: SearchCardView.swift:173-176,581-584; CardSidebarView.swift:193-195,273-280; SuttaCardView.swift:70-82,87-98)
    - SearchCardView: 5-second fade animation
    - CardSidebarView: 30-second opacity fade, 2-second easing animations
    - SuttaCardView: 0.8-second layout animations
    - Test with reduced motion enabled in Accessibility settings

### Fix accessibility layout adaptation
**Status**: Backlog

01. [ ] Add accessibilityCategory checks to AboutCardView and SettingsView (similar to SearchCardView:122-128)
    - AboutCardView: Stack sections vertically when accessibility sizes active
    - SettingsView: Improve spacing and layout for large text sizes
    - Verify readability in VoiceOver with large text

### Ensure minimum touch target sizes
**Status**: Backlog

01. [ ] Verify all interactive elements meet 44pt minimum (See: SearchCardView.swift:496-502, CardSidebarView.swift:98-107,147-164, SegmentView.swift:70-85)
    - Icon-only buttons: explicitly set .frame(minHeight: 44, minWidth: 44)
    - Slider components: verify system defaults meet 44pt
    - Test on iPhone with visual inspection
    - Consider increasing target sizes on iPad for easier touch

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

### Create accessibility declaration
**Status**: Backlog

01. [ ] Create accessibility label in App Store Connect
    - Declare supported accessibility features (after implementing above fixes)
    - Add audio descriptions if applicable
    - Document any accessibility limitations
    - Verify accuracy against actual app behavior

02. [ ] Test on devices with accessibility features enabled
    - Test VoiceOver on iOS device
    - Test with maximum Dynamic Type size
    - Test with reduced motion enabled
    - Test keyboard navigation without touch

### Fix Sendability warnings in CardManager and MockCardManager
**Status**: Backlog

01. [ ] Fix CardManager.swift:98 - 'self' with non-Sendable type in @Sendable closure
02. [ ] Fix CardManager.swift:100 - unused 'self' variable in set closure
03. [ ] Fix MockCardManager Sendability warnings in CardSidebarView:216, 219
    - Requires architectural changes to CardManager and/or MockCardManager
    - May need to make classes Sendable or use different binding strategy

### Investigate phrase search vs keyword search score differences
**Status**: Backlog

01. [ ] Verify whether phrase search scores differ from keyword search scores (See: scv-core/Sources/EbtData.swift:788-815)
    - Current assumption: phrase results use same scores as keyword results
    - Reality: sutta matching phrase may have different scores than keyword-only match
    - Currently performPhraseSearch hardcodes score: 1.0 for all results
    - Need to calculate actual scores for phrase matches or inherit from keyword results
    - Update phraseSearchRootOfSuffering test with actual discovered scores
    - Consider whether phrase matches should score differently than keyword matches

### Refactor MLDocument.segments() to return array instead of key-value pairs
**Status**: Backlog

01. [ ] Change MLDocument.segments() return type from array of tuples to array of Segments
    - Current: returns `[(key: String, value: Segment)]` duplicating segment.scid
    - Proposed: returns `[Segment]` since Segment already contains scid
    - Update all callsites in SuttaCardView and elsewhere
    - Simplifies iteration and eliminates tuple destructuring

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

### Create debug logging macro for conditional cc.ok calls
**Status**: Backlog

01. [ ] Create Swift macro to replace verbose if-statements for debug logging (See: scv-core/Sources/EbtSeeker.swift:158-189)
    - Current: 3 lines per conditional debug log (`if dbgSearch > 1 { cc.ok2(...) }`)
    - Goal: 1-line macro like `@debugLog(dbgSearch > 1) { cc.ok2(...) }`
    - Define macro in scv-core/Sources
    - Apply to all debug logging calls in EbtSeeker and EbtData
    - Reduces boilerplate while maintaining intent

### Make EbtData SQL query methods async
**Status**: Backlog

01. [ ] Convert synchronous EbtData SQL methods to async (See: scv-core/Sources/EbtData.swift:328-1110)
    - Current: Methods like `getMLDocument()`, `getDocument()`, `metadata()` are sync
    - Problem: Sync database queries block MainActor when called from UI code
    - Solution: Make all SQL query methods async to avoid UI freezing
    - Priority methods: getMLDocument, getDocument, metadata, availableAuthors, suttaUidsForAuthor
    - Update all callsites to use await
    - Keep actor serialization to maintain thread safety

