# Background Audio Playback

## Overview

Supporting background audio playback (app backgrounded, lock screen controls, remote commands) requires a fundamental architectural shift away from on-demand synthesis toward cached audio files.

## The Core Constraint

**Simple fact**: AVSpeechSynthesizer does not work when app is backgrounded. Synthesis must complete in foreground only.

**Web research findings** (See: WebSearch results for "AVSpeechSynthesizer background playback issues"):
- AVSpeechSynthesizer stops working when app enters background, even with audio background modes enabled
- Workarounds exist (usesApplicationAudioSession property, audio session ducking) but don't enable background synthesis
- No way to continue real-time synthesis in background

## Architectural Gap

**Current design**: Segment-by-segment synthesis during playback
```
play() → synthesize segment 1 → play it → didFinish
  → synthesize segment 2 → chain continues
```

**Background requirement**: Entire sutta must be cached before app backgrounding
```
play() → all segments synthesized + cached → app backgrounds → play from cache
```

**Implication**: Cannot synthesize incrementally during playback if user will background app. Audio for entire sutta required upfront.

## UX Impact

Upfront synthesis cost is unknown (TBD).

If sutta has 100+ segments:
- **Measured synthesis time**: 230-610ms per segment (see test results below)
- For DN33 (1,167 segments): 4.5-15 minutes depending on voice
- User experience options:
  1. Block UI (unacceptable - would freeze app for 12+ minutes)
  2. **Non-blocking synthesis with progress bar (REQUIRED)**
  3. Resume capability for interrupted synthesis

## Proposed Solution

**"Create Background Audio" workflow**:

1. User selects menu item on sutta card
2. Background process: Synthesize all segments sequentially, cache audio files
3. UI shows progress: "Preparing background audio... 45/100 segments"
4. Completion: Mark sutta with AudioContext hash indicating all audio cached
5. Result: Sutta now playable in background

**Benefits**:
- User explicitly opts-in (no surprise latency)
- Foreground playback still fast (can still synthesize on-demand during playback)
- Background playback works for marked suttas
- Song-like usage (repeated plays) benefits from cached audio

## Open Questions

### Storage and State

1. **Where is "background audio ready" state stored?**
   - Card model field? (e.g., `backgroundAudioContextHash: String?`)
   - MLDocument?
   - Separate metadata file?

2. **What invalidates the state?**
   - User changes voice/rate/pitch → AudioContext hash changes → state stale
   - Should we invalidate automatically or prompt user to re-synthesize?
   - How to handle mismatches between stored hash and current settings?

3. **File lifecycle**:
   - Where are audio files stored? (FileManager cache directory?)
   - What happens if OS/user deletes files?
   - Should we re-synthesize on-demand if files missing?

### Audio File Playback

1. **SuttaPlayer architecture**:
   - Should SuttaPlayer play cached audio directly (AVAudioPlayer/AVPlayer)?
   - How to switch transparently between AVSpeechSynthesizer (foreground) and file playback (background)?
   - Different delegate patterns and state tracking required

2. **Segment chaining**:
   - Current: AVSpeechSynthesizerDelegate callbacks chain segments
   - File playback: Duration-based timing, position tracking instead
   - How to handle user seeking/jumping between segments?

3. **Lock screen integration**:
   - Now Playing info needs sutta title, author, current segment
   - Remote commands (play/pause, next/previous) handled by AVAudioPlayer
   - Requires different control flow than current architecture

### Performance and UX

1. **Synthesis timing (MEASURED - See: scv-core/Tests/AudioStoreTests.swift)**

   **Per-segment timing (synthesis + write):**
   - Default English (en-US): 290ms/segment
   - Sangeeta (en-IN, enhanced): 230ms/segment
   - Sandy (de-DE, eloquence): 510ms/segment
   - Petra Premium (de-DE, premium): 610ms/segment

   **Estimated time for DN33 (1,167 segments):**
   - Best case (Sangeeta): ~4.5 minutes
   - Average (mixed voices): ~8-10 minutes
   - Worst case (Petra Premium): ~12-15 minutes

   **Conclusion**: Background synthesis is MANDATORY. Foreground synthesis would freeze UI for 12+ minutes. Per-sutta caching justifies complexity.

2. **Progress UI** (REQUIRED):
   - **MUST show** segment count and ETA (e.g., "523/1167 segments, ~6 minutes remaining")
   - **MUST allow** cancellation (user needs escape from 12-minute operation)
   - **MUST support** resume from interrupted synthesis (user will background app during cache)

3. **First-play experience**:
   - New sutta: must choose foreground synthesis (loses background) or wait for background cache?
   - Or: allow foreground synthesis but disable backgrounding until "Create Background Audio" done?

## Implementation Progress

**Phase 3 - ClearOrphanedVolumes (✅ COMPLETE — 2026-01-23)**
- [x] Automatic cleanup when voice/rate/pitch settings change
- [x] CompactionStatus struct with metrics (volumesScanned, volumesDeleted, volumesKept, elapsedSeconds)
- [x] compactContextVolumes(context:) async method
- [x] Language + hash prefix filtering (pattern: `{lang}-{hashPrefix7}`)
- [x] Silent error handling (errors logged, don't throw)
- [x] 6 comprehensive tests all passing
- [x] See: AudioStore.md Phase 3 section for implementation details

## Dual-Format Playback Strategy (2026-01-25)

### Problem: Balancing Responsiveness vs Storage

Current approach (CAF format):
- ✅ Fast synthesis (immediate playback)
- ❌ Poor compression (~12.5GB for full corpus)
- ❌ Blocks background playback synthesis

Proposed M4A optimization:
- ✅ 90% better compression (~1.3GB for full corpus)
- ❌ 75ms conversion latency (unacceptable if blocking playback)

**Solution**: Separate concerns into two-stage pipeline

### Two-Stage Synthesis Architecture

**Stage 1 (Immediate)**: CAF synthesis for playback
```
user plays sutta
  → AudioStore.storeAudio() synthesizes to CAF
  → returns immediately (~0.23s-0.82s per segment)
  → SuttaPlayer plays from CAF file
  → user hears audio promptly
```

**Stage 2 (Background, optional)**: M4A compaction for storage
```
Background task (when CPU free, WiFi available, or user explicitly requests)
  → M4A Compactor reads existing CAF files
  → converts to M4A (AVAudioConverter, 0.075s per segment)
  → stores alongside CAF
  → optional: can delete CAF to save space after M4A verified
```

### Playback Strategy

**SuttaPlayer** can choose format based on context:
```swift
// When playing (immediate feedback needed)
if let cafUrl = audioStore.audioUrl(text, audioContext) {
  play(cafUrl)  // Fast, already cached or synthesized
}

// When available and storage is concern
if let m4aUrl = audioStore.compactedUrl(text, audioContext) {
  play(m4aUrl)  // Smaller file
}

// During background preparation
Task {
  for segment in sutta.segments {
    _ = await audioStore.storeAudio(text, audioContext)  // CAF
    // Background later: await compactor.compactToM4A(segment)
  }
}
```

### Advantages of This Approach

1. **Avoids playback latency** — 75ms M4A conversion doesn't block listening
2. **Backwards compatible** — CAF synthesis continues working
3. **Gradual adoption** — M4A compaction optional/deferred
4. **User control** — Settings → Storage → "Compress audio to M4A"
5. **Storage optimization** — Only compact when beneficial (large suttas)
6. **Background synthesis workflow** — CAF generation can pre-cache entire suttas

### Implementation Implications

**AudioStore enhancements needed**:
- `compactedUrl(text:audioContext:) -> URL?` — Returns M4A if exists
- `compactToM4A(text:audioContext:) async throws` — CAF → M4A conversion
- `preferredFormat(text:audioContext:) -> URL` — Smart format selection

**SuttaPlayer integration**:
- Try M4A first if available, fall back to CAF
- Background task triggers M4A compaction for high-replay segments
- Metrics: track format usage (% playback from M4A vs CAF)

### Benchmark Data

**DN10:2.32.2 segment (1058 chars, 5.3MB CAF)**:
- AVAudioConverter M4A: 0.075s conversion, 280KB output (19.15x compression)
- afconvert M4A (reference): 0.082s, 256KB (20.91x)
- **Tradeoff**: 9% larger file, 8% faster execution

**Full DN33 sutta (1,167 segments)**:
- CAF synthesis: ~4.5 hours × 0.23-0.61s/segment = 3-12 minutes (background task)
- M4A compaction: 1,167 × 0.075s = ~87 seconds (can run overnight)
- Storage savings: 5.3GB CAF → ~1.3GB M4A (75% reduction)

See: `doc/AudioCompression.md` for full technical analysis

## Phase 4: Long-Press Prefetch Integration

See: Task T_AZwZsgFWc for implementation actions

### Design Constraints

**Threading Model**
- **Callbacks**: If used for state transitions, progressCallback fires from AudioSynthesisSession actor (background thread). SuttaCardView @State mutations require main thread. Must marshal via DispatchQueue.main.async.
- **Polling**: Modal runs on main thread; polls session.value from background actor. Session actor handles thread safety; no marshaling needed.
- **Design choice**: Use polling for progress updates (simpler, no thread marshaling). Use optional callback for state transitions if desired (e.g., auto-dismiss modal on .completed/.failed).

**State Persistence: "Background Audio Ready"**
- **Decision**: Do NOT store "background audio ready" status on Card or MLDocument
- **Rationale**: Cache is source of truth via (text, audioContext) hash. Metadata would create sync burden.
- **Verification mechanism**: To verify background audio cached, must check actual cache existence (slower but accurate)
- **For this task**: No pre-verification needed. Synthesis is on-demand; audio is ready when complete.
- **Future UX** (if needed): "Show cached status" would require cache lookup, not Card flag
- **Note**: Cache key includes SCID (potential design issue flagged in AudioStore.md line 75)

**Session Lifecycle**
- User may dismiss SuttaCardView mid-synthesis
- **Design decision**: Session must auto-cancel on dismissal (clean up pending segments)
- Alternative: allow background continuation (not chosen - risk of orphaned tasks)

**Audio Context Initialization**
- When user initiates prefetch (long-press), create `AudioContext(for: suttaRef.lang)`
- AudioContext.init() automatically captures current Settings.shared values at that moment (voiceId, pitch, rate, segmentPause)
- Voicing is deterministic: if user later changes voice/pitch/rate, AudioContext hash changes, invalidating old cache
- No prompt needed; use current settings at initiation time
- See: scv-core/Sources/AudioContext.swift:99 for initialization pattern

**Modal UI Design**
- Circular progress bar displaying currentStep/totalSteps
- Segment count in center of circle (e.g., "523/1167")
- Label below progress bar (text describing synthesis state)
- Button below label: "Cancel" during synthesis, "Done" when complete/failed
- Simple and adequate provisional design; UX can evolve based on user feedback

**Modal Dismissal**
- User may swipe-to-dismiss modal or tap cancel button
- **Design requirement**: Both dismissal methods must trigger session cancellation

**Error Handling**
- Synthesis may fail (state = .failed) with error message
- **Design requirement**: Modal must display error state and allow dismissal/retry

**Progress Update Mechanism**
- **State transitions**: progressCallback fires on state changes (.idle→.synthesizing, .synthesizing→.completed/cancelled/failed)
- **Progress granularity**: For smooth per-segment progress display, modal should poll `session.value` on ~0.5s timer
- Rationale: Callbacks keep UI responsive to synthesis start/end. Polling avoids excessive event firing (100+ times per sutta) while consumers control update frequency.
- Implementation: Use `Timer` or `Task.sleep(nanoseconds:)` loop to poll session.value every 0.5s. Each poll returns fresh SessionSnapshot with current currentStep/totalSteps/estimatedCompletion.
- SessionSnapshot is always up-to-date; polling shows actual progress without requiring callback events.
- See: AudioSynthesisSession.md "Progress Monitoring Patterns" for detailed patterns

**Trigger Mechanism**
- Initial implementation: Long-press on play button (SuttaCardView toolbar, line 135-149)
- Rationale: Pragmatic starting point. UX evolves through user feedback rather than speculative design.
- Future: May add menu item, context menu, or other triggers based on actual user behavior and feedback.
- See: Task T_AZwZsgFWc for implementation details

## Measured Test Results

**Test environment**: macOS 14.0, arm64e, Swift Testing
**Test location**: scv-core/Tests/AudioStoreTests.swift

**Synthesis metrics (Jan 2026)**:

| Voice | Language | Text | Duration | Synthesis Time | File Size | Deterministic? |
|-------|----------|------|----------|---|---|---|
| Default English | en-US | "So I have heard." | 0.943s | 0.29s | 87KB | Yes |
| Sangeeta | en-IN (enhanced) | "So I have heard." | 0.753s | 0.23s | 70KB | Yes |
| Sandy | de-DE (eloquence) | "so habe ich gehoert" | 1.232s | 0.51s | 112KB | No* |
| Petra Premium | de-DE (premium) | "so habe ich gehoert" | 1.237s | 0.61s | 113KB | Yes |

\* Sandy produces slight variations in output across runs (RMS diff 0.191), while others are deterministic.

## See Also

- `SuttaPlayer.md` — Current AVSpeechSynthesizer implementation
- `MerkleJson.md` — Hash algorithm for cache keys
- `scv-core/Tests/AudioStoreTests.swift` — Audio store test suite with synthesis measurements
