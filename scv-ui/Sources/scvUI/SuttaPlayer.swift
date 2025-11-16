import AVFoundation
import Foundation
import scvCore
import UIKit

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
    UIApplication.shared.isIdleTimerDisabled = true

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
    UIApplication.shared.isIdleTimerDisabled = false
  }

  private func playSegmentAt(at index: Int) {
    guard index < segments.count else {
      isPlaying = false
      currentSegmentIndex = 0
      UIApplication.shared.isIdleTimerDisabled = false
      return
    }

    currentSegmentIndex = index
    let (scid, segment) = segments[index]
    currentSutta?.currentScid = scid
    let text = getSegmentText(segment)

    guard !text.isEmpty else {
      // Skip segment, advance to next
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.playSegmentAt(at: index + 1)
      }
      return
    }

    let utterance = AVSpeechUtterance(string: text)

    // Use docSpeech configuration from Settings
    let docSpeech = Settings.shared.docSpeech

    // Set voice from docSpeech.voiceId if available, otherwise use language
    // code
    if !docSpeech.voiceId.isEmpty {
      utterance.voice = AVSpeechSynthesisVoice(identifier: docSpeech.voiceId)
    } else {
      // Fallback to language-based voice selection
      let languageCode = docSpeech.language.code
      utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
    }

    // Apply speech configuration settings
    // AVSpeechUtterance uses rate 0.0-1.0 with 0.5 as default (normal speed)
    // docSpeech.rate is 0.1-2.0 multiplier, so scale it: 1.0 -> 0.5 (normal)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * docSpeech.rate
    utterance.pitchMultiplier = docSpeech.pitch

    nextIndexToPlay = index + 1
    synthesizer.speak(utterance)
  }

  private func getSegmentText(_ segment: Segment) -> String {
    // Query settings at point of need
    let playPali = UserDefaults.standard.bool(forKey: "playPali")
    let playEnglish = UserDefaults.standard.bool(forKey: "playEnglish")

    if playPali, !(segment.pli?.isEmpty ?? true) {
      return segment.pli!
    }
    if playEnglish, !(segment.doc?.isEmpty ?? true) {
      return segment.doc!
    }

    // Fallback to doc, then pli
    return (segment.doc?.isEmpty ?? true) ? (segment.pli ?? "") : segment.doc!
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
