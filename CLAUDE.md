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

### Create app privacy label
**Status**: Backlog

01. [ ] Identify data categories app collects (search queries, viewing history, etc.)

02. [ ] Map data to Apple privacy categories and purposes

03. [ ] Configure privacy manifest in Xcode

04. [ ] Add app privacy label to App Store Connect

05. [ ] Test privacy label accuracy against actual app behavior

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

