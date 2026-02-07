import AVFoundation
import Foundation
import scvCore

#if os(iOS)
  import UIKit
#else
  // macOS: UIKit not available
#endif

// MARK: - Error Types

public enum SuttaPlayerError: Error {
  case documentNotFound(SuttaRef)
  case noValidSegments
}

@MainActor
public final class SuttaPlayer: NSObject, ObservableObject,
  IPlaybackDelegate
{
  let cc = ColorConsole(#file, #function, dbg.SuttaPlayer.other)
  public static let shared = SuttaPlayer()

  @Published public var isPlaying = false
  @Published public var isSynthesizerSpeaking = false
  @Published public var currentSutta: MLDocument?
  @Published public var audioContext: AudioContext?

  private var synthesizer: ISpeechSynthesizer
  /// Segments extracted from currentSutta, used for sequential playback
  private var segments: [Segment] = []
  /// Current playback position in segments array
  private var currentSegmentIndex = 0
  /// Next segment index to play in onPlaybackFinished callback. Updated before
  /// queuing
  /// synthesizer.playText() to handle user jumps during async callbacks
  private var nextIndexToPlay = 0
  /// Prevents rapid play/pause toggling from button mashing
  private var isTransitioning = false
  /// Timeout check scheduled after togglePlayback(); cancelled when playback
  /// actually starts.
  /// Used to detect synthesis failures (5 second timeout)
  private var pendingPlaybackCheck: DispatchWorkItem?
  /// Earliest time next segment can start playing, respecting segmentPause
  /// setting
  /// between segments for listener clarity
  private var earliestPlaybackTime: Date = .init()

  init(synthesizer: ISpeechSynthesizer = CachedSynthesizer()) {
    self.synthesizer = synthesizer
    super.init()
    cc.ok2(#line, "init() starting")
    configureAudioSession()
    self.synthesizer.playbackDelegate = self
    setupAudioInterruptionHandler()
    cc.ok2(#line, "init() complete")
  }

  private func setupAudioInterruptionHandler() {
    #if os(iOS)
      NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance(),
        queue: .main,
      ) { [weak self] notification in
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
          cc.bad1(#line, #function, "Audio session interrupted")
          pause()
        } else if type == .ended {
          let options =
            (userInfo["AVAudioSessionInterruptionOptionKey"] as? NSNumber)?
              .uintValue ?? 0
          if AVAudioSession.InterruptionOptions(rawValue: options)
            .contains(.shouldResume)
          {
            cc.ok1(#line, #function, "Audio session resumed - reconfiguring")
            configureAudioSession()
          } else {
            cc.bad1(
              #line,
              #function,
              "Audio session resumed but resumption not recommended",
            )
          }
        }
      }
    #endif
  }

  /// iOS only: Configure audio session for playback.
  /// - Category: .playback (allows audio while silent switch enabled)
  /// - Options: .duckOthers (lowers other audio during speech for clarity)
  /// macOS: no-op (no audio session needed)
  private func configureAudioSession() {
    #if os(iOS)
      do {
        try AVAudioSession.sharedInstance()
          .setCategory(.playback, mode: .default, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        cc.bad1(
          #line,
          "Failed to configure audio session: \(error.localizedDescription)",
        )
      }
    #endif
  }

  @MainActor
  public func load(_ sutta: MLDocument) {
    _ = synthesizer.stopSpeaking(at: .immediate)
    currentSutta = sutta
    segments = sutta.segments()
    currentSegmentIndex = 0
    isPlaying = false
    cc.ok1(#line, #function, "isPlaying:", isPlaying)
  }

  @MainActor
  public func togglePlayback() {
    guard currentSutta != nil else { return }
    guard !isTransitioning else {
      cc.ok1(#line, #function, "togglePlayback ignored - already transitioning")
      return
    }

    isTransitioning = true
    if isPlaying {
      pause()
      cc.ok1(#line, #function, "pause - isPlaying:", isPlaying)
    } else {
      play()
      cc.ok1(#line, #function, "play - isPlaying:", isPlaying)
    }

    // Verify that requested playback has started
    // Cancel any pending check from previous action
    pendingPlaybackCheck?.cancel()

    // Schedule timeout check - will be cancelled when playback actually starts
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      let isSpeaking = synthesizer.isSpeaking
      let isPlaying = isPlaying
      if isSpeaking, isPlaying {
        cc.ok1(#line, #function, "synthesizer started!")
      } else if isPlaying {
        // User expects playing audio
        // Alert user: Synthesizer failed to start after 5s
        cc.bad1(#line, #function, "isSpeaking:\(isSpeaking)",
                "isPlaying:\(isPlaying)")
        showSpeechErrorAlert()
      } else {
        // User expects paused audio
        cc.ok1(#line, #function, "paused OK")
      }
      isTransitioning = false
      pendingPlaybackCheck = nil
    }

    pendingPlaybackCheck = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
  }

  @MainActor
  public func play() {
    cc.ok1(#line, #function, "play() called")
    guard currentSutta != nil else {
      cc.ok1(#line, #function, "play() aborted - currentSutta is nil")
      return
    }

    // Initialize audioContext from current sutta's language
    let docLang = currentSutta?.docLang ?? "en"
    audioContext = AudioContext(for: docLang)
    cc.ok2(
      #line,
      #function,
      "audioContext initialized for docLang:",
      docLang,
      "hash:",
      audioContext?.hash ?? "nil",
    )

    // Create fresh synthesizer for each play attempt to recover from synthesis
    // failures.
    // AVFoundation initialization (~50-100ms) is slower than reusing, but
    // prevents
    // stale synthesis state from blocking playback. Mocks preserved for
    // testing.
    _ = synthesizer.stopSpeaking(at: .immediate)
    synthesizer.resetSynthesizer()
    configureAudioSession()

    isPlaying = true
    var startIndex = 0
    if let currentScid = currentSutta?.currentScid,
       let index = segments.firstIndex(where: { $0.scid == currentScid })
    {
      startIndex = index
      cc.ok2(#line, #function, "startIndex:\(startIndex)")
    } else {
      startIndex = currentSegmentIndex
      cc.ok2(#line, #function, "startIndex:\(startIndex)")
    }
    if startIndex == 0 {
      AudioEffects.shared.announce(.play)
    }
    #if os(iOS)
      UIApplication.shared.isIdleTimerDisabled = true
    #else
      // macOS: no idle timer to disable
    #endif

    playSegmentAt(at: startIndex)
    cc.ok1(#line, #function, "play() complete - isPlaying:", isPlaying)
  }

  @MainActor
  public func jumpToSegment(scid: String) {
    guard let index = segments.firstIndex(where: { $0.scid == scid })
    else { return }

    // Update the current segment
    currentSegmentIndex = index
    currentSutta?.currentScid = scid

    // Stop playback when user taps a segment
    if isPlaying {
      pause()
    }
  }

  @MainActor
  public func pause() {
    _ = synthesizer.stopSpeaking(at: .immediate)
    isPlaying = false
    isSynthesizerSpeaking = false
    // Cancel pending playback check since we're pausing
    pendingPlaybackCheck?.cancel()
    pendingPlaybackCheck = nil
    isTransitioning = false
    AudioEffects.shared.announce(.pause)
    #if os(iOS)
      UIApplication.shared.isIdleTimerDisabled = false
    #else
      // macOS: no idle timer to restore
    #endif

    cc.ok1(#line, #function, "isPlaying", isPlaying)
  }

  @MainActor
  private func showSpeechErrorAlert() {
    cc.bad2(#line, #function, "begin")
    #if os(iOS)
      let alert = UIAlertController(
        title: "Speech problems",
        message: "Close and reopen scVoice".localized,
        preferredStyle: .alert,
      )
      alert
        .addAction(UIAlertAction(title: "OK",
                                 style: .default)
        { [weak self] _ in
          self?.cc.bad2(#line, #function, "resetPlayer")
          self?.resetPlayer()
          })

      if let windowScene = UIApplication.shared.connectedScenes
        .first as? UIWindowScene,
        let window = windowScene.windows.first,
        let rootViewController = window.rootViewController
      {
        rootViewController.present(alert, animated: true)
      }
    #endif
    cc.bad1(#line, #function, "end")
  }

  /// Recovers from synthesis failures by creating a fresh synthesizer instance.
  /// Called when synthesizer fails to start speaking within 5 seconds
  /// (togglePlayback timeout).
  /// Preserves playback state (wasPlaying, currentSegmentIndex) and resumes
  /// from same position.
  /// Fresh synthesizer instance improves failure recovery (see: ~50-100ms
  /// creation cost for AVFoundation init)
  @MainActor
  private func resetPlayer() {
    cc.ok2(#line, #function)

    // Save state before reset
    let wasPlaying = isPlaying
    let playFromIndex = currentSegmentIndex
    let sutta = currentSutta

    _ = synthesizer.stopSpeaking(at: .immediate)

    // Create new synthesizer instance
    synthesizer = CachedSynthesizer()
    synthesizer.playbackDelegate = self

    // Reconfigure audio session
    configureAudioSession()

    isSynthesizerSpeaking = false

    // Resume playback if it was playing
    if wasPlaying, sutta != nil {
      cc.ok2(#line, #function, "Resuming playback from index:", playFromIndex)
      playSegmentAt(at: playFromIndex)
    }

    cc.ok1(#line, #function)
  }

  /// Orchestrates playback of segment at given index.
  /// - Validates isPlaying state and bounds
  /// - Announces section/segment boundaries (.0/.1 scid suffixes)
  /// - Handles empty segments (skips with 500ms delay)
  /// - Respects segmentPause delay between segments
  /// - Updates nextIndexToPlay before queuing synthesizer.playText() to handle
  /// user jumps
  private func playSegmentAt(at index: Int) {
    cc.ok2(#line, #function, "index:", index)

    guard isPlaying else {
      cc.ok1(#line, #function, "isPlaying:", isPlaying)
      return
    }

    guard index < segments.count else {
      isPlaying = false
      currentSegmentIndex = 0
      AudioEffects.shared.announce(.endSutta)
      #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
      #else
        // macOS: no idle timer to restore
      #endif
      cc.ok1(#line, #function, "isPlaying:", isPlaying)
      return
    }

    currentSegmentIndex = index
    let segment = segments[index]
    currentSutta?.currentScid = segment.scid
    if !Settings.shared.playDoc {
      cc.ok1(#line, #function, "!playDoc isPlaying:", isPlaying)
      return
    }

    // Announce section vs segment boundaries based on scid suffix for listener
    // clarity.
    // Suttas use scid hierarchy: chapter.0, chapter.1.1, chapter.2.1, etc.
    // scid.0 = section header, scid.1+ = actual segments with content
    if segment.scid.hasSuffix(".0") {
      AudioEffects.shared.announce(.section)
    } else if segment.scid.hasSuffix(".1") {
      AudioEffects.shared.announce(.segment)
    }

    let text = segment.doc ?? ""

    if text.isEmpty {
      AudioEffects.shared.announce(.noText)
      // Skip empty segments with 500ms delay to let user hear .noText
      // announcement
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.playSegmentAt(at: index + 1)
      }
      cc.ok1(#line, #function, "isPlaying:", isPlaying)
      return
    }

    // Set nextIndexToPlay BEFORE queuing synthesizer.playText() to handle user
    // jumps.
    // If user taps a different segment while onPlaybackFinished() callback is
    // queued,
    // playSegmentAt() updates this value, and the stale callback will use
    // updated nextIndexToPlay
    nextIndexToPlay = index + 1
    let langCode = currentSutta?.docLang ?? "en"

    // Respect segmentPause: delay playback if needed
    let now = Date()
    let delay = max(0, earliestPlaybackTime.timeIntervalSince(now))

    if delay > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.cc.ok1(#line, #function, "isPlaying:", self.isPlaying)
        self.playText(text, langCode: langCode)
      }
    } else {
      cc.ok1(#line, #function, "isPlaying:", isPlaying)
      playText(text, langCode: langCode)
    }
  }

  /// Delegate to synthesizer to play text segment using current audioContext.
  /// - audioContext contains voice, rate, pitch settings from Settings.shared
  /// - Synthesis happens inline (no prefetch strategy)
  /// - Synthesizer notifies via IPlaybackDelegate callbacks
  /// (onPlaybackStarted/Finished)
  private func playText(_ text: String, langCode _: String) {
    guard let audioContext else {
      cc.bad1(#line, #function, "audioContext not initialized")
      return
    }

    do {
      cc.ok2(
        #line,
        #function,
        "playText... isSpeaking:",
        synthesizer.isSpeaking,
      )
      try synthesizer.playText(text, audioContext: audioContext)
      cc.ok1(
        #line,
        #function,
        "playText called. isSpeaking now:",
        synthesizer.isSpeaking,
      )
    } catch {
      cc.bad1(#line, #function, error)
    }
  }

  // MARK: - IPlaybackDelegate

  public func onPlaybackStarted() {
    isSynthesizerSpeaking = true
    // Cancel pending timeout check - playback actually started
    pendingPlaybackCheck?.cancel()
    pendingPlaybackCheck = nil
    isTransitioning = false
    cc.ok1(
      #line,
      #function,
      "Playback started - isSynthesizerSpeaking:",
      isSynthesizerSpeaking,
    )
  }

  public func onPlaybackPaused() {
    isSynthesizerSpeaking = false
    cc.ok2(#line, #function, "Playback paused")
  }

  public func onPlaybackContinued() {
    isSynthesizerSpeaking = true
    cc.ok2(#line, #function, "Playback continued")
  }

  public func onPlaybackFinished() {
    isSynthesizerSpeaking = false

    // Set earliest time next segment can play (respecting segmentPause)
    if let pause = audioContext?.segmentPause {
      earliestPlaybackTime = Date().addingTimeInterval(pause)
    }

    // Play the next segment as determined by nextIndexToPlay
    // When user jumps to a different segment, playSegmentAt updates
    // nextIndexToPlay,
    // so stale callbacks will use the updated target
    if isPlaying {
      cc.ok1(#line, #function, "isPlaying:\(isPlaying)",
             "nextIndexToPlay:\(nextIndexToPlay)")
      playSegmentAt(at: nextIndexToPlay)
    } else {
      cc.ok1(#line, #function, "isPlaying=false")
    }
  }
} // SuttaPlayer
