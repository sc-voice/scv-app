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
  AVSpeechSynthesizerDelegate
{
  let cc = ColorConsole(#file, #function, dbg.SuttaPlayer.other)
  public static let shared = SuttaPlayer()

  @Published public var isPlaying = false
  @Published public var currentSutta: MLDocument?

  private var synthesizer: ISpeechSynthesizer
  private var segments: [(key: String, value: Segment)] = []
  private var currentSegmentIndex = 0
  private var nextIndexToPlay = 0
  private var isTransitioning = false

  init(synthesizer: ISpeechSynthesizer = AVSpeechSynthesizer()) {
    self.synthesizer = synthesizer
    super.init()
    cc.ok2(#line, "init() starting")
    configureAudioSession()
    self.synthesizer.delegate = self
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
    synthesizer.stopSpeaking(at: .immediate)
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

    // Clear transition lock after 500ms to allow next action
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      if !self.synthesizer.isSpeaking, self.isPlaying {
        self.cc.bad1(
          #line,
          #function,
          "Synthesizer failed to start after 500ms - pausing",
        )
        self.pause()
      }
      self.isTransitioning = false
    }
  }

  @MainActor
  public func play() {
    cc.ok1(#line, #function, "play() called")
    guard currentSutta != nil else {
      cc.ok1(#line, #function, "play() aborted - currentSutta is nil")
      return
    }
    isPlaying = true
    AudioEffects.shared.announce(.play)
    #if os(iOS)
      UIApplication.shared.isIdleTimerDisabled = true
    #else
      // macOS: no idle timer to disable
    #endif

    // Start playback at currentScid if set, otherwise use currentSegmentIndex
    if let currentScid = currentSutta?.currentScid,
       let index = segments.firstIndex(where: { $0.key == currentScid })
    {
      cc.ok1(#line, #function, "playing from currentScid:", currentScid)
      playSegmentAt(at: index)
    } else {
      cc.ok1(
        #line,
        #function,
        "playing from currentSegmentIndex:",
        currentSegmentIndex,
      )
      playSegmentAt(at: currentSegmentIndex)
    }
    cc.ok1(#line, #function, "play() complete - isPlaying:", isPlaying)
  }

  @MainActor
  public func jumpToSegment(scid: String) {
    guard let index = segments.firstIndex(where: { $0.key == scid })
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
    synthesizer.stopSpeaking(at: .immediate)
    isPlaying = false
    AudioEffects.shared.announce(.pause)
    #if os(iOS)
      UIApplication.shared.isIdleTimerDisabled = false
    #else
      // macOS: no idle timer to restore
    #endif

    cc.ok1(#line, #function, "isPlaying", isPlaying)
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
    let (scid, segment) = segments[index]
    currentSutta?.currentScid = scid
    if !Settings.shared.playDoc {
      cc.ok1(#line, #function, "!playDoc isPlaying:", isPlaying)
      return
    }

    // Announce section boundary (scid ending in .1)
    if scid.hasSuffix(".0") {
      AudioEffects.shared.announce(.section)
    } else if scid.hasSuffix(".1") {
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
    playText(text, langCode: langCode)
    cc.ok1(#line, #function, "isPlaying:", isPlaying)
  }

  private func playText(_ text: String, langCode: String) {
    let utterance = AVSpeechUtterance(string: text)

    // Get docLangSettings for the specified language
    let docLang = ScvLanguage(code: langCode) ?? .english
    let docLangSettings = Settings.shared
      .docLangSettings[docLang]
      ?? LangSettings(language: docLang)

    // Set voice from docLangSettings.voiceId if available, otherwise find
    // best available voice for language
    if !docLangSettings.voiceId.isEmpty {
      utterance
        .voice = AVSpeechSynthesisVoice(identifier: docLangSettings.voiceId)
    } else {
      // Find best available voice: enhanced/premium > default
      let voices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language == docLangSettings.language.code }
        .sorted { $0.quality.rawValue > $1.quality.rawValue }
      utterance.voice = voices.first
        ?? AVSpeechSynthesisVoice(language: docLangSettings.language.code)
    }

    // Apply speech configuration settings
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * docLangSettings.rate
    utterance.pitchMultiplier = docLangSettings.pitch
    let segmentPause = Settings.shared.segmentPause
    utterance.preUtteranceDelay = segmentPause
    utterance.postUtteranceDelay = segmentPause

    do {
      cc.ok2(#line, #function, "speak... isSpeaking:", synthesizer.isSpeaking)
      try synthesizer.speak(utterance)
      cc.ok1(
        #line,
        #function,
        "speak called. isSpeaking now:",
        synthesizer.isSpeaking,
      )
    } catch {
      cc.bad1(#line, #function, error)
    }
  }

  // MARK: - AVSpeechSynthesizerDelegate

  public nonisolated func speechSynthesizer(
    _: AVSpeechSynthesizer,
    didFinish _: AVSpeechUtterance,
  ) {
    Task { @MainActor in
      // Play the next segment as determined by nextIndexToPlay
      // When user jumps to a different segment, playSegmentAt updates
      // nextIndexToPlay,
      // so stale callbacks will use the updated target
      self.cc.ok1(
        #line,
        #function,
        "didFinish callback - isPlaying:",
        self.isPlaying,
        "nextIndexToPlay:",
        self.nextIndexToPlay,
      )
      if self.isPlaying {
        self.playSegmentAt(at: self.nextIndexToPlay)
      } else {
        self.cc.ok1(
          #line,
          #function,
          "didFinish but isPlaying=false, not continuing",
        )
      }
    }
  }
}
