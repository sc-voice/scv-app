import AVFoundation
import Foundation
import scvCore

#if os(iOS)
  import UIKit
#else
  // macOS: UIKit not available
#endif

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
  private var segments: [Segment] = []
  private var currentSegmentIndex = 0
  private var nextIndexToPlay = 0
  private var isTransitioning = false
  private var pendingPlaybackCheck: DispatchWorkItem?
  private var earliestPlaybackTime: Date = Date()

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
      let isSpeaking = self.synthesizer.isSpeaking
      let isPlaying = self.isPlaying
      if isSpeaking, isPlaying {
        self.cc.ok1(#line, #function, "synthesizer started!")
      } else if isPlaying {
        // User expects playing audio
        // Alert user: Synthesizer failed to start after 5s
        self.cc.bad1(#line, #function, "isSpeaking:\(isSpeaking)",
                     "isPlaying:\(isPlaying)")
        self.showSpeechErrorAlert()
      } else {
        // User expects paused audio
        self.cc.ok1(#line, #function, "paused OK")
      }
      self.isTransitioning = false
      self.pendingPlaybackCheck = nil
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

    // Create fresh synthesizer for each play attempt (but preserve mocks for
    // testing)
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
      alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
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

    // Announce section boundary (scid ending in .1)
    if segment.scid.hasSuffix(".0") {
      AudioEffects.shared.announce(.section)
    } else if segment.scid.hasSuffix(".1") {
      AudioEffects.shared.announce(.segment)
    }

    let text = segment.doc ?? ""

    if text.isEmpty {
      AudioEffects.shared.announce(.noText)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.playSegmentAt(at: index + 1)
      }
      cc.ok1(#line, #function, "isPlaying:", isPlaying)
      return
    }

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
