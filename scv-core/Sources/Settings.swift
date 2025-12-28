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
public let SEGMENT_PAUSE_DEFAULT = 0.5
public let SOUND_EFFECT_VOLUME_DEFAULT: Float = 0.5

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

  let cc = ColorConsole(#file, #function, dbg.Settings.other)

  /// Schema version of this settings instance
  public var version: Int = 1

  /// UserDefaults instance for persistence (injected for testing, defaults to
  /// standard if nil)
  private let userDefaults: UserDefaults?

  /// Currently selected voice document language
  public var docLang: ScvLanguage = .default

  /// Currently selected voice reference language
  public var refLang: ScvLanguage = .default

  /// Document author (translator) for docLang search results
  public var docAuthor: String = ""

  /// Reference author for refLang search results (typically "ms" for pali)
  public var refAuthor: String? = nil

  /// Narration voice configuration for pali
  public var paliSpeech: SpeechConfig = .init(language: .default)

  /// Narration voice configuration for translations
  public var docSpeech: SpeechConfig = .init(language: .default)

  /// Whether dark mode is enabled
  public var isDarkModeEnabled: Bool = true

  /// Pause between segments during playback (in seconds)
  public var segmentPause: Double = SEGMENT_PAUSE_DEFAULT

  /// Whether to play Pali text during narration
  public var playPali: Bool = false

  /// Whether to play document (translation) text during narration
  public var playDoc: Bool = true

  /// Sound effect volume level (0.0-1.0, where 0.0 is muted, default 0.5)
  public var soundEffectVolume: Float = SOUND_EFFECT_VOLUME_DEFAULT

  /// Application version when last run
  public var lastApplicationVersion: String = ""

  /// Maximum number of documents to return in search results
  public var maxDoc: Int = MAX_DOC_DEFAULT

  /// AutoComplete phrase data by author:lang
  public var autoCompleteData: [PhrasesByAuthorLang] = []

  // MARK: - Initialization

  /// Initialize Settings instance
  /// - Parameter userDefaults: UserDefaults instance for persistence (nil
  /// defaults to UserDefaults.standard for dependency injection in tests)
  /// - Note: Internal visibility allows tests to create instances with specific
  /// values
  init(userDefaults: UserDefaults? = nil) {
    self.userDefaults = userDefaults

    // Detect system language and set as default if available
    if let preferredLanguage = Locale.preferredLanguages.first,
       let systemLanguage = ScvLanguage.toVoiceLanguage(preferredLanguage)
    {
      // System language matches an available bundled database
      docLang = systemLanguage
    } else {
      // System language not available, use default (.english)
      docLang = .default
    }

    load()
    validate()
    cc.ok1(#line, "init()")
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case version
    case docLang
    case refLang
    case docAuthor
    case refAuthor
    case paliSpeech
    case docSpeech
    case isDarkModeEnabled
    case segmentPause
    case playPali
    case playDoc
    case soundEffectVolume
    case lastApplicationVersion
    case maxDoc
    case autoCompleteData
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(docLang, forKey: .docLang)
    try container.encode(refLang, forKey: .refLang)
    try container.encode(docAuthor, forKey: .docAuthor)
    if let refAuthor {
      try container.encode(refAuthor, forKey: .refAuthor)
    }
    try container.encode(paliSpeech, forKey: .paliSpeech)
    try container.encode(docSpeech, forKey: .docSpeech)
    try container.encode(isDarkModeEnabled, forKey: .isDarkModeEnabled)
    try container.encode(segmentPause, forKey: .segmentPause)
    try container.encode(playPali, forKey: .playPali)
    try container.encode(playDoc, forKey: .playDoc)
    try container.encode(soundEffectVolume, forKey: .soundEffectVolume)
    try container.encode(
      lastApplicationVersion,
      forKey: .lastApplicationVersion,
    )
    try container.encode(maxDoc, forKey: .maxDoc)
    try container.encode(autoCompleteData, forKey: .autoCompleteData)
  }

  public required init(from decoder: Decoder) throws {
    // userDefaults is nil for Codable decoding (will use UserDefaults.standard
    // when needed)
    userDefaults = nil

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

      // Decode or initialize docAuthor from manifest
      if let decodedAuthor = try container.decodeIfPresent(
        String.self,
        forKey: .docAuthor,
      ) {
        docAuthor = decodedAuthor
      } else {
        // Initialize from DatabaseManifest default for docLang
        if let defaultInfo = DatabaseManifest.shared
          .defaultAuthorForLanguage(docLang.code)
        {
          docAuthor = defaultInfo.author
        } else {
          docAuthor = ""
        }
      }

      // Decode or initialize refAuthor from manifest
      if let decodedRefAuthor = try container.decodeIfPresent(
        String.self,
        forKey: .refAuthor,
      ) {
        refAuthor = decodedRefAuthor
      } else {
        // Initialize from DatabaseManifest default for refLang
        if let defaultInfo = DatabaseManifest.shared
          .defaultAuthorForLanguage(refLang.code)
        {
          refAuthor = defaultInfo.author
        } else {
          refAuthor = nil
        }
      }

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
      segmentPause = try container.decodeIfPresent(
        Double.self,
        forKey: .segmentPause,
      ) ?? SEGMENT_PAUSE_DEFAULT
      playPali = try container.decodeIfPresent(
        Bool.self,
        forKey: .playPali,
      ) ?? false
      playDoc = try container.decodeIfPresent(
        Bool.self,
        forKey: .playDoc,
      ) ?? true
      soundEffectVolume = try container.decodeIfPresent(
        Float.self,
        forKey: .soundEffectVolume,
      ) ?? SOUND_EFFECT_VOLUME_DEFAULT
      lastApplicationVersion = try container.decodeIfPresent(
        String.self,
        forKey: .lastApplicationVersion,
      ) ?? ""
      maxDoc = try container
        .decodeIfPresent(Int.self, forKey: .maxDoc) ?? MAX_DOC_DEFAULT
      autoCompleteData = try container.decodeIfPresent(
        [PhrasesByAuthorLang].self,
        forKey: .autoCompleteData,
      ) ?? []
    default:
      // Unknown version: reset to defaults (will be validated later)
      docLang = .default
      refLang = .default
      docAuthor = ""
      refAuthor = nil
      paliSpeech = SpeechConfig(language: .default)
      docSpeech = SpeechConfig(language: .default)
      isDarkModeEnabled = false
      lastApplicationVersion = ""
      maxDoc = MAX_DOC_DEFAULT
      autoCompleteData = []
    }

    validate()
    cc.ok1(#line, "init(Decoder)")
  }

  // MARK: - Validation

  /// Finds an available Apple voice for a given language
  /// - Parameter language: The language to find a voice for
  /// - Returns: An AVSpeechSynthesisVoice if available, nil otherwise
  private func findVoice(for language: ScvLanguage) -> AVSpeechSynthesisVoice? {
    cc.ok2(#line, "findVoice: searching for voice for language:", language.code)
    let allVoices = AVSpeechSynthesisVoice.speechVoices()
    let languageCode = language.code

    // Filter voices by language and exclude denied voices
    let availableVoices = allVoices.filter { voice in
      voice.language.hasPrefix(languageCode) && !ScvLanguage
        .isVoiceDenied(voice.name)
    }

    let result = availableVoices.first
    if let voice = result {
      cc.ok1(#line, "findVoice: found voice:", voice.name)
    } else {
      cc.ok1(#line, "findVoice: no voice found for language:", language.code)
    }
    return result
  }

  /// Validates and synchronizes settings to maintain consistency
  /// Ensures docSpeech.language matches docLang with an actual Apple voice
  /// Falls back to .english if no voice available for docLang
  /// Ensures refLang and refAuthor are properly initialized
  public func validate() {
    let startTime = CFAbsoluteTimeGetCurrent()

    let manifest = DatabaseManifest.shared

    // Validate and fix docAuthor if it's invalid for docLang
    if docAuthor.isEmpty ||
      manifest.info(language: docLang.code, author: docAuthor) == nil
    {
      if let defaultInfo = manifest.defaultAuthorForLanguage(docLang.code) {
        docAuthor = defaultInfo.author
        cc.ok2(#line, #function, "docAuthor <=", docAuthor)
      }
    }

    // Set refLang to .english if not properly initialized
    if refLang == .default {
      refLang = .english
      cc.ok2(#line, #function, "refLang <=", refLang)
    }

    // Validate and fix refAuthor if it's invalid for refLang
    if refAuthor == nil ||
      manifest.info(language: refLang.code, author: refAuthor ?? "") == nil
    {
      if let defaultInfo = manifest.defaultAuthorForLanguage(refLang.code) {
        refAuthor = defaultInfo.author
        cc.ok2(#line, #function, "refAuthor <=", refAuthor)
      }
    }

    // Check if docSpeech language matches docLang
    if docSpeech.language != docLang {
      cc.ok2(#line, "validate: checking docSpeech language for:", docLang.code)
      // Try to find a voice for docLang
      if let voice = findVoice(for: docLang) {
        // Update docSpeech to match docLang with actual voice
        var newConfig = SpeechConfig(language: docLang)
        newConfig.voiceId = voice.identifier
        newConfig.voiceName = voice.name
        docSpeech = newConfig
        cc.ok2(#line, #function, "docSpeech <=", docSpeech.voiceName)
      } else {
        // No voice available for docLang, fallback to English
        docLang = .english
        cc.ok2(#line, #function, "docLang <=", docLang)
        validate() // Revalidate with new docLang
      }
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    cc.ok1(#line, #function, "elapsed: \(String(format: "%.2f", elapsed)) ms")
  }

  // MARK: - Persistence

  /// Saves settings to UserDefaults
  public func save() {
    validate()
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      (userDefaults ?? UserDefaults.standard).set(
        encoded,
        forKey: "com.scv.settings",
      )
    }
  }

  /// Loads settings from UserDefaults
  private func load() {
    guard let data = (userDefaults ?? UserDefaults.standard)
      .data(forKey: "com.scv.settings")
    else {
      return
    }

    let decoder = JSONDecoder()
    if let decoded = try? decoder.decode(Settings.self, from: data) {
      version = decoded.version
      docLang = decoded.docLang
      refLang = decoded.refLang
      docAuthor = decoded.docAuthor
      refAuthor = decoded.refAuthor
      paliSpeech = decoded.paliSpeech
      docSpeech = decoded.docSpeech
      isDarkModeEnabled = decoded.isDarkModeEnabled
      segmentPause = decoded.segmentPause
      playPali = decoded.playPali
      playDoc = decoded.playDoc
      lastApplicationVersion = decoded.lastApplicationVersion
      maxDoc = decoded.maxDoc
      autoCompleteData = decoded.autoCompleteData
    }
  }

  /// Clears all settings and restores defaults
  public func reset() {
    version = 1
    docLang = .default
    refLang = .default
    docAuthor = ""
    refAuthor = nil
    paliSpeech = SpeechConfig(language: .default)
    docSpeech = SpeechConfig(language: .default)
    isDarkModeEnabled = false
    segmentPause = SEGMENT_PAUSE_DEFAULT
    playPali = false
    playDoc = true
    soundEffectVolume = SOUND_EFFECT_VOLUME_DEFAULT
    lastApplicationVersion = ""
    maxDoc = MAX_DOC_DEFAULT
    autoCompleteData = []
    (userDefaults ?? UserDefaults.standard)
      .removeObject(forKey: "com.scv.settings")
  }
}
