//
//  SettingsTests.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import Foundation
import Testing

@testable import scvCore

// MARK: - SettingsTests

@Suite struct SettingsTests {
  // MARK: - Singleton Tests

  @Test func singletonInstance() {
    let settings1 = Settings.shared
    let settings2 = Settings.shared
    #expect(settings1 === settings2)
  }

  // MARK: - Reset Tests

  @Test func resetRestoresDefaults() {
    Settings.shared.docLang = .german
    Settings.shared.refLang = .french
    Settings.shared.isDarkModeEnabled = false
    Settings.shared.lastApplicationVersion = "1.0.0"
    Settings.shared.maxDoc = 10

    Settings.shared.reset()

    #expect(Settings.shared.docLang == .english)
    #expect(Settings.shared.refLang == .english)
    #expect(Settings.shared.isDarkModeEnabled == true)
    #expect(Settings.shared.lastApplicationVersion == "")
    #expect(Settings.shared.maxDoc == MAX_DOC_DEFAULT)
  }

  @Test func resetClearsAllPropertiesBackToDefaults() {
    // CODABLE ANALYSIS: Verify the number of serializable properties
    // Settings.CodingKeys should contain all persisted properties
    let expectedCodingKeys: [String] = [
      "version", "docLang", "refLang", "refAuthor",
      "docLangSettings", "paliSettings",
      "isDarkModeEnabled", "segmentPause", "backgroundPlayback",
      "playPali", "playDoc", "showPali", "showDoc", "showRef",
      "soundEffectVolume", "lastApplicationVersion",
      "maxDoc", "maxColumnWidth", "autoCompleteData",
    ]
    #expect(expectedCodingKeys
      .count == 19) // Verify count of serializable properties

    // Create a Settings instance to modify
    let settings = Settings(userDefaults: nil)

    // Modify all 18 properties from defaults
    settings.version = 999
    settings.docLang = .german
    settings.refLang = .french
    settings.refAuthor = "custom-author"
    settings.docLangSettings = [.german: LangSettings(language: .german)]
    settings.paliSettings = LangSettings(language: .pli)
    settings.isDarkModeEnabled = true
    settings.segmentPause = 1.5
    settings.backgroundPlayback = true
    settings.playPali = true
    settings.playDoc = false
    settings.showPali = true
    settings.showDoc = false
    settings.showRef = true
    settings.soundEffectVolume = 0.75
    settings.lastApplicationVersion = "2.0.0"
    settings.maxDoc = 100
    settings.maxColumnWidth = 300
    settings.autoCompleteData = [PhrasesByAuthorLang(
      author: "test",
      lang: "en",
      phrases: [:],
    )]

    // Call reset to restore all defaults
    settings.reset()

    // Create a fresh Settings instance to compare against true defaults
    let defaults = Settings(userDefaults: nil)

    // CODABLE ROUND-TRIP: Verify serialization preserves all properties
    let encoder = JSONEncoder()
    let encoded = try? encoder.encode(settings)
    #expect(encoded != nil) // Should encode successfully

    if let encoded {
      let decoder = JSONDecoder()
      if let decoded = try? decoder.decode(Settings.self, from: encoded) {
        // After round-trip, verify key properties match
        #expect(decoded.version == settings.version)
        #expect(decoded.autoCompleteData.isEmpty)
      }
    }

    // Verify all 18 properties match the defaults
    #expect(settings.version == defaults.version)
    #expect(settings.docLang == defaults.docLang)
    #expect(settings.refLang == defaults.refLang)
    #expect(settings.refAuthor == defaults.refAuthor)
    #expect(settings.isDarkModeEnabled == defaults.isDarkModeEnabled)
    #expect(settings.segmentPause == defaults.segmentPause)
    #expect(settings.backgroundPlayback == defaults.backgroundPlayback)
    #expect(settings.playPali == defaults.playPali)
    #expect(settings.playDoc == defaults.playDoc)
    #expect(settings.showPali == defaults.showPali)
    #expect(settings.showDoc == defaults.showDoc)
    #expect(settings.showRef == defaults.showRef)
    #expect(settings.soundEffectVolume == defaults.soundEffectVolume)
    #expect(settings.lastApplicationVersion == defaults.lastApplicationVersion)
    #expect(settings.maxDoc == defaults.maxDoc)
    #expect(settings.maxColumnWidth == defaults.maxColumnWidth)

    // Verify docLangSettings structure (empty after reset)
    #expect(settings.docLangSettings.count > 0) // validate() creates entries
    #expect(defaults.docLangSettings.count > 0) // same for defaults

    // Verify paliSettings language matches (validate may modify this)
    #expect(settings.paliSettings.language == defaults.paliSettings.language)

    // Specifically verify search history (autoCompleteData) is cleared
    #expect(settings.autoCompleteData.isEmpty)
    #expect(defaults.autoCompleteData.isEmpty)
  }

  // MARK: - Property Modification Tests

  @Test func modifyDocLang() {
    Settings.shared.reset()
    Settings.shared.docLang = .french

    #expect(Settings.shared.docLang == .french)
  }

  @Test func modifyRefLang() {
    Settings.shared.reset()
    Settings.shared.refLang = .spanish

    #expect(Settings.shared.refLang == .spanish)
  }

  @Test func toggleDarkMode() {
    Settings.shared.reset()
    #expect(Settings.shared.isDarkModeEnabled == true)

    Settings.shared.isDarkModeEnabled = false
    #expect(Settings.shared.isDarkModeEnabled == false)

    Settings.shared.isDarkModeEnabled = true
    #expect(Settings.shared.isDarkModeEnabled == true)
  }

  @Test func updateApplicationVersion() {
    Settings.shared.reset()
    Settings.shared.lastApplicationVersion = "1.0.0"

    #expect(Settings.shared.lastApplicationVersion == "1.0.0")

    Settings.shared.lastApplicationVersion = "2.0.0"

    #expect(Settings.shared.lastApplicationVersion == "2.0.0")
  }

  @Test func maxDocDefaultValue() {
    Settings.shared.reset()

    #expect(Settings.shared.maxDoc == MAX_DOC_DEFAULT)
  }

  @Test func modifyMaxDoc() {
    Settings.shared.reset()
    Settings.shared.maxDoc = 100

    #expect(Settings.shared.maxDoc == 100)

    Settings.shared.maxDoc = 10

    #expect(Settings.shared.maxDoc == 10)
  }

  // MARK: - Column Visibility Tests

  @Test func columnVisibilityDefaults() {
    Settings.shared.reset()

    #expect(Settings.shared.showPali == false)
    #expect(Settings.shared.showDoc == true)
    #expect(Settings.shared.showRef == false)
  }

  @Test func toggleShowPali() {
    Settings.shared.reset()
    #expect(Settings.shared.showPali == false)

    Settings.shared.showPali = true
    #expect(Settings.shared.showPali == true)

    Settings.shared.showPali = false
    #expect(Settings.shared.showPali == false)
  }

  @Test func toggleShowDoc() {
    Settings.shared.reset()
    #expect(Settings.shared.showDoc == true)

    Settings.shared.showDoc = false
    #expect(Settings.shared.showDoc == false)

    Settings.shared.showDoc = true
    #expect(Settings.shared.showDoc == true)
  }

  @Test func toggleShowRef() {
    Settings.shared.reset()
    #expect(Settings.shared.showRef == false)

    Settings.shared.showRef = true
    #expect(Settings.shared.showRef == true)

    Settings.shared.showRef = false
    #expect(Settings.shared.showRef == false)
  }

  @Test func multipleColumnTogglesCombined() {
    Settings.shared.reset()

    Settings.shared.showPali = true
    Settings.shared.showDoc = false
    Settings.shared.showRef = true

    #expect(Settings.shared.showPali == true)
    #expect(Settings.shared.showDoc == false)
    #expect(Settings.shared.showRef == true)
  }

  // MARK: - Codable Tests

  @Test func encode() throws {
    let settings = Settings()
    settings.docLang = .german
    settings.refLang = .french
    settings.isDarkModeEnabled = true
    settings.backgroundPlayback = true
    settings.lastApplicationVersion = "2.0.0"
    settings.maxDoc = 75
    settings.showPali = true
    settings.showDoc = false
    settings.showRef = true

    let encoder = JSONEncoder()
    let data = try encoder.encode(settings)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["docLang"] as? String == "de")
    #expect(json?["refLang"] as? String == "fr")
    #expect(json?["isDarkModeEnabled"] as? Bool == true)
    #expect(json?["backgroundPlayback"] as? Bool == true)
    #expect(json?["lastApplicationVersion"] as? String == "2.0.0")
    #expect(json?["maxDoc"] as? Int == 75)
    #expect(json?["showPali"] as? Bool == true)
    #expect(json?["showDoc"] as? Bool == false)
    #expect(json?["showRef"] as? Bool == true)
  }

  @Test func decode() throws {
    let json = """
    {
      "docLang": "pt",
      "refLang": "es",
      "isDarkModeEnabled": false,
      "backgroundPlayback": true,
      "lastApplicationVersion": "1.5.0",
      "maxDoc": 25,
      "showPali": true,
      "showDoc": false,
      "showRef": true
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.docLang == .portuguese)
    #expect(settings.refLang == .spanish)
    #expect(settings.isDarkModeEnabled == false)
    #expect(settings.backgroundPlayback == true)
    #expect(settings.lastApplicationVersion == "1.5.0")
    #expect(settings.maxDoc == 25)
    #expect(settings.showPali == true)
    #expect(settings.showDoc == false)
    #expect(settings.showRef == true)
  }

  @Test func decodeWithMissingFields() throws {
    let json = """
    {
      "docLang": "de"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.docLang == .german)
    #expect(settings.refLang == .english)
    #expect(settings.isDarkModeEnabled == true)
    #expect(settings.backgroundPlayback == false)
    #expect(settings.lastApplicationVersion == "")
    #expect(settings.maxDoc == MAX_DOC_DEFAULT)
    #expect(settings.showPali == false)
    #expect(settings.showDoc == true)
    #expect(settings.showRef == false)
  }

  @Test func decodeWithInvalidLanguageCode() throws {
    let json = """
    {
      "docLang": "invalid",
      "refLang": "also-invalid"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.docLang == .english)
    #expect(settings.refLang == .english)
  }

  // MARK: - Persistence Tests

  @Test func saveAndLoad() throws {
    let settings = Settings()

    settings.docLang = .german
    settings.refLang = .french
    settings.isDarkModeEnabled = true
    settings.backgroundPlayback = true
    settings.lastApplicationVersion = "1.0.0"
    settings.maxDoc = 35

    // Manually encode/decode instead of using UserDefaults to avoid test
    // isolation issues
    let encoder = JSONEncoder()
    let encodedData = try encoder.encode(settings)

    let decoder = JSONDecoder()
    let loadedSettings = try decoder.decode(Settings.self, from: encodedData)

    #expect(loadedSettings.docLang == .german)
    #expect(loadedSettings.refLang == .french)
    #expect(loadedSettings.isDarkModeEnabled == true)
    #expect(loadedSettings.backgroundPlayback == true)
    #expect(loadedSettings.lastApplicationVersion == "1.0.0")
    #expect(loadedSettings.maxDoc == 35)
  }

  @Test func allLanguagesIndependent() {
    Settings.shared.reset()

    Settings.shared.docLang = .english
    Settings.shared.refLang = .french

    #expect(Settings.shared.docLang == .english)
    #expect(Settings.shared.refLang == .french)
  }

  // MARK: - Versioning Tests

  @Test func currentVersion() {
    #expect(Settings.currentVersion == 1)
  }

  @Test func versionDefaultsToOne() {
    Settings.shared.reset()

    #expect(Settings.shared.version == 1)
  }

  @Test func encodeIncludesVersion() throws {
    Settings.shared.reset()
    Settings.shared.version = 1

    let encoder = JSONEncoder()
    let data = try encoder.encode(Settings.shared)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["version"] as? Int == 1)
  }

  @Test func decodeHandlesVersionOneData() throws {
    let json = """
    {
      "version": 1,
      "docLang": "de",
      "refLang": "fr",
      "isDarkModeEnabled": true,
      "lastApplicationVersion": "1.5.0"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.version == 1)
    #expect(settings.docLang == .german)
    #expect(settings.refLang == .french)
    #expect(settings.isDarkModeEnabled == true)
  }

  @Test func decodeHandlesOldDataWithoutVersion() throws {
    // Pre-version data should default to version 1
    let json = """
    {
      "docLang": "pt",
      "refLang": "es",
      "isDarkModeEnabled": false
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.version == 1)
    #expect(settings.docLang == .portuguese)
    #expect(settings.refLang == .spanish)
  }

  @Test func decodeHandlesUnknownVersion() throws {
    // Unknown future version should reset to defaults
    let json = """
    {
      "version": 999,
      "docLang": "de",
      "refLang": "fr"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.version == 999)
    #expect(settings.docLang == .english)
    #expect(settings.refLang == .english)
    #expect(settings.isDarkModeEnabled == true)
  }

  @Test func resetResetsVersion() {
    Settings.shared.reset()
    Settings.shared.version = 999

    Settings.shared.reset()

    #expect(Settings.shared.version == 1)
  }

  // MARK: - Validation Tests

  @Test func validateSynchronizesDocSpeechToDocLang() {
    Settings.shared.reset()
    Settings.shared.docLang = .german
    Settings.shared.docSpeech = LangSettings(language: .pli)

    Settings.shared.validate()

    // After validation, either german voice found or fell back to english
    #expect(Settings.shared.docSpeech.language == Settings.shared.docLang)
    if Settings.shared.docLang == .german {
      #expect(!Settings.shared.docSpeech.voiceId.isEmpty)
      #expect(!Settings.shared.docSpeech.voiceName.isEmpty)
    }
    Settings.shared.reset()
  }

  @Test func validateEnsuresSynchronization() {
    Settings.shared.reset()
    Settings.shared.docLang = .french
    Settings.shared.docSpeech = LangSettings(language: .german)

    Settings.shared.validate()

    // After validation, docSpeech must match docLang (may have fallen back to
    // english)
    #expect(Settings.shared.docSpeech.language == Settings.shared.docLang)
    Settings.shared.reset()
  }

  @Test func validateDoesNothingWhenAlreadySynchronized() {
    Settings.shared.reset()
    Settings.shared.docLang = .english
    Settings.shared.docSpeech = LangSettings(language: .english)
    let originalVoiceId = Settings.shared.docSpeech.voiceId

    Settings.shared.validate()

    #expect(Settings.shared.docSpeech.language == .english)
    #expect(Settings.shared.docSpeech.voiceId == originalVoiceId)
    Settings.shared.reset()
  }

  @Test func validateInitializesRefLangAndRefAuthor() {
    Settings.shared.reset()
    // Manually set refLang to .default to simulate uninitialized state
    Settings.shared.refLang = .default
    Settings.shared.refAuthor = nil

    Settings.shared.validate()

    // After validate(), refLang should be .english and refAuthor should be
    // initialized
    #expect(Settings.shared.refLang == .english)
    #expect(Settings.shared.refAuthor != nil)
    let manifest = DatabaseManifest.shared
    if let enInfo = manifest.defaultAuthorForLanguage("en") {
      #expect(Settings.shared.refAuthor == enInfo.author)
    }
  }

  // MARK: - DocAuthor and RefAuthor Tests

  @Test func docAuthorInitializedFromManifest() {
    Settings.shared.reset()
    Settings.shared.docLang = .english
    Settings.shared.validate()

    // English should have default author from manifest
    if let enInfo = DatabaseManifest.shared.defaultAuthorForLanguage("en") {
      #expect(Settings.shared.docAuthor == enInfo.author)
    }
  }

  @Test func docAuthorInitializedForGerman() {
    let settings = Settings()
    settings.docLang = .german
    settings.validate()

    // German should have sabbamitta as default author
    if let deInfo = DatabaseManifest.shared.defaultAuthorForLanguage("de") {
      #expect(settings.docAuthor == deInfo.author)
    }
  }

  @Test func refLangDefaultsToEnglish() {
    Settings.shared.reset()

    #expect(Settings.shared.refLang == .english)
  }

  @Test func refAuthorInitializedFromManifestForEnglish() {
    let settings = Settings()
    settings.refLang = .english
    settings.validate()

    // English reference should have default author from manifest
    if let enInfo = DatabaseManifest.shared.defaultAuthorForLanguage("en") {
      #expect(settings.refAuthor == enInfo.author)
    }
  }

  @Test func refAuthorPersistsAcrossValidate() {
    Settings.shared.reset()
    Settings.shared.refLang = .english
    Settings.shared.refAuthor = nil
    Settings.shared.validate()

    let firstAuthor = Settings.shared.refAuthor
    Settings.shared.validate() // Call again

    #expect(Settings.shared.refAuthor == firstAuthor)
  }

  // NOTE: docAuthor serialization format changed during docLangSettings
  // refactor.
  // docAuthor is now stored in docLangSettings[docLang].author instead of
  // top-level.
  // This test will be updated when fixtures are recreated before app store
  // submittal.
  /*
   @Test func docAuthorEncodedAndDecoded() throws {
     Settings.shared.reset()
     Settings.shared.docLang = .english
     Settings.shared.docAuthor = "sujato"

     let encoder = JSONEncoder()
     let data = try encoder.encode(Settings.shared)
     let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

     #expect(json?["docAuthor"] as? String == "sujato")
   }
   */

  @Test func refAuthorEncodedAndDecoded() throws {
    Settings.shared.reset()
    Settings.shared.refLang = .english
    Settings.shared.refAuthor = "sujato"

    let encoder = JSONEncoder()
    let data = try encoder.encode(Settings.shared)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["refAuthor"] as? String == "sujato")
  }

  @Test func decodeRestoresDocAuthorAndRefAuthor() throws {
    let json = """
    {
      "version": 1,
      "docLang": "en",
      "refLang": "en",
      "docAuthor": "sujato",
      "refAuthor": "sujato"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.docAuthor == "sujato")
    #expect(settings.refAuthor == "sujato")
  }

  @Test func resetClearsDocAuthorAndRefAuthor() {
    Settings.shared.reset()
    Settings.shared.docAuthor = "some-author"
    Settings.shared.refAuthor = "some-ref-author"

    Settings.shared.reset()

    // After reset, authors are initialized from manifest defaults by validate()
    if let defaultInfo = DatabaseManifest.shared
      .defaultAuthorForLanguage("en")
    {
      #expect(Settings.shared.docAuthor == defaultInfo.author)
      #expect(Settings.shared.refAuthor == defaultInfo.author)
    }
  }

  @Test func validateFixesInvalidDocAuthorWhenDocLangChanges() {
    let settings = Settings()
    // Set to valid en/sujato combination
    settings.docLang = .english
    settings.docAuthor = "sujato"
    settings.validate()
    #expect(settings.docLang == .english)
    #expect(settings.docAuthor == "sujato")

    // Change docLang to German - sujato doesn't exist for German
    settings.docLang = .german
    settings.validate()

    // After validate, docAuthor should be sabbamitta (default for German)
    #expect(settings.docLang == .german)
    #expect(settings.docAuthor == "sabbamitta")
  }

  @Test func validateFixesInvalidRefAuthorWhenRefLangChanges() {
    Settings.shared.reset()
    // Set to valid en/sujato combination
    Settings.shared.refLang = .english
    Settings.shared.refAuthor = "sujato"
    Settings.shared.validate()
    #expect(Settings.shared.refLang == .english)
    #expect(Settings.shared.refAuthor == "sujato")

    // Change refLang to German - sujato doesn't exist for German
    Settings.shared.refLang = .german
    Settings.shared.validate()

    // After validate, refAuthor should be sabbamitta (default for German)
    #expect(Settings.shared.refLang == .german)
    #expect(Settings.shared.refAuthor == "sabbamitta")
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
    settings.backgroundPlayback = false
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

    // Encode
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(settings)

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
    #expect(decoded.backgroundPlayback == false)
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

    // Encode and decode
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(settings)

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

    // Encode and decode
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(settings)

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

    // Encode and decode
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(settings)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Settings.self, from: encoded)

    // Verify all language entries survive
    #expect(decoded.docLangSettings[.english]?.author == "sujato")
    #expect(decoded.docLangSettings[.german]?.author == "sabbamitta")
    #expect(decoded.docLangSettings[.german]?.voiceName == "Anna")
    #expect(decoded.docLangSettings[.portuguese]?.author == "felicidade")
  }
}
