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

  /// Deterministic 32-character hex MD5 hash of audio context.
  ///
  /// Hash changes when any speech synthesis setting changes, indicating cached audio
  /// is stale. Used as cache key for audio files.
  /// Not included in Codable encoding/decoding; recomputed on deserialization.
  public let hash: String

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case docLang
    case voiceId
    case pitch
    case rate
    case segmentPause
    // hash is excluded - computed from other fields
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.docLang = try container.decode(String.self, forKey: .docLang)
    self.voiceId = try container.decode(String.self, forKey: .voiceId)
    self.pitch = try container.decode(Float.self, forKey: .pitch)
    self.rate = try container.decode(Float.self, forKey: .rate)
    self.segmentPause = try container.decode(Double.self, forKey: .segmentPause)

    // Recompute hash from decoded values
    let mj = MerkleJson()
    let dict: [String: Any] = [
      "docLang": docLang,
      "voiceId": voiceId,
      "pitch": pitch,
      "rate": rate,
      "segmentPause": segmentPause,
    ]
    self.hash = mj.hash(dict)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(docLang, forKey: .docLang)
    try container.encode(voiceId, forKey: .voiceId)
    try container.encode(pitch, forKey: .pitch)
    try container.encode(rate, forKey: .rate)
    try container.encode(segmentPause, forKey: .segmentPause)
    // hash is not encoded - recomputed on decode
  }

  /// Create AudioContext from document language and settings.
  ///
  /// - Parameters:
  ///   - docLang: Document language code (e.g., "en", "de")
  ///   - settings: Settings instance (defaults to Settings.shared). Provide custom
  ///     Settings for testing.
  ///
  /// The voiceId is resolved to the actual system default if user selected "Default".
  /// The hash property is computed and stored at initialization.
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

    // Compute and store hash at initialization
    let mj = MerkleJson()
    let dict: [String: Any] = [
      "docLang": docLang,
      "voiceId": self.voiceId,
      "pitch": self.pitch,
      "rate": self.rate,
      "segmentPause": self.segmentPause,
    ]
    self.hash = mj.hash(dict)
  }

  /// Compute deterministic hash of audio context using MerkleJson.
  ///
  /// Hash changes when any speech synthesis setting changes, indicating cached audio
  /// is stale. Used as cache key for audio files.
  ///
  /// - Returns: 32-character hex MD5 hash
  public func computeHash() -> String {
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
