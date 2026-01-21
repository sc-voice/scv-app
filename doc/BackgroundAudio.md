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
- Synthesis time = N segments × ~50ms per segment = 5+ seconds minimum
- User experience options:
  1. Block UI for 5+ seconds (unacceptable)
  2. Non-blocking synthesis with progress bar (requires background queue)
  3. Only enable background playback for already-cached suttas

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

1. **Synthesis timing (UNKNOWN - REQUIRES TESTING)**
   - How long to synthesize a typical long sutta?
   - Per-segment timing: synthesis + file write
   - Total time threshold for acceptable UX?
   - If >2 minutes, background synthesis becomes critical

2. **Progress UI**:
   - Show segment count and ETA?
   - Allow cancellation?
   - Resume from where it left off if interrupted?

3. **First-play experience**:
   - New sutta: must choose foreground synthesis (loses background) or wait for background cache?
   - Or: allow foreground synthesis but disable backgrounding until "Create Background Audio" done?

## Proposed Next Steps

1. **Measure synthesis timing** (high priority)
   - Pick a long sutta (100+ segments)
   - Profile: segment synthesis time, file write time, total duration
   - Determine UX feasibility

2. **Design cache key strategy**
   - How AudioContext hash computed and stored
   - Invalidation policy when settings change
   - File naming/organization in cache directory

3. **Prototype SuttaPlayer dual-mode playback**
   - Detect cache hit vs miss
   - Switch between AVSpeechSynthesizer and AVAudioPlayer
   - Handle segment chaining differently for each mode

4. **Implement "Create Background Audio" UI**
   - Menu item, progress indication, completion state

## See Also

- `SuttaPlayer.md` — Current AVSpeechSynthesizer implementation
- `MerkleJson.md` — Hash algorithm for cache keys
- `doc/AudioCaching.md` — Caching analysis (TBD - companion doc)
