//
//  Settings.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import AVFoundation
import Foundation

// MARK: - Constants

let MAX_DOC_DEFAULT = 50

// MARK: - SpeechConfig

/// Configuration for speech synthesis (narration and accessibility voices)
public struct SpeechConfig: Codable, Sendable {
  /// Language for the voice
  public var language: ScvLanguage

  /// Apple voice identifier (e.g., "com.apple.ttsbundle.Samantha-compact")
  public var voiceId: String = ""

  /// Display name of the voice (e.g., "Samantha", "Daniel")
  public var voiceName: String = ""

  /// Voice variant (e.g., "default", "premium", "slow")
  public var variant: String = "default"

  /// Voice pitch multiplier (0.5 to 2.0, default 1.0)
  public var pitch: Float = 1.0

  /// Voice rate multiplier (0.1 to 2.0, default 1.0)
  public var rate: Float = 1.0

  /// Whether to use emphasis in speech
  public var emphasis: Bool = true

  /// Initialize with language
  public init(language: ScvLanguage) {
    self.language = language
  }
}

// MARK: - Settings Singleton

/// Serialized singleton for application settings with UserDefaults persistence
public class Settings: Codable {
  // MARK: - Static Properties

  /// Shared singleton instance
  /// nonisolated(unsafe): singleton initialized once, safe to access from any
  /// thread
  public nonisolated(unsafe) static let shared = Settings()

  /// Current schema version (bumped when format changes incompatibly)
  public static let currentVersion: Int = 1

  // MARK: - Instance Properties

  let cc = ColorConsole(#file, #function)

  /// Flag to prevent validation during initialization and deserialization
  private var isInitializing: Bool = true

  /// Schema version of this settings instance
  public var version: Int = 1

  /// Currently selected voice document language
  public var docLang: ScvLanguage = .default

  /// Currently selected voice reference language
  public var refLang: ScvLanguage = .default

  /// Currently selected voice ui language
  public var uiLang: ScvLanguage = .default

  /// Narration voice configuration for pali
  public var paliSpeech: SpeechConfig = .init(language: .default)

  /// Narration voice configuration for translations
  public var docSpeech: SpeechConfig = .init(language: .default)

  /// Whether dark mode is enabled
  public var isDarkModeEnabled: Bool = true

  /// Application version when last run
  public var lastApplicationVersion: String = ""

  /// Maximum number of documents to return in search results
  public var maxDoc: Int = MAX_DOC_DEFAULT

  // MARK: - Private Initialization

  private init() {
    load()
    isInitializing = false
    validate()
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case version
    case docLang
    case refLang
    case uiLang
    case paliSpeech
    case docSpeech
    case isDarkModeEnabled
    case lastApplicationVersion
    case maxDoc
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(docLang, forKey: .docLang)
    try container.encode(refLang, forKey: .refLang)
    try container.encode(uiLang, forKey: .uiLang)
    try container.encode(paliSpeech, forKey: .paliSpeech)
    try container.encode(docSpeech, forKey: .docSpeech)
    try container.encode(isDarkModeEnabled, forKey: .isDarkModeEnabled)
    try container.encode(
      lastApplicationVersion,
      forKey: .lastApplicationVersion,
    )
    try container.encode(maxDoc, forKey: .maxDoc)
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode version (defaults to 1 for backwards compatibility with v0
    // serialized data)
    let decodedVersion = try container.decodeIfPresent(
      Int.self,
      forKey: .version,
    ) ?? 1
    version = decodedVersion

    // Handle version-specific migrations here if needed in the future
    switch decodedVersion {
    case 1:
      // Current version: standard decoding
      let docLangCode = try container.decodeIfPresent(
        String.self,
        forKey: .docLang,
      ) ?? "en"
      docLang = ScvLanguage(code: docLangCode) ?? .default
      let refLangCode = try container.decodeIfPresent(
        String.self,
        forKey: .refLang,
      ) ?? "en"
      refLang = ScvLanguage(code: refLangCode) ?? .default
      let uiLangCode = try container.decodeIfPresent(
        String.self,
        forKey: .uiLang,
      ) ?? "en"
      uiLang = ScvLanguage(code: uiLangCode) ?? .default
      paliSpeech = try container.decodeIfPresent(
        SpeechConfig.self,
        forKey: .paliSpeech,
      ) ?? SpeechConfig(language: .default)
      docSpeech = try container.decodeIfPresent(
        SpeechConfig.self,
        forKey: .docSpeech,
      ) ?? SpeechConfig(language: .default)
      isDarkModeEnabled = try container.decodeIfPresent(
        Bool.self,
        forKey: .isDarkModeEnabled,
      ) ?? false
      lastApplicationVersion = try container.decodeIfPresent(
        String.self,
        forKey: .lastApplicationVersion,
      ) ?? ""
      maxDoc = try container
        .decodeIfPresent(Int.self, forKey: .maxDoc) ?? MAX_DOC_DEFAULT
    default:
      // Unknown version: reset to defaults
      docLang = .default
      refLang = .default
      uiLang = .default
      paliSpeech = SpeechConfig(language: .default)
      docSpeech = SpeechConfig(language: .default)
      isDarkModeEnabled = false
      lastApplicationVersion = ""
      maxDoc = MAX_DOC_DEFAULT
    }

    isInitializing = false
    validate()
  }

  // MARK: - Validation

  /// Finds an available Apple voice for a given language
  /// - Parameter language: The language to find a voice for
  /// - Returns: An AVSpeechSynthesisVoice if available, nil otherwise
  private func findVoice(for language: ScvLanguage) -> AVSpeechSynthesisVoice? {
    let allVoices = AVSpeechSynthesisVoice.speechVoices()
    let languageCode = language.code

    // Filter voices by language and exclude denied voices
    let availableVoices = allVoices.filter { voice in
      voice.language.hasPrefix(languageCode) && !ScvLanguage
        .isVoiceDenied(voice.name)
    }

    return availableVoices.first
  }

  /// Validates and synchronizes settings to maintain consistency
  /// Ensures docSpeech.language matches docLang with an actual Apple voice
  /// Falls back to .english if no voice available for docLang
  public func validate() {
    let startTime = CFAbsoluteTimeGetCurrent()

    // Check if docSpeech language matches docLang
    if docSpeech.language != docLang {
      // Try to find a voice for docLang
      if let voice = findVoice(for: docLang) {
        // Update docSpeech to match docLang with actual voice
        var newConfig = SpeechConfig(language: docLang)
        newConfig.voiceId = voice.identifier
        newConfig.voiceName = voice.name
        docSpeech = newConfig
      } else {
        // No voice available for docLang, fallback to English
        docLang = .english
        validate() // Revalidate with new docLang
      }
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    cc.ok2(#line, "validate() elapsed: \(String(format: "%.2f", elapsed)) ms")
  }

  // MARK: - Persistence

  /// Saves settings to UserDefaults
  public func save() {
    validate()
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      UserDefaults.standard.set(encoded, forKey: "com.scv.settings")
    }
  }

  /// Loads settings from UserDefaults
  private func load() {
    guard let data = UserDefaults.standard.data(forKey: "com.scv.settings")
    else {
      return
    }

    let decoder = JSONDecoder()
    if let decoded = try? decoder.decode(Settings.self, from: data) {
      version = decoded.version
      docLang = decoded.docLang
      refLang = decoded.refLang
      uiLang = decoded.uiLang
      paliSpeech = decoded.paliSpeech
      docSpeech = decoded.docSpeech
      isDarkModeEnabled = decoded.isDarkModeEnabled
      lastApplicationVersion = decoded.lastApplicationVersion
    }
  }

  /// Clears all settings and restores defaults
  public func reset() {
    version = 1
    docLang = .default
    refLang = .default
    uiLang = .default
    paliSpeech = SpeechConfig(language: .default)
    docSpeech = SpeechConfig(language: .default)
    isDarkModeEnabled = false
    lastApplicationVersion = ""
    maxDoc = MAX_DOC_DEFAULT
    UserDefaults.standard.removeObject(forKey: "com.scv.settings")
  }
}
