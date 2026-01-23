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

## Proposed Next Steps

1. **Phase 4 - CachedSynthesizer Implementation** (Pending)
   - Create CachedSynthesizer class implementing ISpeechSynthesizer
   - Wraps AudioStore.storeAudio() for cached playback
   - Emits identical IPlaybackDelegate events as SpeechSynthesizerImpl
   - Implement lookahead prefetch (N+1, N+2 while N plays)
   - Add tests verifying all 4 IPlaybackDelegate events
   - Test end-to-end: SuttaPlayer with injected CachedSynthesizer

2. **Phase 5 - M4A Optimization** (Pending)
   - Link AudioToolbox framework for AAC encoding
   - Implement M4A synthesis path (AVAudioConverter + ExtAudioFile)
   - ~7x compression vs CAF (important for large suttas: 2.2GB → 300MB)
   - Verify playback via AVAudioPlayer

3. **"Create Background Audio" Feature** (Pending)
   - Mark sutta as "background ready" after playback completes
   - Storage: Card model field `backgroundAudioContextHash: String?`
   - Invalidation: hash changes when voice/rate/pitch settings change
   - UI: Visual indicator on sutta card showing audio is cached
   - Verification: check all segments exist with correct hash before marking ready

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
