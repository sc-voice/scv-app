import AVFoundation
import Foundation
import scvCore

#if os(iOS)
  import MediaPlayer
  import UIKit
#endif

// MARK: - SegmentPlaybackIteratorWrapper

/// Class wrapper around SegmentPlaybackIterator to maintain mutable state
/// across async calls (structs are value types, so mutations don't persist)
@MainActor
private final class SegmentPlaybackIteratorWrapper {
  private var iterator: SegmentPlaybackIterator

  init(iterator: SegmentPlaybackIterator) {
    self.iterator = iterator
  }

  func next() async -> (index: Int, segment: Segment)? {
    let result = await callNext()
    return result
  }

  private func callNext() async -> (index: Int, segment: Segment)? {
    // Create a mutable copy, call next(), and store updated copy
    var iter = iterator
    let result = await iter.next()
    iterator = iter
    return result
  }

  func cancel() {
    iterator.cancel()
  }
}

// MARK: - Bundle Extension

#if os(iOS)
  extension Bundle {
    var appIcon: UIImage? {
      if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
         let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
         let files = primary["CFBundleIconFiles"] as? [String],
         let icon = files.last
      {
        return UIImage(named: icon)
      }
      return nil
    }
  }

  // Nonisolated function to create artwork from app icon
  // Uses CGImage to avoid MainActor isolation issues with UIImage
  nonisolated func createAppIconArtwork() -> MPMediaItemArtwork? {
    // Load the lock screen icon image
    guard let iconImage = UIImage(named: "LockScreenIcon") else {
      return nil
    }

    // Extract CGImage (not MainActor-isolated)
    guard let cgImage = iconImage.cgImage else {
      return nil
    }

    let size = CGSize(width: cgImage.width, height: cgImage.height)

    // Create MPMediaItemArtwork with closure that converts CGImage to UIImage
    // The closure is called by MediaPlayer on a background thread
    return MPMediaItemArtwork(boundsSize: size) { _ in
      UIImage(cgImage: cgImage)
    }
  }
#endif

// MARK: - BackgroundPlayerError

/// Errors thrown by BackgroundPlayer operations
public enum BackgroundPlayerError: Error, LocalizedError {
  case noSegments
  case synthesisFailure(String)

  public var errorDescription: String? {
    switch self {
    case .noSegments:
      "background_player.error.no_segments".localized
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
  let cc = ColorConsole(#file, #function, dbg.BackgroundPlayer.other)

  // MARK: - Observable Properties

  @Published public var state: PlaybackState = .idle
  @Published public var playbackSnapshot: PlaybackSnapshot?
  @Published public var synthesisSnapshot: SessionSnapshot?

  // MARK: - Private Properties

  private let suttaRef: SuttaRef
  private let audioContext: AudioContext
  private let audioStore: AudioStore
  private let adapter: IAVAdapter

  private var segments: [Segment] = []
  private var currentSegmentIndex: Int = 0
  var synthesisSession: AudioSynthesisSession?
  private var audioPlayerId: AudioPlayerID?
  private var playbackIterator: SegmentPlaybackIteratorWrapper?
  private var playbackIteratorTask: Task<Void, Never>?
  private var artistName: String = ""
  private var playbackContinuation: CheckedContinuation<Void, Never>?

  #if os(iOS)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var remoteCommandsSetup = false
    private var artWork: MPMediaItemArtwork?
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
    adapter = audioStore.adapter
    super.init()

    // Configure audio session for background playback
    configureAudioSession()

    // Setup audio session interruption handler
    setupAudioInterruptionHandler()

    // Setup remote command handlers for lock screen
    setupRemoteCommands()

    // Load app icon for lock screen artwork (iOS only)
    #if os(iOS)
      cc.ok2(#line, #function, "loading app icon artwork...")
      // Create artwork from app icon (nonisolated, thread-safe via CGImage)
      artWork = createAppIconArtwork()
      if artWork != nil {
        cc.ok1(#line, #function, "Loaded app icon artwork for lock screen")
      } else {
        cc.bad1(#line, #function, "Failed to load app icon artwork")
      }
    #endif

    cc.ok1(#line, #function, "init() complete")
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
          options: [],
        )

        // Activate the session
        try session.setActive(true)

        let msg = "AVAudioSession configured for background playback"
        cc.ok2(#line, #function, msg)
      } catch {
        let msg = "Failed to configure audio session: \(error)"
        cc.bad1(#line, #function, msg)
      }
    #endif
  }

  /// Setup audio session interruption handler for background playback.
  /// Unlike foreground playback (SuttaPlayer), BackgroundPlayer continues
  /// playing
  /// through lock screen activation and other interruptions.
  /// Only available on iOS.
  private func setupAudioInterruptionHandler() {
    #if os(iOS)
      NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance(),
        queue: .main,
      ) { [weak self] notification in
        let cc = ColorConsole(#file, #function, dbg.BackgroundPlayer.other)
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
          if state == .playing {
            // During playback: continue through lock screen (background
            // playback mode)
            cc.ok2(#line, #function, "Lock screen: continuing playback")
          } else {
            // During synthesis or other states: allow normal interruption
            cc.ok2(#line, #function, "Audio interrupted during \(state)")
          }
        } else if type == .ended {
          // Interruption ended (e.g., lock screen dismissed)
          // Reconfigure audio session
          configureAudioSession()

          // Resume playback if we were playing before interruption
          // Note: AVAudioSession needs time to reinitialize, so use
          // dispatch_after
          // with a small delay before resuming. This is a known workaround for
          // iOS 14+
          // (See: https://github.com/liorazi/AVAudioSessionWorkaround)
          if state == .playing {
            cc.ok1(#line, #function, "Resuming playback after delay")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              self.play()
            }
          } else {
            cc.ok1(#line, #function, "not resuming: \(state)")
          }
        }
      }
    #endif
  }

  /// Setup MPRemoteCommandCenter handlers for lock screen controls.
  /// Registers handlers for play, pause, skip forward (next), skip backward
  /// (previous).
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
      let msg = "Remote commands registered with MPRemoteCommandCenter"
      cc.ok2(#line, #function, msg)
    #endif
  }

  /// Update MPNowPlayingInfoCenter with current playback metadata.
  /// Called whenever playback state or segment changes to keep lock screen in
  /// sync.
  /// Only available on iOS.
  private func updateNowPlayingInfo() {
    #if os(iOS)
      guard let snapshot = playbackSnapshot else {
        let msg = "No snapshot available, skipping metadata update"
        cc.ok2(#line, #function, msg)
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
        "background_player.lock_screen.segment_info".localized(
          "\(snapshot.segmentIndex + 1)/\(snapshot.totalSegments)",
        )

      // Add artwork if available
      if let artwork = artWork {
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
      }

      MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

      let msg = "Updated now playing: \(snapshot.trackTitle)"
      cc.ok2(#line, #function, msg)
    #endif
  }

  /// Reset MPNowPlayingInfoCenter metadata to defaults (called on terminal
  /// states).
  /// Preserves album artwork set during init.
  /// Only available on iOS.
  private func resetNowPlayingInfo() {
    #if os(iOS)
      // Preserve artwork, clear dynamic metadata
      var nowPlayingInfo = [String: Any]()
      if let artwork = artWork {
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
      }
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
      cc.ok1(#line, #function, "Reset now playing info")
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

    // Get playback timing from adapter if available
    let duration = audioPlayerId.map { adapter.duration(id: $0) } ?? 0
    let elapsedTime = audioPlayerId.map { adapter.currentTime(id: $0) } ?? 0

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
    cc.ok2(#line, #function, "prepare() starting")

    // Load segments
    segments = await EbtData.segmentsOfSuttaRef(suttaRef)
    guard !segments.isEmpty else {
      state = .failed("background_player.error.no_segments".localized)
      resetNowPlayingInfo()
      cc.bad1(#line, #function, "No segments found for \(suttaRef)")
      throw BackgroundPlayerError.noSegments
    }
    cc.ok2(#line, #function, "Loaded \(segments.count) segments")

    // Find starting segment index from suttaRef.scid
    if let startIndex = segments
      .firstIndex(where: { $0.scid == suttaRef.scid })
    {
      currentSegmentIndex = startIndex
    } else {
      currentSegmentIndex = 0
    }
    let msg = "Starting at segment index \(currentSegmentIndex)"
    cc.ok2(#line, #function, msg)

    // Get translator name
    // TODO: Get full translator name from EbtData.getMetaprop (requires nonisolated access)
    // For now, use author ID (e.g., "sujato" instead of "Bhikkhu Sujato")
    artistName = suttaRef.author ?? "Unknown"
    cc.ok2(#line, #function, "Artist: \(artistName)")

    // Transition to synthesizing
    state = .synthesizing

    // Disable idle timer during synthesis to prevent screen lock
    IdleTimerManager.disableIdleTimer()
    cc.ok2(#line, #function, "Disabled idle timer for synthesis")

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
    cc.ok2(#line, #function, "Synthesis complete: \(finalSnapshot.state)")

    // Stop polling
    pollingTask.cancel()

    // Re-enable idle timer after synthesis completes
    IdleTimerManager.enableIdleTimer()
    cc.ok2(#line, #function, "Re-enabled idle timer after synthesis")

    // Check synthesis result - handle all terminal states
    switch finalSnapshot.state {
    case .completed:
      // Synthesis succeeded - transition to paused state ready for playback
      state = .paused
    case .cancelled:
      // User cancelled synthesis - preserve the cancelled state
      cc.ok1(#line, #function, "Synthesis cancelled by user")
    case let .failed(errorMsg):
      // Synthesis failed - transition to failed state
      state = .failed(errorMsg)
      resetNowPlayingInfo()
      cc.bad1(#line, #function, errorMsg)
      throw BackgroundPlayerError.synthesisFailure(errorMsg)
    default:
      // Unexpected state (shouldn't occur in normal flow)
      let errorMsg = "Unexpected synthesis state: \(finalSnapshot.state)"
      state = .failed(errorMsg)
      resetNowPlayingInfo()
      cc.bad1(#line, #function, errorMsg)
      throw BackgroundPlayerError.synthesisFailure(errorMsg)
    }

    // Update observable and return snapshot
    updateSnapshot()

    cc.ok1(#line, #function, "prepare() complete - ready for playback")
    return playbackSnapshot!
  }

  // MARK: - Cancellation

  /// Cancel synthesis and playback immediately
  public func cancel() {
    cc.ok2(#line, #function, "cancel()")

    // Cancel iterator and task
    playbackIteratorTask?.cancel()
    playbackIterator?.cancel()

    // Signal continuation if waiting
    if let continuation = playbackContinuation {
      playbackContinuation = nil
      continuation.resume()
    }

    // Halt synthesis if in progress
    if let session = synthesisSession, state == .synthesizing {
      Task {
        _ = await session.cancel()
      }
      // Re-enable idle timer if synthesis was cancelled
      IdleTimerManager.enableIdleTimer()
      cc.ok2(#line, #function, "Re-enabled idle timer after synthesis cancel")
    }

    // Stop audio player if playing
    if let id = audioPlayerId, adapter.isPlaying(id: id) {
      adapter.stop(id: id)
    }
    audioPlayerId = nil

    // Capture final elapsed time before cancellation
    updateSnapshot()

    // Transition to cancelled
    state = .cancelled
    resetNowPlayingInfo()
    cc.ok1(#line, #function, "cancel() complete")
  }

  // MARK: - Playback Control

  /// Start playback from current segment
  public func play() {
    cc.ok2(#line, #function, "play()")

    // Guard: have valid segments and current index
    guard !segments.isEmpty, currentSegmentIndex < segments.count else {
      cc.bad1(#line, #function, "No segments or invalid index")
      state = .failed("background_player.error.no_segments_available".localized)
      return
    }

    // Cancel old iterator and task if playing
    playbackIteratorTask?.cancel()
    playbackIterator?.cancel()
    playbackIterator = nil
    playbackIteratorTask = nil

    // Immediately set state to .playing
    state = .playing

    // Update snapshot immediately so tests can see current state
    updateSnapshot()

    // Create iterator starting at currentSegmentIndex
    let iterator = SegmentPlaybackIterator(
      segments: segments,
      index: currentSegmentIndex,
      audioEffects: AudioEffects.shared,
      audioContext: audioContext,
      textKey: "doc",
    )
    playbackIterator = SegmentPlaybackIteratorWrapper(iterator: iterator)

    // Spawn async loop task for all segments starting at currentSegmentIndex
    playbackIteratorTask = Task {
      while !Task.isCancelled {
        guard let (idx, segment) = await playbackIterator?.next() else {
          self.cc.ok2(#line, #function, "iterator->nil")
          break
        }

        // Update segment index BEFORE playback so updateSnapshot() has correct
        // index
        currentSegmentIndex = idx

        // Play segment
        await playSegment(segment)

        // Stop if cancelled
        if Task.isCancelled {
          break
        }
      }

      // Playback completed
      state = .done
      resetNowPlayingInfo()
      updateSnapshot()
      cc.ok2(#line, #function, "Playback completed via iterator")
    }

    cc.ok1(#line, #function, "Playback started")
  }

  /// - Parameter segment: Segment to play
  private func playSegment(_ segment: Segment) async {
    cc.ok2(#line, #function, segment.scid)

    // Get segment text using segmentKey
    let segmentText = segment.textOf(segmentKey)

    // Guard: segment has text to play
    guard !segmentText.trimmingCharacters(in: .whitespaces).isEmpty else {
      let msg = "Segment \(segment.scid) has no text"
      cc.ok2(#line, #function, msg)
      return
    }

    // Get audio URL from cache
    guard let audioUrl = audioStore.audioUrl(
      text: segmentText,
      audioContext: audioContext,
      forceUrl: false,
    ) else {
      let msg = "Audio file not available for segment \(segment.scid)"
      cc.bad1(#line, #function, msg)
      state = .failed("background_player.error.audio_not_available".localized)
      return
    }

    do {
      // Stop and clear old audio player
      if let id = audioPlayerId {
        adapter.stop(id: id)
      }
      audioPlayerId = nil

      // Create audio player with cached audio file using adapter
      let playerId = try adapter.createPlayer(contentsOf: audioUrl)
      audioPlayerId = playerId
      adapter.setDelegate(id: playerId, delegate: self)
      adapter.play(id: playerId)

      // Update observable immediately so snapshot has duration/elapsed time
      state = .playing
      updateSnapshot()
      cc.ok1(#line, #function, "Playback started for segment \(segment.scid)")

      // Wait for playback to complete via continuation
      // audioPlayerDidFinishPlaying() will signal completion
      await withCheckedContinuation { continuation in
        playbackContinuation = continuation
      }

      // Update snapshot again at completion
      updateSnapshot()

      cc.ok2(#line, #function, "Playback completed for segment \(segment.scid)")
    } catch {
      let msg = "Failed to create player: \(error)"
      cc.bad1(#line, #function, msg)
      state = .failed("background_player.error.playback_failed".localized)
    }
  }

  /// Pause playback
  public func pause() {
    cc.ok2(#line, #function, "pause()")

    // Guard: currently playing
    guard state == .playing else {
      cc.ok2(#line, #function, "Not playing")
      return
    }

    // Cancel iterator and task to stop chaining
    playbackIteratorTask?.cancel()
    playbackIterator?.cancel()

    // Stop player
    if let id = audioPlayerId {
      adapter.pause(id: id)
    }

    // Signal continuation if waiting
    if let continuation = playbackContinuation {
      playbackContinuation = nil
      continuation.resume()
    }

    // Transition to paused and update observable
    state = .paused
    AudioEffects.shared.announce(.pause)
    updateSnapshot()
    cc.ok1(#line, #function, "Playback paused")
  }

  /// Advance to next segment and start playback
  /// Cancels current playback, increments segment index, plays new segment
  public func playNext() {
    cc.ok2(#line, #function, "playNext()")

    // Guard: have valid segments
    guard !segments.isEmpty, currentSegmentIndex < segments.count else {
      cc.bad1(#line, #function, "No segments available")
      return
    }

    // Cancel current iterator and task
    playbackIteratorTask?.cancel()
    playbackIterator?.cancel()

    // Signal continuation if waiting
    if let continuation = playbackContinuation {
      playbackContinuation = nil
      continuation.resume()
    }

    // Advance to next segment
    if currentSegmentIndex < segments.count - 1 {
      currentSegmentIndex += 1
      cc.ok2(#line, #function, "Advanced to segment \(currentSegmentIndex)")
      // Update snapshot with new index before play() spawns async task
      updateSnapshot()
    } else {
      cc.ok2(#line, #function, "Already at last segment")
      state = .paused
      updateSnapshot()
      return
    }

    // Start playback from new segment with new iterator
    play()
  }

  /// Move to previous segment or restart current segment if elapsed < 1s
  /// - If paused or elapsed time < 1s: move to previous segment and play
  /// - Otherwise: restart playback of current segment
  public func playPrevious() {
    cc.ok2(#line, #function, "playPrevious()")

    // Guard: have valid segments
    guard !segments.isEmpty, currentSegmentIndex < segments.count else {
      cc.bad1(#line, #function, "No segments available")
      return
    }

    // Cancel current iterator and task
    playbackIteratorTask?.cancel()
    playbackIterator?.cancel()

    // Signal continuation if waiting
    if let continuation = playbackContinuation {
      playbackContinuation = nil
      continuation.resume()
    }

    // Get elapsed time from player (or 0 if not playing)
    let elapsedTime = audioPlayerId.map { adapter.currentTime(id: $0) } ?? 0

    // Determine which segment to play
    if state == .paused || elapsedTime < 1.0 {
      // Go to previous segment
      if currentSegmentIndex > 0 {
        currentSegmentIndex -= 1
        let msg = "Moved to previous: \(currentSegmentIndex)"
        cc.ok2(#line, #function, msg)
        // Update snapshot with new index before play() spawns async task
        updateSnapshot()
      } else {
        cc.ok2(#line, #function, "Already at first segment")
        state = .paused
        updateSnapshot()
        return
      }
    } else {
      // Restart current segment (elapsed time >= 1s)
      let msg = "Elapsed time \(elapsedTime)s >= 1s, restarting segment"
      cc.ok2(#line, #function, msg)
      // Update snapshot before restarting current segment
      updateSnapshot()
    }

    // Start playback from target segment with new iterator
    play()
  }
}

// MARK: - IAVAudioPlayerDelegate

extension BackgroundPlayer: @preconcurrency IAVAudioPlayerDelegate {
  /// Called when audio player finishes playing
  /// Signals completion to resume iterator loop (which handles chaining)
  public func audioPlayerDidFinishPlaying(
    successfully flag: Bool,
  ) {
    let msg = "audioPlayerDidFinishPlaying(flag: \(flag)) segment: \(currentSegmentIndex)"
    cc.ok2(#line, #function, msg)

    guard flag else {
      // Playback interrupted
      state = .failed("background_player.error.playback_interrupted".localized)
      resetNowPlayingInfo()
      let msg = "Playback failed segment: \(currentSegmentIndex)"
      cc.bad1(#line, #function, msg)
      updateSnapshot()

      // Signal continuation to break iterator loop
      if let continuation = playbackContinuation {
        playbackContinuation = nil
        continuation.resume()
      }
      return
    }

    // Segment playback completed successfully
    cc.ok1(#line, #function, "currentSegmentIndex:\(currentSegmentIndex)")

    // Signal completion to iterator loop via continuation
    // Iterator loop will call next() to get next segment
    if let continuation = playbackContinuation {
      playbackContinuation = nil
      continuation.resume()
    }
  }

  /// Called when audio decoding error occurs
  public func audioPlayerDecodeErrorDidOccur(error: Error?) {
    let errorMsg = error?.localizedDescription ?? "unknown"
    cc.bad1(#line, #function, "Audio decode error: \(errorMsg)")
    state = .failed("Audio decode error: \(errorMsg)")
    resetNowPlayingInfo()
    updateSnapshot()

    // Signal continuation to break iterator loop
    if let continuation = playbackContinuation {
      playbackContinuation = nil
      continuation.resume()
    }
  }

  /// Called when audio playback is interrupted
  public func audioPlayerBeginInterruption() {
    cc.ok2(#line, #function, "Audio interruption began")
    pause()
  }

  /// Called when interruption ends
  public func audioPlayerEndInterruption(shouldResume: Bool) {
    cc.ok2(
      #line,
      #function,
      "Audio interruption ended, shouldResume: \(shouldResume)",
    )
    if shouldResume, state == .paused {
      play()
    }
  }
}
