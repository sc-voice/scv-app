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
///   audioContext: audioContext,
///   textKey: "doc"
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
  private let textKey: String
  public private(set) var isPlaying: Bool = true

  /// Initialize iterator with segments and audio settings
  /// - Parameters:
  ///   - segments: Array of segments to iterate through
  ///   - audioEffects: Audio effects handler for announcements and cancellation
  ///   - audioContext: Audio settings including segment pause duration
  ///   - textKey: Segment property to test for emptiness (e.g., "doc")
  public init(
    segments: [Segment],
    index: Int = 0,
    audioEffects: IAudioEffects,
    audioContext: AudioContext,
    textKey: String,
  ) {
    self.segments = segments
    self.index = index
    self.audioEffects = audioEffects
    self.audioContext = audioContext
    self.textKey = textKey
    cc.ok1(#line, #function, "\(segments.count) segments")
  }

  /// Returns next playable segment with its index, skipping empties with
  /// .noText announcement.
  /// Returns nil when all segments exhausted or iterator cancelled.
  /// Announces .play on first segment, .endSutta on last, .section/.segment for
  /// boundaries.
  public mutating func next() async -> (index: Int, segment: Segment)? {
    if !isPlaying {
      cc.ok1(#line, #function, "iteration cancelled")
      return nil
    }

    if index >= segments.count {
      await audioEffects.announceAsync(.endSutta)
      isPlaying = false
      cc.ok1(#line, #function, "announced .endSutta for last segment")
      return nil
    }

    // Sleep between segments (but not before first segment)
    if index > 0 {
      cc.ok2(#line, #function, "segmentPause:\(audioContext.segmentPause)s")
      try? await Task
        .sleep(nanoseconds: UInt64(audioContext.segmentPause * 1_000_000_000))
    }

    // Skip empty segments (test property specified by textKey) and announce
    // .noText for each
    while index < segments.count {
      let segment = segments[index]
      let text: String? = switch textKey {
      case "doc": segment.doc
      case "pli": segment.pli
      case "ref": segment.ref
      default: segment.doc
      }
      let isEmpty = text == nil || text?.isEmpty ?? true

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
    let scid = segment.scid

    switch segment.type {
    case .header:
      if scid.hasSuffix(":0.1") {
        await audioEffects.announceAsync(.header)
        cc.ok2(#line, #function, ".header", scid)
      }
    case .section:
      await audioEffects.announceAsync(.section)
      cc.ok2(#line, #function, ".section", scid)
    case .paragraph:
      await audioEffects.announceAsync(.paragraph)
      cc.ok2(#line, #function, ".paragraph", scid)
    case .text:
      await audioEffects.announceAsync(.segment)
      cc.ok2(#line, #function, ".segment", scid)
    }

    let segmentIndex = index
    index += 1

    cc.ok1(#line, #function, segment.scid)
    return (index: segmentIndex, segment: segment)
  }

  /// Cancels iteration immediately, stops any active AudioEffect playback, and
  /// announces .pause.
  /// After cancel(), next() always returns nil.
  public mutating func cancel() {
    isPlaying = false
    audioEffects.cancel()
    audioEffects.announce(.pause)
    cc.ok1(#line, #function)
  }
}
