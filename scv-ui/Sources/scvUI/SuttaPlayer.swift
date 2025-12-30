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

  private let synthesizer = AVSpeechSynthesizer()
  private var segments: [(key: String, value: Segment)] = []
  private var currentSegmentIndex = 0
  private var nextIndexToPlay = 0

  override init() {
    super.init()
    cc.ok2(#line, "init() starting")
    configureAudioSession()
    synthesizer.delegate = self
    cc.ok2(#line, "init() complete")
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

  public func load(_ sutta: MLDocument) {
    synthesizer.stopSpeaking(at: .immediate)
    currentSutta = sutta
    segments = sutta.segments()
    currentSegmentIndex = 0
    isPlaying = false
  }

  public func togglePlayback() {
    guard currentSutta != nil else { return }

    if isPlaying {
      pause()
    } else {
      play()
    }
  }

  public func play() {
    guard currentSutta != nil else { return }
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
      playSegmentAt(at: index)
    } else {
      playSegmentAt(at: currentSegmentIndex)
    }
  }

  public func jumpToSegment(scid: String) {
    guard let index = segments.firstIndex(where: { $0.key == scid })
    else { return }
    if isPlaying {
      nextIndexToPlay = index
      synthesizer.stopSpeaking(at: .immediate)
    } else {
      currentSegmentIndex = index
      currentSutta?.currentScid = scid
    }
  }

  public func pause() {
    synthesizer.stopSpeaking(at: .immediate)
    isPlaying = false
    AudioEffects.shared.announce(.pause)
    #if os(iOS)
      UIApplication.shared.isIdleTimerDisabled = false
    #else
      // macOS: no idle timer to restore
    #endif
  }

  private func playSegmentAt(at index: Int) {
    guard index < segments.count else {
      isPlaying = false
      currentSegmentIndex = 0
      AudioEffects.shared.announce(.endSutta)
      #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
      #else
        // macOS: no idle timer to restore
      #endif
      return
    }

    currentSegmentIndex = index
    let (scid, segment) = segments[index]
    currentSutta?.currentScid = scid
    if !Settings.shared.playDoc {
      cc.ok1(#line, #function, "!playDoc")
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
      playSegmentAt(at: index + 1)
      return
    }

    nextIndexToPlay = index + 1
    let langCode = currentSutta?.docLang ?? "en"
    playText(text, langCode: langCode)
  }

  private func playText(_ text: String, langCode: String) {
    let utterance = AVSpeechUtterance(string: text)

    // Get docLangSettings for the specified language
    let docLang = ScvLanguage(code: langCode) ?? .english
    let docLangSettings = Settings.shared
      .docLangSettings[docLang]
      ?? LangSettings(language: docLang)

    // Set voice from docLangSettings.voiceId if available, otherwise use language code
    if !docLangSettings.voiceId.isEmpty {
      utterance.voice = AVSpeechSynthesisVoice(identifier: docLangSettings.voiceId)
    } else {
      utterance.voice = AVSpeechSynthesisVoice(language: docLangSettings.language.code)
    }

    // Apply speech configuration settings
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * docLangSettings.rate
    utterance.pitchMultiplier = docLangSettings.pitch
    let segmentPause = Settings.shared.segmentPause
    utterance.preUtteranceDelay = segmentPause
    utterance.postUtteranceDelay = segmentPause

    synthesizer.speak(utterance)
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
      if self.isPlaying {
        self.playSegmentAt(at: self.nextIndexToPlay)
      }
    }
  }
}
