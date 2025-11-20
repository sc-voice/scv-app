//
//  ScvLanguages.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import Foundation

// MARK: - ScvLanguage Enum

/// Supported languages for the SC Voice application
public enum ScvLanguage: String, CaseIterable, Codable, Sendable {
  /// Planned user interface languages
  case pli
  case english = "en"
  case portuguese = "pt"
  case spanish = "es"
  case french = "fr"
  case german = "de"
  case russian = "ru"
  case italian = "it"

  // MARK: - Properties

  /// Localized display name for the language
  public var displayName: String {
    "\(code.uppercased()) / \(nativeName)"
  }

  /// Native name of the language
  public var nativeName: String {
    switch self {
    case .english:
      "English"
    case .portuguese:
      "Português"
    case .spanish:
      "Español"
    case .french:
      "Français"
    case .german:
      "Deutsch"
    case .pli:
      "Pali"
    case .russian:
      "Русский"
    case .italian:
      "Italiano"
    }
  }

  /// ISO 639-1 language code
  public var code: String {
    rawValue
  }

  // MARK: - Initialization

  /// Creates a language from an ISO 639-1 code
  public init?(code: String) {
    self.init(rawValue: code)
  }

  /// Converts BCP 47 language tag to supported voice language
  /// Extracts ISO 639-1 code from BCP 47 format (e.g., "en-US" -> "en", "de-AT"
  /// -> "de")
  /// Maps to the base supported language or nil if unsupported
  /// - Parameter bcp47Tag: BCP 47 language tag (e.g., "en", "en-US", "de-AT",
  /// "pt-PT")
  /// - Returns: Base supported voice language or nil if not supported
  public static func toVoiceLanguage(_ bcp47Tag: String) -> ScvLanguage? {
    // Extract language code (first part before hyphen)
    let languageCode = bcp47Tag.split(separator: "-").first
      .map(String.init) ?? bcp47Tag

    // Check if it's a supported voice language by code
    if let language = ScvLanguage(code: languageCode),
       voiceLanguages.contains(language)
    {
      return language
    }

    // Special case: "pi" (ISO 639-1) maps to .pli (ISO 639-2/T)
    if languageCode == "pi", voiceLanguages.contains(.pli) {
      return .pli
    }

    // Return nil if language is not supported (don't fallback to default)
    return nil
  }

  /// Default language
  public static let `default`: ScvLanguage = .english

  /// Supported narration languages
  public static let voiceLanguages: [ScvLanguage] = [.english, .german, .pli]

  /// Supported user-interface languages
  public static let uiLanguages: [ScvLanguage] = [.english, .german, .french]

  /// Novelty voices to exclude from narration voice selection
  /// These voices are designed for entertainment and are unsuitable for serious
  /// content like sutta reading
  public static let voiceDenyList: Set<String> = [
    "Bahh",
    "Boing",
    "Cellos",
    "Bubbles",
    "Pipe Organ",
    "Bad News",
    "Good News",
    "Deranged",
    "Ellen",
    "Hysterical",
    "Jester",
    "Princess",
    "Tarik",
    "Veena",
  ]

  /// Check if a voice name is in the deny list (case-insensitive)
  /// - Parameter voiceName: The voice name to check
  /// - Returns: true if the voice is in the deny list
  public static func isVoiceDenied(_ voiceName: String) -> Bool {
    voiceDenyList.contains { denyedVoice in
      voiceName.localizedCaseInsensitiveCompare(denyedVoice) == .orderedSame
    }
  }
}
