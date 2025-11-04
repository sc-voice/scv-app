//
//  Settings.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import Foundation

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
  /// nonisolated(unsafe): singleton initialized once, safe to access from any thread
  nonisolated(unsafe) public static let shared = Settings()

  /// Current schema version (bumped when format changes incompatibly)
  public static let currentVersion: Int = 1

  // MARK: - Instance Properties

  /// Schema version of this settings instance
  public var version: Int = 1

  /// Currently selected voice document language
  public var docLang: ScvLanguage = .default

  /// Currently selected voice reference language
  public var refLang: ScvLanguage = .default

  /// Currently selected voice ui language
  public var uiLang: ScvLanguage = .default

  /// Narration voice configuration for pali
  public var paliSpeech: SpeechConfig = SpeechConfig(language: .default)

  /// Narration voice configuration for translations
  public var docSpeech: SpeechConfig = SpeechConfig(language: .default)

  /// Whether dark mode is enabled
  public var isDarkModeEnabled: Bool = true

  /// Application version when last run
  public var lastApplicationVersion: String = ""

  // MARK: - Private Initialization

  private init() {
    load()
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
    try container.encode(lastApplicationVersion, forKey: .lastApplicationVersion)
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode version (defaults to 1 for backwards compatibility with v0 serialized data)
    let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    self.version = decodedVersion

    // Handle version-specific migrations here if needed in the future
    switch decodedVersion {
    case 1:
      // Current version: standard decoding
      let docLangCode = try container.decodeIfPresent(String.self, forKey: .docLang) ?? "en"
      self.docLang = ScvLanguage(code: docLangCode) ?? .default
      let refLangCode = try container.decodeIfPresent(String.self, forKey: .refLang) ?? "en"
      self.refLang = ScvLanguage(code: refLangCode) ?? .default
      let uiLangCode = try container.decodeIfPresent(String.self, forKey: .uiLang) ?? "en"
      self.uiLang = ScvLanguage(code: uiLangCode) ?? .default
      self.paliSpeech = try container.decodeIfPresent(SpeechConfig.self, forKey: .paliSpeech) ?? SpeechConfig(language: .default)
      self.docSpeech = try container.decodeIfPresent(SpeechConfig.self, forKey: .docSpeech) ?? SpeechConfig(language: .default)
      self.isDarkModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDarkModeEnabled) ?? false
      self.lastApplicationVersion = try container.decodeIfPresent(String.self, forKey: .lastApplicationVersion) ?? ""
    default:
      // Unknown version: reset to defaults
      self.docLang = .default
      self.refLang = .default
      self.uiLang = .default
      self.paliSpeech = SpeechConfig(language: .default)
      self.docSpeech = SpeechConfig(language: .default)
      self.isDarkModeEnabled = false
      self.lastApplicationVersion = ""
    }
  }

  // MARK: - Persistence

  /// Saves settings to UserDefaults
  public func save() {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      UserDefaults.standard.set(encoded, forKey: "com.scv.settings")
    }
  }

  /// Loads settings from UserDefaults
  private func load() {
    guard let data = UserDefaults.standard.data(forKey: "com.scv.settings") else {
      return
    }

    let decoder = JSONDecoder()
    if let decoded = try? decoder.decode(Settings.self, from: data) {
      self.version = decoded.version
      self.docLang = decoded.docLang
      self.refLang = decoded.refLang
      self.uiLang = decoded.uiLang
      self.paliSpeech = decoded.paliSpeech
      self.docSpeech = decoded.docSpeech
      self.isDarkModeEnabled = decoded.isDarkModeEnabled
      self.lastApplicationVersion = decoded.lastApplicationVersion
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
    UserDefaults.standard.removeObject(forKey: "com.scv.settings")
  }
}
