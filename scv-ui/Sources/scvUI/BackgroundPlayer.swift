import AVFoundation
import Foundation
import scvCore

#if os(iOS)
  import MediaPlayer
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
      "No segments found for sutta"
    case let .synthesisFailure(msg):
      "Synthesis failed: \(msg)"
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
  case done
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

  /// Duration of current segment audio in seconds (as for
  /// MPMediaItemPropertyPlaybackDuration)
  public let playbackDuration: TimeInterval

  /// Elapsed playback time in seconds (as for
  /// MPNowPlayingInfoPropertyElapsedPlaybackTime)
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
    artist: String,
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

/// Orchestrates passive background playback of the current SuttaCard with
/// minimal UX.
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
  private var audioPlayer: AVAudioPlayer? // FIXME: Stop in cancel() when AVAudioPlayer implementation complete
  private var artistName: String = ""
  private var earliestPlaybackTime: Date = .init()

  #if os(iOS)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var remoteCommandsSetup = false
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
    audioStore: AudioStore = .shared,
  ) {
    self.suttaRef = suttaRef
    self.audioContext = audioContext ?? AudioContext(
      for: suttaRef.lang,
    )
    self.audioStore = audioStore
    super.init()

    // Configure audio session for background playback
    configureAudioSession()

    // Setup audio session interruption handler
    setupAudioInterruptionHandler()

    // Setup remote command handlers for lock screen
    setupRemoteCommands()

    cc.ok2(#line, "init() complete")
  }

  /// Configure AVAudioSession for background playback.
  /// Sets category to .playback to allow playback when lock screen is active.
  /// Only available on iOS.
  private func configureAudioSession() {
    #if os(iOS)
      do {
        let session = AVAudioSession.sharedInstance()

        // Set category to .playback to enable background audio
        // Note: .defaultToSpeaker only works with .playAndRecord category
        try session.setCategory(
          .playback,
          mode: .spokenAudio,
          options: []
        )

        // Activate the session
        try session.setActive(true)

        cc.ok2(#line, "AVAudioSession configured for background playback")
      } catch {
        cc.bad1(#line, "Failed to configure audio session: \(error)")
      }
    #endif
  }

  /// Setup audio session interruption handler for background playback.
  /// Unlike foreground playback (SuttaPlayer), BackgroundPlayer continues playing
  /// through lock screen activation and other interruptions.
  /// Only available on iOS.
  private func setupAudioInterruptionHandler() {
    #if os(iOS)
      NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance(),
        queue: .main,
      ) { [weak self] notification in
        let cc = ColorConsole(#file, #function, dbg.SuttaPlayer.other)
        cc.ok2(#line, #function, "Interruption notification received!")
        guard let self else { return }
        guard let userInfo = notification.userInfo as? [String: Any],
              let typeValue =
              userInfo["AVAudioSessionInterruptionTypeKey"] as? NSNumber
        else {
          cc.bad1(#line, #function, "Could not parse interruption notification")
          return
        }

        let type = AVAudioSession
          .InterruptionType(rawValue: typeValue.uintValue)

        if type == .began {
          // Lock screen or other interruption began
          if self.state == .playing {
            // During playback: continue through lock screen (background playback mode)
            cc.ok2(#line, #function, "Lock screen activated but continuing playback")
          } else {
            // During synthesis or other states: allow normal interruption
            cc.ok2(#line, #function, "Audio interrupted during \(self.state)")
          }
        } else if type == .ended {
          // Interruption ended (e.g., lock screen dismissed)
          // Reconfigure audio session
          configureAudioSession()

          // Resume playback if we were playing before interruption
          // Note: AVAudioSession needs time to reinitialize, so use dispatch_after
          // with a small delay before resuming. This is a known workaround for iOS 14+
          // (See: https://github.com/liorazi/AVAudioSessionWorkaround)
          if self.state == .playing {
            cc.ok1(#line, #function, "Resuming playback after lock screen (delayed)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              self.play()
            }
          } else {
            cc.ok2(#line, #function, "Interruption ended but not resuming - state: \(self.state)")
          }
        }
      }
    #endif
  }

  /// Setup MPRemoteCommandCenter handlers for lock screen controls.
  /// Registers handlers for play, pause, skip forward (next), skip backward (previous).
  /// Only available on iOS.
  private func setupRemoteCommands() {
    #if os(iOS)
      let commandCenter = MPRemoteCommandCenter.shared()

      // Enable and setup play command
      commandCenter.playCommand.isEnabled = true
      commandCenter.playCommand.addTarget { [weak self] _ in
        self?.play()
        return .success
      }

      // Enable and setup pause command
      commandCenter.pauseCommand.isEnabled = true
      commandCenter.pauseCommand.addTarget { [weak self] _ in
        self?.pause()
        return .success
      }

      // Enable and setup next track command (next segment)
      commandCenter.nextTrackCommand.isEnabled = true
      commandCenter.nextTrackCommand.addTarget { [weak self] _ in
        self?.playNext()
        return .success
      }

      // Enable and setup previous track command (previous segment)
      commandCenter.previousTrackCommand.isEnabled = true
      commandCenter.previousTrackCommand.addTarget { [weak self] _ in
        self?.playPrevious()
        return .success
      }

      remoteCommandsSetup = true
      cc.ok2(#line, "Remote commands registered with MPRemoteCommandCenter")
    #endif
  }

  /// Update MPNowPlayingInfoCenter with current playback metadata.
  /// Called whenever playback state or segment changes to keep lock screen in sync.
  /// Only available on iOS.
  private func updateNowPlayingInfo() {
    #if os(iOS)
      guard let snapshot = playbackSnapshot else {
        cc.ok2(#line, "No snapshot available, skipping metadata update")
        return
      }

      var nowPlayingInfo = [String: Any]()

      // Track title (scid + text preview)
      nowPlayingInfo[MPMediaItemPropertyTitle] = snapshot.trackTitle

      // Artist name
      nowPlayingInfo[MPMediaItemPropertyArtist] = snapshot.artist

      // Album title (sutta title from suttaRef)
      nowPlayingInfo[MPMediaItemPropertyAlbumTitle] =
        snapshot.suttaRef.toString()

      // Playback duration
      nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] =
        snapshot.playbackDuration

      // Elapsed playback time
      nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
        snapshot.elapsedPlaybackTime

      // Playback rate
      nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] =
        (state == .playing ? 1.0 : 0.0)

      // Segment index for lock screen display
      nowPlayingInfo[MPMediaItemPropertyComments] =
        "Segment \(snapshot.segmentIndex + 1)/\(snapshot.totalSegments)"

      MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

      cc.ok2(
        #line,
        "Updated now playing info: \(snapshot.trackTitle)",
      )
    #endif
  }

  /// Clear MPNowPlayingInfoCenter metadata (called on terminal states).
  /// Only available on iOS.
  private func clearNowPlayingInfo() {
    #if os(iOS)
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      cc.ok2(#line, "Cleared now playing info")
    #endif
  }

  // MARK: - Internal State Management

  /// Determine segmentKey based on sutta language
  /// Returns "pli" if suttaRef.lang == "pli", otherwise "doc"
  private var segmentKey: String {
    suttaRef.lang == "pli" ? "pli" : "doc"
  }

  /// Update playbackSnapshot observable from current segment state.
  /// Called whenever segment index or state changes.
  /// Also updates lock screen metadata via updateNowPlayingInfo().
  private func updateSnapshot() {
    guard !segments.isEmpty, currentSegmentIndex < segments.count,
          !artistName.isEmpty else { return }

    let segment = segments[currentSegmentIndex]
    let docPreview = (segment.doc ?? "").prefix(20)

    // Get playback timing from AVAudioPlayer if available
    let duration = audioPlayer?.duration ?? 0
    let elapsedTime = audioPlayer?.currentTime ?? 0

    playbackSnapshot = PlaybackSnapshot(
      suttaRef: suttaRef,
      segment: segment,
      segmentIndex: currentSegmentIndex,
      totalSegments: segments.count,
      playbackDuration: duration,
      elapsedPlaybackTime: elapsedTime,
      trackTitle: "\(segment.scid) \(docPreview)",
      artist: artistName,
    )

    // Update lock screen metadata
    updateNowPlayingInfo()
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
      clearNowPlayingInfo()
      cc.bad1(#line, "No segments found for \(suttaRef)")
      throw BackgroundPlayerError.noSegments
    }
    cc.ok2(#line, "Loaded \(segments.count) segments")

    // Find starting segment index from suttaRef.scid
    if let startIndex = segments
      .firstIndex(where: { $0.scid == suttaRef.scid })
    {
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
      audioStore: audioStore,
    )

    // Start polling task to update synthesisSnapshot during synthesis
    let pollingTask = Task {
      while state == .synthesizing {
        if let session = synthesisSession {
          synthesisSnapshot = await session.value
        }
        try? await Task.sleep(nanoseconds: 500_000_000) // ~0.5s
      }
    }

    // Execute synthesis
    let finalSnapshot = await synthesisSession!.execute()
    cc.ok2(#line, "Synthesis complete: \(finalSnapshot.state)")

    // Stop polling
    pollingTask.cancel()

    // Check synthesis result - handle all terminal states
    switch finalSnapshot.state {
    case .completed:
      // Synthesis succeeded - transition to paused state ready for playback
      state = .paused
    case .cancelled:
      // User cancelled synthesis - preserve the cancelled state
      cc.ok1(#line, "Synthesis cancelled by user")
    case let .failed(errorMsg):
      // Synthesis failed - transition to failed state
      state = .failed(errorMsg)
      clearNowPlayingInfo()
      cc.bad1(#line, errorMsg)
      throw BackgroundPlayerError.synthesisFailure(errorMsg)
    default:
      // Unexpected state (shouldn't occur in normal flow)
      let errorMsg = "Unexpected synthesis state: \(finalSnapshot.state)"
      state = .failed(errorMsg)
      clearNowPlayingInfo()
      cc.bad1(#line, errorMsg)
      throw BackgroundPlayerError.synthesisFailure(errorMsg)
    }

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

    // Capture final elapsed time before cancellation
    updateSnapshot()

    // Transition to cancelled
    state = .cancelled
    clearNowPlayingInfo()
    cc.ok1(#line, "cancel() complete")
  }

  // MARK: - Playback Control

  /// Start playback from current segment
  public func play() {
    cc.ok2(#line, "play()")

    // Guard: have valid segments and current index
    guard !segments.isEmpty, currentSegmentIndex < segments.count else {
      cc.bad1(#line, "No segments or invalid index")
      state = .failed("No segments available")
      return
    }

    // Respect segmentPause: delay playback if needed
    let now = Date()
    let delay = max(0, earliestPlaybackTime.timeIntervalSince(now))

    if delay > 0 {
      cc.ok2(#line, "Delaying playback by \(delay)s to respect segmentPause")
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.startPlayback()
      }
    } else {
      startPlayback()
    }
  }

  /// Internal method to start playback of current segment
  private func startPlayback() {
    cc.ok2(#line, "startPlayback()")

    // Guard: still have valid segments and current index
    guard !segments.isEmpty, currentSegmentIndex < segments.count else {
      cc.bad1(#line, "No segments or invalid index")
      state = .failed("No segments available")
      return
    }

    let segment = segments[currentSegmentIndex]

    // Get segment text using segmentKey
    let segmentText = segment.textOf(segmentKey)

    // Guard: segment has text to synthesize
    guard !segmentText.trimmingCharacters(in: .whitespaces).isEmpty else {
      cc.ok2(#line, "Segment has no text, skipping")
      return
    }

    // Get audio URL from cache (forceUrl=false only returns if cached)
    guard let audioUrl = audioStore.audioUrl(
      text: segmentText,
      audioContext: audioContext,
      forceUrl: false,
    ) else {
      cc.bad1(#line, "Audio file not synthesized for segment")
      state = .failed("Audio not available for segment")
      return
    }

    do {
      // Create AVAudioPlayer with cached audio file
      audioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
      audioPlayer?.delegate = self
      audioPlayer?.play()

      // Transition to playing and update observable
      state = .playing
      updateSnapshot()
      cc.ok1(#line, "Playback started for segment \(segment.scid)")
    } catch {
      cc.bad1(#line, "Failed to create player: \(error)")
      state = .failed("Playback failed: \(error.localizedDescription)")
    }
  }

  /// Pause playback
  public func pause() {
    cc.ok2(#line, "pause()")

    // Guard: currently playing
    guard state == .playing else {
      cc.ok2(#line, "Not playing")
      return
    }

    // Stop player
    audioPlayer?.pause()

    // Transition to paused and update observable
    state = .paused
    updateSnapshot()
    cc.ok1(#line, "Playback paused")
  }

  /// Advance to next segment and start playback
  /// Pauses current playback, increments segment index, plays new segment
  public func playNext() {
    cc.ok2(#line, "playNext()")

    // Guard: have valid segments
    guard !segments.isEmpty, currentSegmentIndex < segments.count else {
      cc.bad1(#line, "No segments available")
      return
    }

    // Pause current playback
    if state == .playing {
      audioPlayer?.pause()
    }

    // Advance to next segment
    if currentSegmentIndex < segments.count - 1 {
      currentSegmentIndex += 1
      cc.ok2(#line, "Advanced to segment \(currentSegmentIndex)")
    } else {
      cc.ok2(#line, "Already at last segment")
      state = .paused
      updateSnapshot()
      return
    }

    // Start playback from new segment
    play()
  }

  /// Move to previous segment or restart current segment if elapsed < 1s
  /// - If paused or elapsed time < 1s: move to previous segment and play
  /// - Otherwise: restart playback of current segment
  public func playPrevious() {
    cc.ok2(#line, "playPrevious()")

    // Guard: have valid segments
    guard !segments.isEmpty, currentSegmentIndex < segments.count else {
      cc.bad1(#line, "No segments available")
      return
    }

    // Pause current playback
    if state == .playing {
      audioPlayer?.pause()
    }

    // Get elapsed time from player (or 0 if not playing)
    let elapsedTime = audioPlayer?.currentTime ?? 0

    // Determine which segment to play
    if state == .paused || elapsedTime < 1.0 {
      // Go to previous segment
      if currentSegmentIndex > 0 {
        currentSegmentIndex -= 1
        cc.ok2(#line, "Moved to previous segment \(currentSegmentIndex)")
      } else {
        cc.ok2(#line, "Already at first segment")
        state = .paused
        updateSnapshot()
        return
      }
    } else {
      // Restart current segment (elapsed time >= 1s)
      cc.ok2(
        #line,
        "Elapsed time \(elapsedTime)s >= 1s, restarting current segment",
      )
    }

    // Start playback from target segment
    play()
  }
}

// MARK: - AVAudioPlayerDelegate

@MainActor
extension BackgroundPlayer: @preconcurrency AVAudioPlayerDelegate {
  /// Called when AVAudioPlayer finishes playing
  /// Implements segment chaining: automatically plays next segment if available
  public func audioPlayerDidFinishPlaying(
    _: AVAudioPlayer,
    successfully flag: Bool,
  ) {
    cc.ok2(
      #line,
      "audioPlayerDidFinishPlaying(successfully: \(flag)) for segment \(currentSegmentIndex)",
    )

    guard flag else {
      // Playback interrupted
      state = .failed("Playback interrupted")
      clearNowPlayingInfo()
      cc.bad1(
        #line,
        "Playback failed or interrupted for segment \(currentSegmentIndex)",
      )
      updateSnapshot()
      return
    }

    // Segment playback completed successfully
    cc.ok2(#line, "Segment \(currentSegmentIndex) playback completed")

    // Check if there are more segments to play
    if currentSegmentIndex < segments.count - 1 {
      // Stop and clear current player before advancing to next segment
      audioPlayer?.stop()
      audioPlayer = nil

      // Set earliest time next segment can play (respecting segmentPause)
      earliestPlaybackTime = Date().addingTimeInterval(audioContext.segmentPause)

      // Chain to next segment: advance index and play
      currentSegmentIndex += 1
      cc.ok2(#line, "Chaining to next segment: \(currentSegmentIndex)")
      play() // Automatically start next segment with segmentPause delay
    } else {
      // Reached last segment, transition to done
      state = .done
      clearNowPlayingInfo()
      updateSnapshot()
      cc.ok1(#line, "Playback completed - reached end of sutta")
    }
  }

  /// Called when audio decoding error occurs
  public func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error: Error?) {
    cc.bad1(
      #line,
      "Audio decode error: \(error?.localizedDescription ?? "unknown")",
    )
    state =
      .failed("Audio decode error: \(error?.localizedDescription ?? "unknown")")
    clearNowPlayingInfo()
    updateSnapshot()
  }
}
