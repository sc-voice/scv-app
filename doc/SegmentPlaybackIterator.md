# SegmentIterator

## Overview

`SegmentIterator` implements `AsyncIterator` for segment traversal with built-in handling of empty segments, audio announcements, and segmentPause delays.

## Interface

```swift
class SegmentIterator: AsyncIterator {
  var segments: [Segment]
  var index: Int
  let audioEffects: IAudioEffects
  let audioContext: AudioContext

  /// Required by AsyncIterator. Returns next playable segment, skipping empties with .noText announcement.
  /// Returns nil when all segments exhausted or iterator cancelled.
  /// Announces .play on first segment, .endSutta on last, .section/.segment for boundaries.
  mutating func next() async -> Segment?

  /// Cancels iteration immediately, stops any active AudioEffect playback, and announces .pause.
  /// After cancel(), next() always returns nil.
  func cancel()
}
```

## Behavior

- Skips segments with empty text
- Announces `.noText` for each empty segment encountered
- Sleeps for `segmentPause` between segments
- Returns next playable segment or nil when done

## Usage

```swift
var iterator = SegmentIterator(
  segments: segments,
  audioEffects: audioEffects,
  audioContext: audioContext
)

for await segment in iterator {
  // segment is next playable segment
  playSegment(segment)
}
```

## Integration

- **BackgroundPlayer:** Replace `startPlayback()` empty-check + `audioPlayerDidFinishPlaying()` chaining
- **SuttaPlayer:** Replace `playSegmentAt()` empty-check + `onPlaybackFinished()` chaining
