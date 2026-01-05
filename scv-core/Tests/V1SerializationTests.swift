//
//  V1SerializationTests.swift
//  scv-core
//
//  V1 serialization baseline tests for Settings.
//  These tests verify that the current serialization format can be used to
//  generate v1 fixtures for backward compatibility testing.
//
//  See: doc/Serialization.md for fixture management and versioning strategy.
//

import Foundation
@testable import scvCore
import Testing

@Suite("V1SerializationTests")
struct V1SerializationTests {
  // MARK: - Configuration

  /// Enable fixture generation. Set to false to skip saving fixtures.
  static let GENERATE_V1_FIXTURES = false

  // MARK: - Helpers

  static func getFixtureJSON(_ settings: Settings,
                             testName: String) throws -> Data
  {
    let fixturesPath = "/Users/visakha/dev/scv-app/scv-core/Tests/Fixtures"
    let filePath = "\(fixturesPath)/V1_\(testName).json"

    if GENERATE_V1_FIXTURES {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let encoded = try encoder.encode(settings)

      try FileManager.default.createDirectory(
        atPath: fixturesPath,
        withIntermediateDirectories: true,
        attributes: nil,
      )
      try encoded.write(to: URL(fileURLWithPath: filePath))
      return encoded
    } else {
      return try Data(contentsOf: URL(fileURLWithPath: filePath))
    }
  }

  // MARK: - Serialization: Atomic Fields (v1.0)

  @Test func serializeAllAtomicFields() throws {
    /// Comprehensive round-trip test for all atomic (non-dict) fields
    let settings = Settings()

    // Set all atomic fields
    settings.version = 1
    settings.docLang = .english
    settings.refLang = .english
    settings.refAuthor = "sujato"
    settings.isDarkModeEnabled = true
    settings.segmentPause = 0.5
    settings.playPali = false
    settings.playDoc = true
    settings.showPali = false
    settings.showDoc = true
    settings.showRef = false
    settings.soundEffectVolume = 0.5
    settings.lastApplicationVersion = "0.0.589"
    settings.maxDoc = 50
    settings.maxColumnWidth = 400
    settings.autoCompleteData = []

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(
      settings,
      testName: "Settings_AllAtomicFields",
    )

    // Decode
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Settings.self, from: encoded)

    // Verify all atomic fields survive round-trip
    #expect(decoded.version == 1)
    #expect(decoded.docLang == .english)
    #expect(decoded.refLang == .english)
    #expect(decoded.refAuthor == "sujato")
    #expect(decoded.isDarkModeEnabled == true)
    #expect(decoded.segmentPause == 0.5)
    #expect(decoded.playPali == false)
    #expect(decoded.playDoc == true)
    #expect(decoded.showPali == false)
    #expect(decoded.showDoc == true)
    #expect(decoded.showRef == false)
    #expect(decoded.soundEffectVolume == 0.5)
    #expect(decoded.lastApplicationVersion == "0.0.589")
    #expect(decoded.maxDoc == 50)
    #expect(decoded.maxColumnWidth == 400)
    #expect(decoded.autoCompleteData.isEmpty)
  }

  // MARK: - Serialization: docLangSettings (Dictionary Structure)

  @Test func serializeDocLangSettingsMinimal() throws {
    /// Test docLangSettings with single entry (English)
    let settings = Settings()
    settings.docLang = .english
    settings.refLang = .english

    // Set minimal English settings
    var englishSettings = LangSettings(language: .english)
    englishSettings.author = "sujato"
    settings.docLangSettings[.english] = englishSettings

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(
      settings,
      testName: "Settings_DocLangSettingsMinimal",
    )

    // Decode
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Settings.self, from: encoded)

    // Verify docLangSettings structure
    #expect(decoded.docLangSettings[.english] != nil)
    #expect(decoded.docLangSettings[.english]?.author == "sujato")
    #expect(decoded.docLangSettings[.english]?.language == .english)
    #expect(decoded.docAuthor == "sujato")
  }

  @Test func serializeDocLangSettingsWithVoice() throws {
    /// Test docLangSettings with full voice configuration
    let settings = Settings()
    settings.docLang = .english
    settings.refLang = .pli
    settings.refAuthor = "ms"

    // Set English document settings with voice
    var englishSettings = LangSettings(language: .english)
    englishSettings.author = "soma"
    englishSettings.voiceName = "Samantha"
    englishSettings.voiceId = "com.apple.ttsbundle.Samantha-compact"
    englishSettings.variant = "premium"
    englishSettings.pitch = 1.0
    englishSettings.rate = 1.0
    englishSettings.emphasis = true
    settings.docLangSettings[.english] = englishSettings

    // Set Pali narration settings
    var paliSettings = LangSettings(language: .pli)
    paliSettings.voiceName = "Daniel"
    paliSettings.voiceId = "com.apple.ttsbundle.Daniel-compact"
    paliSettings.pitch = 1.1
    paliSettings.rate = 0.95
    paliSettings.emphasis = true
    settings.paliSettings = paliSettings

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(
      settings,
      testName: "Settings_DocLangSettingsWithVoice",
    )

    // Decode
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Settings.self, from: encoded)

    // Verify docLangSettings with voice
    #expect(decoded.docLangSettings[.english]?.author == "soma")
    #expect(decoded.docLangSettings[.english]?.voiceName == "Samantha")
    #expect(decoded.docLangSettings[.english]?
      .voiceId == "com.apple.ttsbundle.Samantha-compact")
    #expect(decoded.docLangSettings[.english]?.variant == "premium")

    // Verify paliSettings
    #expect(decoded.paliSettings.voiceName == "Daniel")
    #expect(decoded.paliSettings
      .voiceId == "com.apple.ttsbundle.Daniel-compact")
    #expect(abs(decoded.paliSettings.pitch - 1.1) < 0.01)
    #expect(abs(decoded.paliSettings.rate - 0.95) < 0.01)
  }

  @Test func serializeDocLangSettingsMultipleLanguages() throws {
    /// Test docLangSettings with multiple language entries
    let settings = Settings()
    settings.docLang = .english

    // Add English settings
    var englishSettings = LangSettings(language: .english)
    englishSettings.author = "sujato"
    settings.docLangSettings[.english] = englishSettings

    // Add German settings
    var germanSettings = LangSettings(language: .german)
    germanSettings.author = "sabbamitta"
    germanSettings.voiceName = "Anna"
    settings.docLangSettings[.german] = germanSettings

    // Add Portuguese settings
    var portugueseSettings = LangSettings(language: .portuguese)
    portugueseSettings.author = "felicidade"
    settings.docLangSettings[.portuguese] = portugueseSettings

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(
      settings,
      testName: "Settings_DocLangSettingsMultipleLanguages",
    )

    // Decode
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Settings.self, from: encoded)

    // Verify all language entries survive
    #expect(decoded.docLangSettings[.english]?.author == "sujato")
    #expect(decoded.docLangSettings[.german]?.author == "sabbamitta")
    #expect(decoded.docLangSettings[.german]?.voiceName == "Anna")
    #expect(decoded.docLangSettings[.portuguese]?.author == "felicidade")
  }
}
