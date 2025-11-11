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
    Settings.shared.uiLang = .spanish
    Settings.shared.isDarkModeEnabled = true
    Settings.shared.lastApplicationVersion = "1.0.0"
    Settings.shared.maxDoc = 10

    Settings.shared.reset()

    #expect(Settings.shared.docLang == .english)
    #expect(Settings.shared.refLang == .english)
    #expect(Settings.shared.uiLang == .english)
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

  @Test func modifyUiLang() {
    Settings.shared.reset()
    Settings.shared.uiLang = .german

    #expect(Settings.shared.uiLang == .german)
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
    Settings.shared.reset()
    Settings.shared.docLang = .german
    Settings.shared.refLang = .french
    Settings.shared.uiLang = .italian
    Settings.shared.isDarkModeEnabled = true
    Settings.shared.lastApplicationVersion = "2.0.0"
    Settings.shared.maxDoc = 75

    let encoder = JSONEncoder()
    let data = try encoder.encode(Settings.shared)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["docLang"] as? String == "de")
    #expect(json?["refLang"] as? String == "fr")
    #expect(json?["uiLang"] as? String == "it")
    #expect(json?["isDarkModeEnabled"] as? Bool == true)
    #expect(json?["lastApplicationVersion"] as? String == "2.0.0")
    #expect(json?["maxDoc"] as? Int == 75)
  }

  @Test func decode() throws {
    let json = """
    {
      "docLang": "pt",
      "refLang": "es",
      "uiLang": "fr",
      "isDarkModeEnabled": false,
      "lastApplicationVersion": "1.5.0",
      "maxDoc": 25
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.docLang == .portuguese)
    #expect(settings.refLang == .spanish)
    #expect(settings.uiLang == .french)
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
    #expect(settings.uiLang == .english)
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
    #expect(settings.uiLang == .english)
  }

  // MARK: - Persistence Tests

  @Test func saveAndLoad() throws {
    Settings.shared.reset()

    Settings.shared.docLang = .german
    Settings.shared.refLang = .french
    Settings.shared.uiLang = .spanish
    Settings.shared.isDarkModeEnabled = true
    Settings.shared.lastApplicationVersion = "1.0.0"
    Settings.shared.maxDoc = 35

    Settings.shared.save()

    guard let data = UserDefaults.standard.data(forKey: "com.scv.settings") else {
      throw NSError(domain: "SettingsTests", code: 1)
    }
    let decoder = JSONDecoder()
    let loadedSettings = try decoder.decode(Settings.self, from: data)

    #expect(loadedSettings.docLang == .german)
    #expect(loadedSettings.refLang == .french)
    #expect(loadedSettings.uiLang == .spanish)
    #expect(loadedSettings.isDarkModeEnabled == true)
    #expect(loadedSettings.lastApplicationVersion == "1.0.0")
    #expect(loadedSettings.maxDoc == 35)
  }

  @Test func allLanguagesIndependent() {
    Settings.shared.reset()

    Settings.shared.docLang = .english
    Settings.shared.refLang = .french
    Settings.shared.uiLang = .spanish

    #expect(Settings.shared.docLang == .english)
    #expect(Settings.shared.refLang == .french)
    #expect(Settings.shared.uiLang == .spanish)
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
      "uiLang": "es",
      "isDarkModeEnabled": true,
      "lastApplicationVersion": "1.5.0"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.version == 1)
    #expect(settings.docLang == .german)
    #expect(settings.refLang == .french)
    #expect(settings.uiLang == .spanish)
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
      "refLang": "fr",
      "uiLang": "es"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.version == 999)
    #expect(settings.docLang == .english)
    #expect(settings.refLang == .english)
    #expect(settings.uiLang == .english)
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

    // After validation, docSpeech must match docLang (may have fallen back to english)
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
}
