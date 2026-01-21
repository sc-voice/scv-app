import AVFoundation
import Foundation

/// AudioContext captures all speech synthesis settings that affect audio output.
///
/// Used as a cache key to detect when settings change, invalidating cached audio files.
/// When user changes voice, pitch, rate, or segment pause, the hash changes, indicating
/// cached audio is stale.
///
/// The voiceId is always resolved to the actual AVSpeechSynthesisVoice identifier:
/// - If user selected explicit voice: stores that voice's identifier
/// - If user selected "Default": resolves and stores the system default voice ID
///
/// This ensures we detect if the system default voice changes between cache creation
/// and later playback.
public struct AudioContext: Codable, Hashable, Sendable {
  /// Document language code (e.g., "en", "de", "pli")
  public let docLang: String

  /// AVSpeechSynthesisVoice identifier (never empty - always resolved to actual voice)
  public let voiceId: String

  /// Voice pitch multiplier (0.5 to 2.0, default 1.0)
  public let pitch: Float

  /// Voice rate multiplier (0.1 to 2.0, default 1.0)
  public let rate: Float

  /// Segment pause duration in seconds (pre/post utterance delays)
  public let segmentPause: Double

  /// Create AudioContext from document language and settings.
  ///
  /// - Parameters:
  ///   - docLang: Document language code (e.g., "en", "de")
  ///   - settings: Settings instance (defaults to Settings.shared). Provide custom
  ///     Settings for testing.
  ///
  /// The voiceId is resolved to the actual system default if user selected "Default".
  public init(for docLang: String, from settings: Settings = Settings.shared) {
    self.docLang = docLang

    let langCode = ScvLanguage(code: docLang) ?? .english
    let langSettings = settings.docLangSettings[langCode]
      ?? LangSettings(language: langCode)

    // Resolve voiceId: if empty (Default), capture actual default voice ID
    if !langSettings.voiceId.isEmpty {
      self.voiceId = langSettings.voiceId
    } else {
      let defaultVoice = AVSpeechSynthesisVoice(language: langCode.code)
      self.voiceId = defaultVoice?.identifier ?? ""
    }

    self.pitch = langSettings.pitch
    self.rate = langSettings.rate
    self.segmentPause = settings.segmentPause
  }

  /// Compute deterministic hash of audio context using MerkleJson.
  ///
  /// Hash changes when any speech synthesis setting changes, indicating cached audio
  /// is stale. Used as cache key for audio files.
  ///
  /// - Returns: 32-character hex MD5 hash
  public func hash() -> String {
    let mj = MerkleJson()
    let dict: [String: Any] = [
      "docLang": docLang,
      "voiceId": voiceId,
      "pitch": pitch,
      "rate": rate,
      "segmentPause": segmentPause,
    ]
    return mj.hash(dict)
  }
}
