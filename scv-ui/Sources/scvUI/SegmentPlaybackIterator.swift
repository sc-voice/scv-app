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
/// for await segment in iterator {
///   // segment is next playable segment
///   playSegment(segment)
/// }
/// ```
@MainActor
public struct SegmentPlaybackIterator: IAsyncIterator {
  let cc = ColorConsole(#file, #function, dbg.SegmentPlaybackIterator.other)
  public typealias Element = Segment

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
    audioEffects: IAudioEffects,
    audioContext: AudioContext,
  ) {
    self.segments = segments
    self.audioEffects = audioEffects
    self.audioContext = audioContext
    index = 0
    cc.ok1(#line, #function, "\(segments.count) segments")
  }

  /// Returns next playable segment, skipping empties with .noText announcement.
  /// Returns nil when all segments exhausted or iterator cancelled.
  /// Announces .play on first segment, .endSutta on last, .section/.segment for
  /// boundaries.
  public mutating func next() async -> Segment? {
    // Return nil if cancelled
    guard !isCancelled else {
      cc.ok2(#line, "iteration cancelled")
      return nil
    }

    // Return nil if we've exhausted all segments
    guard index < segments.count else {
      cc.ok2(#line, "all segments exhausted at index \(index)")
      return nil
    }

    // Sleep between segments (but not before first segment)
    if index > 0 {
      cc.ok2(#line, "sleeping for \(audioContext.segmentPause)s before segment")
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

      cc.ok2(#line, "skipping empty segment at index \(index): \(segment.scid)")
      audioEffects.announce(.noText)
      index += 1
    }

    // If we've exhausted all segments after skipping empties, return nil
    guard index < segments.count else {
      cc.ok2(#line, "all segments exhausted after skipping empties")
      return nil
    }

    let segment = segments[index]
    let isFirstSegment = index == 0
    let isLastSegment = index == segments.count - 1

    // Announce .play on first segment
    if isFirstSegment {
      audioEffects.announce(.play)
      cc.ok2(#line, "announced .play for first segment")
    } else {
      // Announce segment boundary for non-first segments
      audioEffects.announce(.segment)
      cc.ok2(#line, "announced .segment boundary")
    }

    // Announce .endSutta on last segment
    if isLastSegment {
      audioEffects.announce(.endSutta)
      cc.ok2(#line, "announced .endSutta for last segment")
    }

    index += 1
    cc.ok2(#line, #function, segment.scid)
    return segment
  }

  /// Cancels iteration immediately, stops any active AudioEffect playback, and
  /// announces .pause.
  /// After cancel(), next() always returns nil.
  public mutating func cancel() {
    isCancelled = true
    audioEffects.cancel()
    cc.ok2(#line, #function)
  }
}
