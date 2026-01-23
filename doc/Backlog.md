# Backlog

Project backlog items organized by release priority.

---

## Current Release

Focus on background audio support and core stability. AVSpeechSynthesizer cannot synthesize when app backgrounded—solution is pre-cache via "Create Background Audio" workflow. See: `doc/BackgroundAudio.md`

### Background Audio Critical Path

**Design constraint**: Restrict synthesis to current suttacard while sutta is playing. Synthesis tied to playback speed (1x playback = 1x synthesis). After linear playback completes, all segments cached.

**Workflow**:
1. User selects sutta from search → load MLDocument (one-time, sync call)
2. User plays sutta → SuttaPlayer.playSegmentAt() with lookahead prefetch (N+1, N+2 while N plays)
3. Playback completes → all segments cached with current AudioContext hash
4. Mark sutta "background ready" (implicit: if all segments cached, can background)
5. Later: user backgrounds app → play from cache (no synthesis needed)

1. **AudioStore Phase 3 — ClearOrphanedVolumes** (✅ COMPLETE — 2026-01-23, committed)
   - [x] Implement automatic cleanup when voice/rate/pitch settings change
   - [x] List all volumes in store, filter by language + hash prefix, delete old contexts
   - [x] Handle errors silently (errors logged at bad2 level, don't throw)
   - [x] Add tests for cleanup on settings change (6 tests, all passing, 0.836s total)
   - [x] Comprehensive ColorConsole logging at ok1/ok2/bad1/bad2 levels
   - [x] CompactionStatus struct reporting volumesScanned, volumesDeleted, volumesKept, elapsedSeconds

2. **AudioStore Phase 4 — CachedSynthesizer Implementation** (Pending)
   - Create CachedSynthesizer class implementing ISpeechSynthesizer
   - Wraps AudioStore.storeAudio() for cached playback
   - Emits identical IPlaybackDelegate events as SpeechSynthesizerImpl
   - Implements AVAudioPlayer playback with delegate callbacks
   - Implement lookahead prefetch (N+1, N+2 while N plays)
   - Add tests verifying all 4 IPlaybackDelegate events
   - Test end-to-end: SuttaPlayer with injected CachedSynthesizer
   - Performance testing vs SpeechSynthesizerImpl

3. **AudioStore Phase 5 — M4A Optimization** (Pending)
   - Link AudioToolbox framework for AAC encoding
   - Implement M4A synthesis path (AVAudioConverter + ExtAudioFile)
   - ~7x compression vs CAF (important for large suttas: 2.2GB → 300MB)
   - Verify playback via AVAudioPlayer

4. **"Create Background Audio" Feature** (New, not yet backlogged)
   - Mark sutta as "background ready" after playback completes
   - Storage: Card model field `backgroundAudioContextHash: String?`
   - Invalidation: hash changes when voice/rate/pitch settings change
   - UI: Visual indicator on sutta card showing audio is cached
   - Verification: check all segments exist with correct hash before marking ready

---

## Next Release

Accessibility improvements, search refinements, and infrastructure improvements.

### Accessibility

1. **Test VoiceOver accessibility labels** (Implementation done, testing pending)
   - [x] All accessibility labels added to UI buttons (SearchCardView, CardSidebarView, SuttaHeaderView, AboutCardView)
   - [ ] Test with VoiceOver enabled on iOS device
   - Note: Apple does not require VoiceOver support, but good UX practice

2. **Fix accessibility layout adaptation** (Backlog)
   - Add accessibilityCategory checks to AboutCardView and SettingsView
   - Stack sections vertically when accessibility sizes active
   - Improve spacing for large text sizes

3. **Add keyboard accessibility** (Backlog)
   - Add keyboard shortcuts (Command+F, Command+N)
   - Tab order and focus management
   - Keyboard support for collapsible sections
   - Remove color-only information conveyance

### Search & Indexing

4. **Mark matched segments in MLDocument with lemmaRegexp** (Backlog)
   - Set matched: true on Segment objects when lemma matches
   - Enable UI to highlight matched segments in search results

5. **Investigate phrase search vs keyword search score differences** (Backlog)
   - Verify if phrase scores differ from keyword scores
   - Currently performPhraseSearch hardcodes score: 1.0
   - Calculate actual scores or inherit from keyword results

### Infrastructure

6. **Make EbtData SQL query methods async** (In Progress — Partial)
   - [x] Static async wrapper for getMLDocument()
   - [ ] Convert instance methods to fully async (getMLDocument, getDocument, availableAuthors, suttaUidsForAuthor)
   - Improves general MainActor responsiveness
   - Update all internal callsites to use await
   - Keep actor serialization for thread safety
   - Note: Not critical for current release (background audio synthesis tied to playback, not separate background task)

---

## Future Release

Performance optimizations and infrastructure improvements.

### Performance

1. **Redesign Lemmatizer cache for performance** (Backlog)
   - Current bottleneck: lemmatization takes 192ms (vs 28ms SQL)
   - Evaluate: pre-build common queries, trie-based cache, parallel lemmatization
   - Target: reduce lemmatization below SQL execution time

2. **Fix EbtSeeker LIKE pattern string length assertions** (Backlog)
   - Test expectations in EbtSeekerTests.swift:218-243 are off by 1
   - Determine if test or implementation wrong
   - Update assertions or fix pattern generation

---

**Total backlog items**:
- Current Release: 3 items (Phase 3 complete)
- Next Release: 6 items
- Future Release: 2 items
