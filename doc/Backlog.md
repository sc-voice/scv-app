# Backlog

Project backlog items organized by status and priority.

## Fix EbtSeeker LIKE pattern string length assertions
**Status**: Backlog

01. [ ] Fix test expectations in EbtSeekerTests.swift:218-243 (commented out)
    - String count assertions are off by 1
    - "% root %suffer %".count is 16, not 17
    - "% root %of% suffer %".count is 20, not 21
    - "% lemma1 %lemma2%lemma3% lemma4 %".count is 33, not 34
    - Determine if test expectations are wrong or implementation is wrong
    - Update test assertions to match actual string lengths or fix EbtSeeker pattern generation

## Add VoiceOver accessibility labels
**Status**: Complete (labels implemented, testing pending)

01. [x] Add accessibilityLabel to all icon-only buttons (See: SearchCardView.swift:195, CardSidebarView.swift:176/187/130, SuttaHeaderView.swift:71-72, AboutCardView.swift:376/449)
    - [x] Search toolbar button: "a11y.button.search" (SearchCardView:195)
    - [x] Add card button: "a11y.button.add_card" (CardSidebarView:176)
    - [x] Settings button: "a11y.button.settings" (CardSidebarView:187)
    - [x] Delete card button: "a11y.button.delete_card" (CardSidebarView:130)
    - [x] Play/pause button: "a11y.button.play_audio" / "a11y.button.pause_audio" (SuttaHeaderView:71-72)
    - [x] Link buttons in AboutCardView: "a11y.button.external_link" (AboutCardView:376, 449)
    - [ ] Test with VoiceOver enabled on iOS device (post-launch testing)

## Fix accessibility layout adaptation
**Status**: Backlog

01. [ ] Add accessibilityCategory checks to AboutCardView and SettingsView (similar to SearchCardView:122-128)
    - AboutCardView: Stack sections vertically when accessibility sizes active
    - SettingsView: Improve spacing and layout for large text sizes
    - Verify readability in VoiceOver with large text

## Add keyboard accessibility
**Status**: Backlog

01. [ ] Add keyboard shortcuts for common actions (See: SearchCardView, CardSidebarView, AboutCardView)
    - Command+F: Focus search field in SearchCardView
    - Command+N: Add new card
    - Tab order and focus management for all interactive elements
    - Keyboard support for collapsible sections (collapse/expand with Enter/Space)

02. [ ] Remove color-only information conveyance
    - Star ratings in SearchCardView: Add text label or accessibility value
    - Ensure all semantic information is accessible to screen readers

## Investigate phrase search vs keyword search score differences
**Status**: Backlog

01. [ ] Verify whether phrase search scores differ from keyword search scores (See: scv-core/Sources/EbtData.swift:788-815)
    - Current assumption: phrase results use same scores as keyword results
    - Reality: sutta matching phrase may have different scores than keyword-only match
    - Currently performPhraseSearch hardcodes score: 1.0 for all results
    - Need to calculate actual scores for phrase matches or inherit from keyword results
    - Update phraseSearchRootOfSuffering test with actual discovered scores
    - Consider whether phrase matches should score differently than keyword matches

## Mark matched segments in MLDocument with lemmaRegexp
**Status**: Backlog

01. [ ] Use lemmaRegexp() to set matched: true on Segment objects (See: Segment.swift:27)
    - Currently matched field is never set to true anywhere
    - populateSuttaInfo() creates header segments but can't mark matches (no query/method)
    - populateQuotes() has query/method but doesn't update Segment.matched field
    - Determine best place to mark matched segments (in populateQuotes or separate method)
    - Update MLDocument segments to reflect which ones matched the lemma search
    - This enables UI to highlight matched segments in search results

## Redesign Lemmatizer cache for performance
**Status**: Backlog

01. [ ] Profile and redesign lemmatizer caching strategy (See: EbtSeeker.swift:152-194)
    - Current bottleneck: lemmatization takes 192ms for "root of suffering" → "root, of, suffer"
    - SQL query execution only takes 28ms (7x faster than lemmatization)
    - Investigate current lemmatizer cache implementation
    - Evaluate caching strategies: pre-build common queries, use trie-based cache, parallel lemmatization
    - Benchmark different approaches to reduce lemmatization overhead
    - Target: reduce lemmatization time below SQL execution time

## Make EbtData SQL query methods async
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

## AudioStore Phase 2 — StoreAudio (✅ COMPLETE)

**Status**: ✅ VERIFIED COMPLETE — Build 0.2601.12, 2026-01-22

- [x] Implement `storeAudio(text:audioContext:) async throws -> URL`
- [x] Uses proven AVSpeechSynthesizer.write(toBufferCallback:) pattern
- [x] CAF file synthesis with atomic write via GuidStore
- [x] Returns URL when synthesis completes (0.23s-0.82s per segment, verified in tests)
- [x] Error handling: Throws on synthesis timeout or write failures
- [x] Cache optimization: Returns immediately if file already exists
- [x] 4 new tests pass (synthesis, caching, different contexts, edge cases)
- [x] 512 total scv-core tests pass (508 original + 4 new storeAudio)
- [x] Full scv-ui build succeeds

**Key Files**: scv-core/Sources/AudioStore.swift, scv-core/Tests/AudioStoreTests.swift (lines 107-217)

## AudioStore Phase 3 — ClearOrphanedVolumes (Pending)

Implement automatic cleanup when voice/rate/pitch settings change.

1. [ ] Implement `clearOrphanedVolumes(audioContext:) async`
2. [ ] List all volumes in store
3. [ ] Filter by language + hash prefix
4. [ ] Delete volumes with different hash (old audio contexts)
5. [ ] Handle errors silently
6. [ ] Add tests for cleanup on settings change

## AudioStore Phase 4 — SuttaPlayer Integration (Pending)

Replace AVSpeechSynthesizer usage in SuttaPlayer with AudioStore API.

1. [ ] Update SuttaPlayer to use `audioStore.storeAudio()` instead of direct synthesis
2. [ ] Implement prefetch strategy (lazy, lookahead, or prefetch-all)
3. [ ] Use AVAudioPlayer for playback instead of AVSpeechSynthesizer
4. [ ] Test end-to-end playback with synthesized audio
5. [ ] Verify dual AudioContext pattern (docAudioContext + pliAudioContext)
6. [ ] Performance testing: measure latency and memory usage

## AudioStore Phase 5 — M4A Optimization (Future)

Optimize file size with AAC compression (~7x smaller than CAF).

1. [ ] Link AudioToolbox framework for AAC encoding
2. [ ] Implement M4A synthesis path (AVAudioConverter + ExtAudioFile)
3. [ ] Benchmark M4A vs CAF file sizes and synthesis time
4. [ ] Update AudioType.m4a path
5. [ ] Verify M4A playback via AVAudioPlayer
6. [ ] Update tests to verify both CAF and M4A formats
