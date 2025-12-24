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
    Settings.shared.isDarkModeEnabled = true
    Settings.shared.lastApplicationVersion = "1.0.0"
    Settings.shared.maxDoc = 10

    Settings.shared.reset()

    #expect(Settings.shared.docLang == .english)
    #expect(Settings.shared.refLang == .english)
    #expect(Settings.shared.isDarkModeEnabled == false)
    #expect(Settings.shared.lastApplicationVersion == "")
    #expect(Settings.shared.maxDoc == MAX_DOC_DEFAULT)
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
    #expect(Settings.shared.isDarkModeEnabled == false)

    Settings.shared.isDarkModeEnabled = true
    #expect(Settings.shared.isDarkModeEnabled == true)

    Settings.shared.isDarkModeEnabled = false
    #expect(Settings.shared.isDarkModeEnabled == false)
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

  // MARK: - Codable Tests

  @Test func encode() throws {
    let settings = Settings()
    settings.docLang = .german
    settings.refLang = .french
    settings.isDarkModeEnabled = true
    settings.lastApplicationVersion = "2.0.0"
    settings.maxDoc = 75

    let encoder = JSONEncoder()
    let data = try encoder.encode(settings)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["docLang"] as? String == "de")
    #expect(json?["refLang"] as? String == "fr")
    #expect(json?["isDarkModeEnabled"] as? Bool == true)
    #expect(json?["lastApplicationVersion"] as? String == "2.0.0")
    #expect(json?["maxDoc"] as? Int == 75)
  }

  @Test func decode() throws {
    let json = """
    {
      "docLang": "pt",
      "refLang": "es",
      "isDarkModeEnabled": false,
      "lastApplicationVersion": "1.5.0",
      "maxDoc": 25
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.docLang == .portuguese)
    #expect(settings.refLang == .spanish)
    #expect(settings.isDarkModeEnabled == false)
    #expect(settings.lastApplicationVersion == "1.5.0")
    #expect(settings.maxDoc == 25)
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
    #expect(settings.isDarkModeEnabled == false)
    #expect(settings.lastApplicationVersion == "")
    #expect(settings.maxDoc == MAX_DOC_DEFAULT)
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
    #expect(settings.isDarkModeEnabled == false)
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
    Settings.shared.docSpeech = SpeechConfig(language: .pli)

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
    Settings.shared.docSpeech = SpeechConfig(language: .german)

    Settings.shared.validate()

    // After validation, docSpeech must match docLang (may have fallen back to
    // english)
    #expect(Settings.shared.docSpeech.language == Settings.shared.docLang)
    Settings.shared.reset()
  }

  @Test func validateDoesNothingWhenAlreadySynchronized() {
    Settings.shared.reset()
    Settings.shared.docLang = .english
    Settings.shared.docSpeech = SpeechConfig(language: .english)
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

  @Test func docAuthorEncodedAndDecoded() throws {
    Settings.shared.reset()
    Settings.shared.docLang = .english
    Settings.shared.docAuthor = "sujato"

    let encoder = JSONEncoder()
    let data = try encoder.encode(Settings.shared)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["docAuthor"] as? String == "sujato")
  }

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

    #expect(Settings.shared.docAuthor == "")
    #expect(Settings.shared.refAuthor == nil)
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
}
