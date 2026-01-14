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

  /// Helper that simulates full persistence cycle: save settings to
  /// UserDefaults,
  /// then load into new instance (tests Settings.load() method)
  /// Returns tuple of (loaded instance, jsonValues from fixture for comparison)
  static func getFixtureCard(_ settings: Settings,
                             testName: String) throws
    -> (loaded: Settings, jsonValues: Settings)
  {
    // Get fixture JSON (for reproducibility and potential fixture files)
    let jsonData = try Self.getFixtureJSON(settings, testName: testName)

    // Decode to get jsonValues (all fields as they were encoded)
    let decoder = JSONDecoder()
    let jsonValues = try decoder.decode(Settings.self, from: jsonData)

    // Create isolated UserDefaults for this test
    let testSuiteName = "test.v1.\(testName)"
    let testDefaults = UserDefaults(suiteName: testSuiteName)!
    testDefaults.removePersistentDomain(forName: testSuiteName)

    // Save settings to test UserDefaults (simulates app saving)
    let encoder = JSONEncoder()
    let encoded = try encoder.encode(settings)
    testDefaults.set(encoded, forKey: "com.scv.settings")

    // Load into new Settings instance (calls load() method)
    let loaded = Settings(userDefaults: testDefaults)

    // Clean up
    testDefaults.removePersistentDomain(forName: testSuiteName)

    return (loaded, jsonValues)
  }

  // MARK: - Serialization: Atomic Fields (v1.0)

  @Test func serializeAllAtomicFields() throws {
    /// Comprehensive round-trip test for all atomic (non-dict) fields
    /// Tests full UserDefaults persistence cycle
    let settings = Settings()

    // Set all atomic fields to non-default values
    settings.version = 1
    settings.docLang = .german
    settings.refLang = .pli
    settings.refAuthor = "ms"
    settings.isDarkModeEnabled = false
    settings.segmentPause = 1.25
    settings.playPali = true
    settings.playDoc = false
    settings.showPali = true
    settings.showDoc = false
    settings.showRef = true
    settings.soundEffectVolume = 0.75
    settings.lastApplicationVersion = "0.0.600"
    settings.maxDoc = 75
    settings.maxColumnWidth = 350

    // Set one autoComplete entry to test persistence
    let now = Date()
    var phrase = PhraseAsset(
      lemma: "test",
      lastUsedPhrase: "testing",
      created: now,
      lastUsed: now,
      documentCount: 5,
    )
    let autoCompleteEntry = PhrasesByAuthorLang(
      author: "sujato",
      lang: "en",
      phrases: ["test": phrase],
    )
    settings.autoCompleteData = [autoCompleteEntry]

    // Persist to UserDefaults and load into new instance
    let (loaded, _) = try Self.getFixtureCard(
      settings,
      testName: "Settings_AllAtomicFields",
    )

    // Verify all atomic fields survive persistence cycle
    #expect(loaded.version == settings.version)
    #expect(loaded.docLang == settings.docLang)
    #expect(loaded.refLang == settings.refLang)
    #expect(loaded.refAuthor == settings.refAuthor)
    #expect(loaded.isDarkModeEnabled == settings.isDarkModeEnabled)
    #expect(loaded.segmentPause == settings.segmentPause)
    #expect(loaded.playPali == settings.playPali)
    #expect(loaded.playDoc == settings.playDoc)
    #expect(loaded.showPali == settings.showPali)
    #expect(loaded.showDoc == settings.showDoc)
    #expect(loaded.showRef == settings.showRef)
    #expect(loaded.soundEffectVolume == settings.soundEffectVolume)
    #expect(loaded.lastApplicationVersion == settings.lastApplicationVersion)
    #expect(loaded.maxDoc == settings.maxDoc)
    #expect(loaded.maxColumnWidth == settings.maxColumnWidth)

    // Verify autoCompleteData persists
    #expect(loaded.autoCompleteData.count == 1)
    #expect(loaded.autoCompleteData[0].author == "sujato")
    #expect(loaded.autoCompleteData[0].lang == "en")

    // Verify phrase data survives
    if let loadedPhrase = loaded.autoCompleteData[0].phrases["test"] {
      #expect(loadedPhrase.lemma == "test")
      #expect(loadedPhrase.lastUsedPhrase == "testing")
      #expect(loadedPhrase.documentCount == 5)
    }
  }

  // MARK: - Serialization: autoCompleteData

  @Test func serializeAutoCompleteData() throws {
    /// Test autoCompleteData serialization with PhraseAsset entries
    let settings = Settings()

    // Create phrase asset with test data
    let now = Date()
    let phrase = PhraseAsset(
      lemma: "test",
      lastUsedPhrase: "testing",
      created: now,
      lastUsed: now,
      documentCount: 5,
    )

    // Create autocomplete entry for sujato/en
    let autoCompleteEntry = PhrasesByAuthorLang(
      author: "sujato",
      lang: "en",
      phrases: ["test": phrase],
    )
    settings.autoCompleteData = [autoCompleteEntry]

    // Persist to UserDefaults and load into new instance
    let (loaded, _) = try Self.getFixtureCard(
      settings,
      testName: "Settings_AutoCompleteData",
    )

    // Verify autoCompleteData persists
    #expect(loaded.autoCompleteData.count == 1)
    #expect(loaded.autoCompleteData[0].author == "sujato")
    #expect(loaded.autoCompleteData[0].lang == "en")

    // Verify phrase data survives
    if let loadedPhrase = loaded.autoCompleteData[0].phrases["test"] {
      #expect(loadedPhrase.lemma == "test")
      #expect(loadedPhrase.lastUsedPhrase == "testing")
      #expect(loadedPhrase.documentCount == 5)
    }
  }

  // MARK: - Serialization: docLangSettings (Dictionary Structure)

  @Test func serializeDocLangSettingsMinimal() throws {
    /// Test docLangSettings with single entry (German)
    let settings = Settings()
    settings.docLang = .german
    settings.refLang = .pli

    // Set minimal German settings
    var germanSettings = LangSettings(language: .german)
    germanSettings.author = "sabbamitta"
    settings.docLangSettings[.german] = germanSettings

    // Persist to UserDefaults and load into new instance
    let (loaded, jsonValues) = try Self.getFixtureCard(
      settings,
      testName: "Settings_DocLangSettingsMinimal",
    )

    // Verify docLangSettings structure survives persistence
    #expect(loaded.docLangSettings[.german] != nil)
    #expect(loaded.docLangSettings[.german]?.author == jsonValues
      .docLangSettings[.german]?.author)
    #expect(loaded.docLangSettings[.german]?.language == jsonValues
      .docLangSettings[.german]?.language)
    #expect(loaded.docAuthor == jsonValues.docAuthor)
  }

  @Test func serializeDocLangSettingsWithVoice() throws {
    /// Test docLangSettings with full voice configuration
    let settings = Settings()
    settings.docLang = .french
    settings.refLang = .pli
    settings.refAuthor = "ms"

    // Set French document settings with voice (using non-default author)
    var frenchSettings = LangSettings(language: .french)
    frenchSettings.author = "noeismet"
    frenchSettings.voiceName = "Joana"
    frenchSettings.voiceId = "com.apple.ttsbundle.Joana-compact"
    frenchSettings.variant = "enhanced"
    frenchSettings.pitch = 1.2
    frenchSettings.rate = 0.9
    frenchSettings.emphasis = false
    settings.docLangSettings[.french] = frenchSettings

    // Set Pali narration settings
    var paliSettings = LangSettings(language: .pli)
    paliSettings.voiceName = "Daniel"
    paliSettings.voiceId = "com.apple.ttsbundle.Daniel-compact"
    paliSettings.pitch = 1.3
    paliSettings.rate = 0.85
    paliSettings.emphasis = false
    settings.paliSettings = paliSettings

    // Persist to UserDefaults and load into new instance
    let (loaded, _) = try Self.getFixtureCard(
      settings,
      testName: "Settings_DocLangSettingsWithVoice",
    )

    // Verify docLangSettings with voice survives persistence
    #expect(loaded.docLangSettings[.french]?.author == settings
      .docLangSettings[.french]?.author)
    #expect(loaded.docLangSettings[.french]?.voiceName == settings
      .docLangSettings[.french]?.voiceName)
    #expect(loaded.docLangSettings[.french]?.voiceId == settings
      .docLangSettings[.french]?.voiceId)
    #expect(loaded.docLangSettings[.french]?.variant == settings
      .docLangSettings[.french]?.variant)
    if let pitch = loaded.docLangSettings[.french]?.pitch,
       let origPitch = settings.docLangSettings[.french]?.pitch
    {
      #expect(abs(pitch - origPitch) < 0.01)
    }
    if let rate = loaded.docLangSettings[.french]?.rate,
       let origRate = settings.docLangSettings[.french]?.rate
    {
      #expect(abs(rate - origRate) < 0.01)
    }
    #expect(loaded.docLangSettings[.french]?.emphasis == settings
      .docLangSettings[.french]?.emphasis)

    // Verify paliSettings survives persistence
    #expect(loaded.paliSettings.voiceName == settings.paliSettings.voiceName)
    #expect(loaded.paliSettings.voiceId == settings.paliSettings.voiceId)
    #expect(abs(loaded.paliSettings.pitch - settings.paliSettings.pitch) < 0.01)
    #expect(abs(loaded.paliSettings.rate - settings.paliSettings.rate) < 0.01)
    #expect(loaded.paliSettings.emphasis == settings.paliSettings.emphasis)
  }

  @Test func serializeDocLangSettingsMultipleLanguages() throws {
    /// Test docLangSettings with multiple language entries
    let settings = Settings()
    settings.docLang = .english

    // Add English settings with non-default author
    var englishSettings = LangSettings(language: .english)
    englishSettings.author = "brahmali"
    englishSettings.voiceName = "Daniel"
    englishSettings.pitch = 1.15
    settings.docLangSettings[.english] = englishSettings

    // Add German settings with non-default author
    var germanSettings = LangSettings(language: .german)
    germanSettings.author = "sonjabuege"
    germanSettings.voiceName = "Anna"
    germanSettings.pitch = 1.05
    settings.docLangSettings[.german] = germanSettings

    // Add French settings
    var frenchSettings = LangSettings(language: .french)
    frenchSettings.author = "noeismet"
    frenchSettings.voiceName = "Rosa"
    frenchSettings.rate = 0.9
    settings.docLangSettings[.french] = frenchSettings

    // Persist to UserDefaults and load into new instance
    let (loaded, _) = try Self.getFixtureCard(
      settings,
      testName: "Settings_DocLangSettingsMultipleLanguages",
    )

    // Verify all language entries survive persistence
    #expect(loaded.docLangSettings[.english]?.author == settings
      .docLangSettings[.english]?.author)
    #expect(loaded.docLangSettings[.english]?.voiceName == settings
      .docLangSettings[.english]?.voiceName)
    if let pitch = loaded.docLangSettings[.english]?.pitch,
       let origPitch = settings.docLangSettings[.english]?.pitch
    {
      #expect(abs(pitch - origPitch) < 0.01)
    }
    #expect(loaded.docLangSettings[.german]?.author == settings
      .docLangSettings[.german]?.author)
    #expect(loaded.docLangSettings[.german]?.voiceName == settings
      .docLangSettings[.german]?.voiceName)
    if let pitch = loaded.docLangSettings[.german]?.pitch,
       let origPitch = settings.docLangSettings[.german]?.pitch
    {
      #expect(abs(pitch - origPitch) < 0.01)
    }
    #expect(loaded.docLangSettings[.french]?.author == settings
      .docLangSettings[.french]?.author)
    #expect(loaded.docLangSettings[.french]?.voiceName == settings
      .docLangSettings[.french]?.voiceName)
    if let rate = loaded.docLangSettings[.french]?.rate,
       let origRate = settings.docLangSettings[.french]?.rate
    {
      #expect(abs(rate - origRate) < 0.01)
    }
  }
}
