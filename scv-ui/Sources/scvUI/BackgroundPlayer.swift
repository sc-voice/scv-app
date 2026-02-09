import AVFoundation
import Foundation
import scvCore

#if os(iOS)
  import UIKit
#endif

// MARK: - BackgroundPlayerError

/// Errors thrown by BackgroundPlayer operations
public enum BackgroundPlayerError: Error, LocalizedError {
  case noSegments
  case synthesisFailure(String)

  public var errorDescription: String? {
    switch self {
    case .noSegments:
      return "No segments found for sutta"
    case .synthesisFailure(let msg):
      return "Synthesis failed: \(msg)"
    }
  }
}

// MARK: - PlaybackState

/// Represents the current playback state
public enum PlaybackState: Equatable, Sendable {
  case idle
  case synthesizing
  case playing
  case paused
  case cancelled
  case failed(String)

  public var isFailed: Bool {
    if case .failed = self {
      return true
    }
    return false
  }

  public var failureMessage: String? {
    if case let .failed(msg) = self {
      return msg
    }
    return nil
  }
}

// MARK: - PlaybackSnapshot

/// Observable snapshot of current playback state and metadata
public struct PlaybackSnapshot: Sendable, Equatable {
  /// Current sutta reference
  public let suttaRef: SuttaRef

  /// Current segment being played
  public let segment: Segment

  /// 0-based index of current segment
  public let segmentIndex: Int

  /// Total number of segments in sutta
  public let totalSegments: Int

  /// Duration of current segment audio in seconds (as for MPMediaItemPropertyPlaybackDuration)
  public let playbackDuration: TimeInterval

  /// Elapsed playback time in seconds (as for MPNowPlayingInfoPropertyElapsedPlaybackTime)
  public let elapsedPlaybackTime: TimeInterval

  /// Track title for lock screen display (e.g., "MN8:1.1 So I have hea...")
  public let trackTitle: String

  /// Artist name for lock screen display (e.g., "Bhikkhu Sujato")
  public let artist: String

  public init(
    suttaRef: SuttaRef,
    segment: Segment,
    segmentIndex: Int,
    totalSegments: Int,
    playbackDuration: TimeInterval,
    elapsedPlaybackTime: TimeInterval,
    trackTitle: String,
    artist: String
  ) {
    self.suttaRef = suttaRef
    self.segment = segment
    self.segmentIndex = segmentIndex
    self.totalSegments = totalSegments
    self.playbackDuration = playbackDuration
    self.elapsedPlaybackTime = elapsedPlaybackTime
    self.trackTitle = trackTitle
    self.artist = artist
  }
}

// MARK: - BackgroundPlayer

/// Orchestrates passive background playback of the current SuttaCard with minimal UX.
///
/// BackgroundPlayer manages:
/// - Audio session configuration for background playback
/// - State machine (idle, synthesizing, playing, paused, failed)
/// - Segment chaining via AVAudioPlayer
/// - AudioSynthesisSession lifecycle
/// - Background task management
/// - Lock screen metadata (MPNowPlayingInfoCenter)
/// - Remote command handling (MPRemoteCommandCenter)
@MainActor
public final class BackgroundPlayer: NSObject, ObservableObject {
  let cc = ColorConsole(#file, #function, dbg.SuttaPlayer.other)

  // MARK: - Observable Properties

  @Published public var state: PlaybackState = .idle
  @Published public var playbackSnapshot: PlaybackSnapshot?
  @Published public var synthesisSnapshot: SessionSnapshot?

  // MARK: - Private Properties

  private let suttaRef: SuttaRef
  private let audioContext: AudioContext
  private let audioStore: AudioStore

  private var segments: [Segment] = []
  private var currentSegmentIndex: Int = 0
  var synthesisSession: AudioSynthesisSession?
  private var audioPlayer: AVAudioPlayer?  // FIXME: Stop in cancel() when AVAudioPlayer implementation complete
  private var artistName: String = ""

  #if os(iOS)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
  #endif

  // MARK: - Initialization

  /// Initialize BackgroundPlayer with a sutta reference.
  ///
  /// - Parameters:
  ///   - suttaRef: Sutta to play
  ///   - audioContext: Optional customization for testing. If nil, derives from
  /// Settings.
  ///   - audioStore: Optional dependency injection for testing. Defaults to
  /// AudioStore.shared
  public init(
    suttaRef: SuttaRef,
    audioContext: AudioContext? = nil,
    audioStore: AudioStore = .shared
  ) {
    self.suttaRef = suttaRef
    self.audioContext = audioContext ?? AudioContext(
      for: suttaRef.lang
    )
    self.audioStore = audioStore
    super.init()
    cc.ok2(#line, "init() complete")
  }

  // MARK: - Internal State Management

  /// Update playbackSnapshot observable from current segment state.
  /// Called whenever segment index or state changes.
  private func updateSnapshot() {
    guard !segments.isEmpty, currentSegmentIndex < segments.count, !artistName.isEmpty else { return }

    let segment = segments[currentSegmentIndex]
    let docPreview = (segment.doc ?? "").prefix(20)

    playbackSnapshot = PlaybackSnapshot(
      suttaRef: suttaRef,
      segment: segment,
      segmentIndex: currentSegmentIndex,
      totalSegments: segments.count,
      playbackDuration: 0,
      elapsedPlaybackTime: 0,
      trackTitle: "\(segment.scid) \(docPreview)",
      artist: artistName
    )
  }

  // MARK: - Preparation & Synthesis

  /// Prepare BackgroundPlayer for playback by synthesizing all segments.
  ///
  /// - Returns: PlaybackSnapshot when synthesis completes and playback is ready
  /// - Throws: BackgroundPlayerError if segment loading or synthesis fails
  public func prepare() async throws -> PlaybackSnapshot {
    cc.ok2(#line, "prepare() starting")

    // Load segments
    segments = await EbtData.segmentsOfSuttaRef(suttaRef)
    guard !segments.isEmpty else {
      state = .failed("No segments found")
      cc.bad1(#line, "No segments found for \(suttaRef)")
      throw BackgroundPlayerError.noSegments
    }
    cc.ok2(#line, "Loaded \(segments.count) segments")

    // Find starting segment index from suttaRef.scid
    if let startIndex = segments.firstIndex(where: { $0.scid == suttaRef.scid }) {
      currentSegmentIndex = startIndex
    } else {
      currentSegmentIndex = 0
    }
    cc.ok2(#line, "Starting at segment index \(currentSegmentIndex)")

    // Get translator name
    // TODO: Get full translator name from EbtData.getMetaprop (requires nonisolated access)
    // For now, use author ID (e.g., "sujato" instead of "Bhikkhu Sujato")
    artistName = suttaRef.author ?? "Unknown"
    cc.ok2(#line, "Artist: \(artistName)")

    // Transition to synthesizing
    state = .synthesizing

    // Create synthesis session
    synthesisSession = AudioSynthesisSession(
      suttaRef,
      audioContext: audioContext,
      audioStore: audioStore
    )

    // Start polling task to update synthesisSnapshot during synthesis
    let pollingTask = Task {
      while state == .synthesizing {
        if let session = synthesisSession {
          synthesisSnapshot = await session.value
        }
        try? await Task.sleep(nanoseconds: 500_000_000)  // ~0.5s
      }
    }

    // Execute synthesis
    let finalSnapshot = await synthesisSession!.execute()
    cc.ok2(#line, "Synthesis complete: \(finalSnapshot.state)")

    // Stop polling
    pollingTask.cancel()

    // Check synthesis result
    guard finalSnapshot.state == .completed else {
      let errorMsg: String
      if case let .failed(msg) = finalSnapshot.state {
        errorMsg = msg
      } else {
        errorMsg = "Synthesis failed"
      }
      state = .failed(errorMsg)
      cc.bad1(#line, errorMsg)
      throw BackgroundPlayerError.synthesisFailure(errorMsg)
    }

    // Ready for playback
    state = .paused

    // Update observable and return snapshot
    updateSnapshot()

    cc.ok1(#line, "prepare() complete - ready for playback")
    return playbackSnapshot!
  }

  // MARK: - Cancellation

  /// Cancel synthesis and playback immediately
  public func cancel() {
    cc.ok2(#line, "cancel()")

    // Halt synthesis if in progress
    if let session = synthesisSession, state == .synthesizing {
      Task {
        _ = await session.cancel()
      }
    }

    // Stop AVAudioPlayer if playing
    if audioPlayer?.isPlaying == true {
      audioPlayer?.stop()
    }
    audioPlayer = nil

    // Transition to cancelled
    state = .cancelled
    cc.ok1(#line, "cancel() complete")
  }

  // MARK: - Playback Control

  /// Start playback from current segment
  public func play() {
    cc.ok2(#line, "play()")
    guard state != .playing else {
      cc.ok2(#line, "Already playing")
      return
    }
    state = .playing
  }

  /// Pause playback
  public func pause() {
    cc.ok2(#line, "pause()")
    guard state == .playing else {
      cc.ok2(#line, "Not playing")
      return
    }
    state = .paused
  }

  /// Advance to next segment
  public func nextSegment() {
    cc.ok2(#line, "nextSegment()")
  }

  /// Move to previous segment
  public func previousSegment() {
    cc.ok2(#line, "previousSegment()")
  }
}
