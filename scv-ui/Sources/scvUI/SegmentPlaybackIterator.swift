//
//  SegmentPlaybackIterator.swift
//  scv-ui
//
//  AsyncIterator for segment playback with built-in announcement and pause
//  handling
//

import Foundation
import scvCore

// MARK: - IAsyncIterator

/// Protocol for async iteration (simplified version of Swift's AsyncIterator)
public protocol IAsyncIterator {
  associatedtype Element

  mutating func next() async -> Element?
}

// MARK: - SegmentPlaybackIterator

/// Implements AsyncIterator for segment playback with built-in handling of:
/// - Empty segment detection + .noText announcement
/// - .play on first segment, .endSutta on last
/// - .section/.segment boundary announcements
/// - segmentPause delays between segments
/// - cancel() to halt iteration and stop active audio effects
///
/// Usage:
/// ```swift
/// var iterator = SegmentPlaybackIterator(
///   segments: segments,
///   audioEffects: audioEffects,
///   audioContext: audioContext
/// )
///
/// while let (index, segment) = await iterator.next() {
///   // index and segment are next playable segment
///   playSegment(segment, at: index)
/// }
/// ```
@MainActor
public struct SegmentPlaybackIterator: IAsyncIterator {
  let cc = ColorConsole(#file, #function, dbg.SegmentPlaybackIterator.other)
  public typealias Element = (index: Int, segment: Segment)

  private var segments: [Segment]
  private var index: Int
  private let audioEffects: IAudioEffects
  private let audioContext: AudioContext
  private var isCancelled: Bool = false

  /// Initialize iterator with segments and audio settings
  /// - Parameters:
  ///   - segments: Array of segments to iterate through
  ///   - audioEffects: Audio effects handler for announcements and cancellation
  ///   - audioContext: Audio settings including segment pause duration
  public init(
    segments: [Segment],
    index: Int = 0,
    audioEffects: IAudioEffects,
    audioContext: AudioContext,
  ) {
    self.segments = segments
    self.index = index
    self.audioEffects = audioEffects
    self.audioContext = audioContext
    cc.ok1(#line, #function, "\(segments.count) segments")
  }

  /// Returns next playable segment with its index, skipping empties with
  /// .noText announcement.
  /// Returns nil when all segments exhausted or iterator cancelled.
  /// Announces .play on first segment, .endSutta on last, .section/.segment for
  /// boundaries.
  public mutating func next() async -> (index: Int, segment: Segment)? {
    // Return nil if cancelled
    guard !isCancelled else {
      cc.ok1(#line, #function, "iteration cancelled")
      return nil
    }

    // Return nil if we've exhausted all segments
    guard index < segments.count else {
      cc.ok1(#line, #function, "all segments exhausted at index \(index)")
      return nil
    }

    // Sleep between segments (but not before first segment)
    if index > 0 {
      cc.ok2(#line, #function, "segmentPause:\(audioContext.segmentPause)s")
      try? await Task
        .sleep(nanoseconds: UInt64(audioContext.segmentPause * 1_000_000_000))
    }

    // Skip empty segments (no doc, pli, or ref) and announce .noText for each
    while index < segments.count {
      let segment = segments[index]
      let isEmpty = (segment.doc == nil || segment.doc?.isEmpty ?? true)
        && (segment.pli == nil || segment.pli?.isEmpty ?? true)
        && (segment.ref == nil || segment.ref?.isEmpty ?? true)

      guard isEmpty else { break }

      cc.ok2(#line, #function, "skipping empty:\(segment.scid)")
      await audioEffects.announceAsync(.noText)
      index += 1
    }

    // If we've exhausted all segments after skipping empties, return nil
    guard index < segments.count else {
      cc.ok1(#line, #function, "all segments exhausted after skipping empties")
      return nil
    }

    let segment = segments[index]

    if index == 0 {
      // Announce .play on first segment of document
      audioEffects.announce(.play)
      cc.ok2(#line, #function, "announced .play for first segment")
    } else {
      // Announce segment boundary for non-first segments
      audioEffects.announce(.segment)
      cc.ok2(#line, #function, "announced .segment boundary")
    }

    let segmentIndex = index
    index += 1

    // Announce .endSutta on last segment
    if index == segments.count {
      audioEffects.announce(.endSutta)
      cc.ok2(#line, #function, "announced .endSutta for last segment")
    }
    cc.ok1(#line, #function, segment.scid)
    return (index: segmentIndex, segment: segment)
  }

  /// Cancels iteration immediately, stops any active AudioEffect playback, and
  /// announces .pause.
  /// After cancel(), next() always returns nil.
  public mutating func cancel() {
    isCancelled = true
    audioEffects.cancel()
    cc.ok1(#line, #function)
  }
}
