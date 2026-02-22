# SegmentPlaybackIterator

## Overview

`SegmentPlaybackIterator` implements `AsyncIterator` for segment traversal with built-in handling of empty segments, audio announcements, and segmentPause delays.

## Interface

```swift
struct SegmentPlaybackIterator: IAsyncIterator {
  var segments: [Segment]
  var index: Int
  let audioEffects: IAudioEffects
  let audioContext: AudioContext
  let textKey: String

  /// Required by AsyncIterator. 
  /// Returns next playable segment with its index, skipping empties with .noText announcement.
  /// Returns nil when all segments exhausted or iterator cancelled.
  /// Announces .play on first segment, .endSutta on last, .segment for boundaries.
  mutating func next() async -> (index: Int, segment: Segment)?

  /// Cancels iteration immediately, stops any active AudioEffect playback, and announces .pause.
  /// After cancel(), next() always returns nil.
  func cancel()
}
```

## Behavior

- `textKey` parameter is required (e.g., "doc") and specifies which segment property to test for empty text
- Skips segments with empty text (tests segment property specified by `textKey`)
- Announces `.noText` for each empty segment encountered
- Sleeps for `segmentPause` between segments
- Returns next playable segment or nil when done

## Usage

```swift
var iterator = SegmentPlaybackIterator(
  segments: segments,
  index: 0,
  audioEffects: audioEffects,
  audioContext: audioContext,
  textKey: "doc"
)

while let (index, segment) = await iterator.next() {
  // index and segment are next playable segment
  playSegment(segment, at: index)
}
```

