import AVFoundation

/// Protocol abstracting AVSpeechSynthesizer for dependency injection and
/// testing.
/// Enables SuttaPlayer to accept mocked synthesizers in tests while using real
/// AVSpeechSynthesizer in production.
protocol ISpeechSynthesizer {
  /// Whether the synthesizer is currently speaking
  var isSpeaking: Bool { get }

  /// The delegate that receives speech synthesis callbacks
  var delegate: AVSpeechSynthesizerDelegate? { get set }

  /// Speak the given utterance
  func speak(_ utterance: AVSpeechUtterance) throws

  /// Stop speaking at the specified boundary
  func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool
}

/// Make AVSpeechSynthesizer conform to ISpeechSynthesizer
extension AVSpeechSynthesizer: ISpeechSynthesizer {
  // No additional implementation needed - AVSpeechSynthesizer already has
  // the exact method signature required by the protocol
}
