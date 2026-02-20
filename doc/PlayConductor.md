# PlayConductor API

## Overview

PlayConductor orchestrates the playing of a PlayList of SuttaRefs.
Specifically, it manages playback state (e.g. .playing, .paused, etc.)
and is also responsible for sequencing segments and segment audio:

* playback state: .playing, .paused, etc.
* audio effects for (e.g., empty text, section, end of sutta, etc.)
* ISpeechSyntesizer calls to play segment pli audio (if enabled)
* ISpeechSyntesizer calls to play segment doc audio (if enabled)
* segmentPause delays

PlayConductor is used by BackgroundPlayer and SuttaPlayer.

### PlayList

PlayList comprises a list of SuttaRefs that identify the documents to be played.
For the first release of scVoice, a PlayList will only contain a single SuttaRef
that specifies the document to be
played segment by segment from the specified scid to the end of the document.

Future PlayLists will support:

* playback of multiple SuttaRefs
* looping playlists
* maximum play times

## Problem Statement

**Current duplication:**

- `SuttaPlayer.playSegmentAt():431-440` - Detects empty segments, announces `.noText`, recursively chains to next segment
- `SuttaPlayer.playSegmentAt():451-467` - Calculates segmentPause delay, uses `asyncAfter` or plays immediately
- `BackgroundPlayer.audioPlayerDidFinishPlaying():819-831` - Chains to next segment after AVAudioPlayer finishes
- `BackgroundPlayer.play():618-634` - Calculates segmentPause delay, uses `asyncAfter` or plays immediately

**Root issue:** Both players must independently implement segment-chaining and delay-respecting playback patterns, leading to maintenance risk and inconsistent empty-segment handling (SuttaPlayer announces `.noText`; BackgroundPlayer doesn't).

## API

PlayConductor provides a single unified method that encapsulates segment playback logic:

```swift
class PlayConductor {
  init(
    audioEffects: IAudioEffects,
    speechSynthesizer: ISpeechSynthesizer,
    suttaRefs: [SuttaRef]
  )

  /// Play segment at given index.
  ///
  /// Handles segment chaining, empty-text detection, audio effects announcements,
  /// and delay respecting. Replaces duplicated logic in SuttaPlayer.playSegmentAt()
  /// and BackgroundPlayer segment-chaining code.
  ///
  /// - Parameters:
  ///   - index: Segment index to play
  ///   - segments: Array of segments
  ///   - audioContext: Audio settings (segmentPause, language, etc)
  ///   - earliestPlaybackTime: Earliest time this segment should start playing
  ///   - onSegmentFinished: Callback when segment finishes (segment index provided)
  func playSegmentAt(
    _ index: Int,
    segments: [Segment],
    audioContext: AudioContext,
    earliestPlaybackTime: Date,
    onSegmentFinished: @escaping (Int) -> Void
  )
}
```

**Responsibilities:**
- Detect empty segments and skip with `.noText` announcement
- Announce `.section` (scid.0) and `.segment` (scid.1) boundaries
- Call ISpeechSynthesizer to play segment text
- Respect segmentPause delays
- Handle end-of-sutta detection and announce `.endSutta`
- Invoke callback when segment finishes to chain to next segment

## Integration

### SuttaPlayer Changes

**Current:** `playSegmentAt(at index: Int)` lines 390-468:
- Bounds checking, empty segment detection, announcements, delay calculation, synthesis

**After refactor:**
- Replace with single call: `conductor.playSegmentAt(index, segments, audioContext, earliestPlaybackTime, onSegmentFinished:)`
- Pass closure to handle next segment when current finishes
- Remove duplicated logic

### BackgroundPlayer Changes

**Current:** `play()` lines 618-634 and `audioPlayerDidFinishPlaying()` lines 794-839:
- Segment bounds checking, delay calculation, AVAudioPlayer delegation

**After refactor:**
- Replace with single call: `conductor.playSegmentAt(index, segments, audioContext, earliestPlaybackTime, onSegmentFinished:)`
- Simplify delegation/callback patterns
- Remove duplicated logic

## Testing

### Unit Tests (PlayConductorTests.swift)

- **Empty segment handling:** Verify `.noText` announced and next segment chained with 500ms delay
- **End of sutta:** Verify `.endSutta` announced and callback not invoked
- **Segment boundaries:** Verify `.section` and `.segment` announcements based on scid
- **Delay calculation:** Verify playback delayed correctly per segmentPause
- **Callback invocation:** Verify `onSegmentFinished` called with correct next index

### Integration Tests (SuttaPlayerTests.swift, BackgroundPlayerTests.swift)

- **SuttaPlayer:** Verify segment chaining works with PlayConductor callback
- **BackgroundPlayer:** Verify segment chaining works with PlayConductor callback
- **Empty segments:** Verify both players receive announcements and callbacks as expected

## Migration Path

1. Create IAudioEffects protocol from existing AudioEffects
2. Implement PlayConductor with playSegmentAt() method and full test coverage (mock IAudioEffects for testing)
3. Inject PlayConductor into SuttaPlayer, replace playSegmentAt() implementation
4. Inject PlayConductor into BackgroundPlayer, replace play() and audioPlayerDidFinishPlaying() logic
5. Remove duplicated segment-chaining code from both players
6. Verify all tests pass (serial execution required due to localization bundle swaps)
