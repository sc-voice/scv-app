import AVFoundation

/// Simple playback event protocol independent of AVFoundation types
/// Enables multiple audio sources (live synthesis, cached audio) to emit
/// identical events
@MainActor
protocol IPlaybackDelegate {
  /// Playback started
  func onPlaybackStarted()

  /// Playback paused
  func onPlaybackPaused()

  /// Playback resumed from pause
  func onPlaybackContinued()

  /// Playback finished (segment complete)
  func onPlaybackFinished()
}

/// Protocol abstracting AVSpeechSynthesizer for dependency injection and
/// testing.
/// Enables SuttaPlayer to accept mocked synthesizers in tests while using real
/// AVSpeechSynthesizer in production.
protocol ISpeechSynthesizer {
  /// Whether the synthesizer is currently speaking
  var isSpeaking: Bool { get }

  /// Playback event listener (simplified, AVFoundation-independent)
  var playbackDelegate: IPlaybackDelegate? { get set }

  /// The delegate that receives speech synthesis callbacks (internal,
  /// AVFoundation-specific)
  var delegate: AVSpeechSynthesizerDelegate? { get set }

  /// Stop speaking at the specified boundary
  func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool

  /// High-level playback: configure and speak utterance from text and audio
  /// settings
  /// Abstracts away AVSpeechUtterance creation and voice/pitch/rate
  /// configuration.
  /// Behaves like speak() — returns immediately, playback happens async with
  /// delegate callbacks.
  /// - Parameters:
  ///   - text: Text to synthesize and play
  ///   - audioContext: Voice settings (language, voiceId, pitch, rate, pauses)
  /// - Throws: On synthesis or playback errors
  func playText(_ text: String, audioContext: AudioContext) throws
}

/// Concrete implementation of ISpeechSynthesizer wrapping AVSpeechSynthesizer
/// Translates AVSpeechSynthesizerDelegate callbacks to IPlaybackDelegate events
final class SpeechSynthesizerImpl: NSObject, ISpeechSynthesizer,
  AVSpeechSynthesizerDelegate
{
  private let innerSynthesizer = AVSpeechSynthesizer()
  var playbackDelegate: IPlaybackDelegate?

  override init() {
    super.init()
    innerSynthesizer.delegate = self
  }

  var isSpeaking: Bool {
    innerSynthesizer.isSpeaking
  }

  var delegate: AVSpeechSynthesizerDelegate? {
    get { innerSynthesizer.delegate }
    set { innerSynthesizer.delegate = newValue }
  }

  private func speak(_ utterance: AVSpeechUtterance) throws {
    innerSynthesizer.speak(utterance)
  }

  func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
    innerSynthesizer.stopSpeaking(at: boundary)
  }

  func playText(_ text: String, audioContext: AudioContext) throws {
    let utterance = AVSpeechUtterance(string: text)

    // Get docLangSettings for the specified language
    let docLang = ScvLanguage(code: audioContext.docLang) ?? .english
    let docLangSettings = Settings.shared.docLangSettings[docLang]
      ?? LangSettings(language: docLang)

    // Set voice from docLangSettings.voiceId if available
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

    try speak(utterance)
  }

  // MARK: - AVSpeechSynthesizerDelegate (translate to IPlaybackDelegate)

  nonisolated func speechSynthesizer(
    _: AVSpeechSynthesizer,
    didStart _: AVSpeechUtterance,
  ) {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackStarted()
    }
  }

  nonisolated func speechSynthesizer(
    _: AVSpeechSynthesizer,
    didPause _: AVSpeechUtterance,
  ) {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackPaused()
    }
  }

  nonisolated func speechSynthesizer(
    _: AVSpeechSynthesizer,
    didContinue _: AVSpeechUtterance,
  ) {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackContinued()
    }
  }

  nonisolated func speechSynthesizer(
    _: AVSpeechSynthesizer,
    didFinish _: AVSpeechUtterance,
  ) {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackFinished()
    }
  }
}
