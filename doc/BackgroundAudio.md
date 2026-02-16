# Background Audio Playback

## Overview

The application provides Text to Speech (TTS) in two different ways:

* **Foreground Audio** is highly interactive with the user focused actively reading and listening to text. Foreground audio consumes more battery power since it is highly interactive.
* **Background Audio** is minimally interactive with the user actively listening while engaged in activities that require outward attention (e.g., walking). With background audio, the screen will typically be locked for maximum conservation of energy.

### Background Playback

Background Audio is disabled by default because background audio requires that audio synthesis for an entire sutta be completed before that sutta can be played with the lock screen. 
The user can enable Background Audio by enabling Background Playback in Settings.
Enabling background playback brings up an informational modal dialog that explains:

* The need to synthesize entire documents prior to background playback
* The user must long-press the Play icon to use background playback

### Technical Strategy

Synthesizing and playing back cached audio is more complex than synthesizing text on demand.
That complexity warrants a separations of concerns for both the user experience and implementation. 

When Background Playback is disabled. The user will hear TTS synthesis on demand.

When Background Playback is enabled, The user will hear cached audio synthesized on demand in Foreground Audio mode and will hear batch-synthesized audio in Background Audio mode.
In other words, the user setting for Background Playback controls whether audio is played from a cached file or from the synthesizer directly.

## Technical Notes

### Benchmark Data

**Synthesis timing (MEASURED - See: scv-core/Tests/AudioStoreTests.swift)**

 **Per-segment timing (synthesis + write):**
 - Default English (en-US): 290ms/segment
 - Sangeeta (en-IN, enhanced): 230ms/segment
 - Sandy (de-DE, eloquence): 510ms/segment
 - Petra Premium (de-DE, premium): 610ms/segment

 **Estimated time for DN33 (1,167 segments):**
 - Best case (Sangeeta): ~4.5 minutes
 - Average (mixed voices): ~8-10 minutes
 - Worst case (Petra Premium): ~12-15 minutes

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
- `BackgroundPlayer.md` - Background player
- `BackgroundPlayerView.md` - Background player UI
- `AudioSynthesisSession.md` - Batch TTS syntesizer
- `AudioStore.md` - Audio cache
