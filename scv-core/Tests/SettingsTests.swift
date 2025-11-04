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
    Settings.shared.lastSelectedCardId = "card-123"

    Settings.shared.reset()

    #expect(Settings.shared.docLang == .english)
    #expect(Settings.shared.refLang == .english)
    #expect(Settings.shared.uiLang == .english)
    #expect(Settings.shared.isDarkModeEnabled == false)
    #expect(Settings.shared.lastApplicationVersion == "")
    #expect(Settings.shared.lastSelectedCardId == "")
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

  @Test func updateLastSelectedCardId() {
    Settings.shared.reset()
    Settings.shared.lastSelectedCardId = "card-123"

    #expect(Settings.shared.lastSelectedCardId == "card-123")

    Settings.shared.lastSelectedCardId = "card-456"

    #expect(Settings.shared.lastSelectedCardId == "card-456")
  }

  // MARK: - Codable Tests

  @Test func encode() throws {
    Settings.shared.reset()
    Settings.shared.docLang = .german
    Settings.shared.refLang = .french
    Settings.shared.uiLang = .italian
    Settings.shared.isDarkModeEnabled = true
    Settings.shared.lastApplicationVersion = "2.0.0"
    Settings.shared.lastSelectedCardId = "card-456"

    let encoder = JSONEncoder()
    let data = try encoder.encode(Settings.shared)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["docLang"] as? String == "de")
    #expect(json?["refLang"] as? String == "fr")
    #expect(json?["uiLang"] as? String == "it")
    #expect(json?["isDarkModeEnabled"] as? Bool == true)
    #expect(json?["lastApplicationVersion"] as? String == "2.0.0")
    #expect(json?["lastSelectedCardId"] as? String == "card-456")
  }

  @Test func decode() throws {
    let json = """
    {
      "docLang": "pt",
      "refLang": "es",
      "uiLang": "fr",
      "isDarkModeEnabled": false,
      "lastApplicationVersion": "1.5.0",
      "lastSelectedCardId": "card-789"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let settings = try decoder.decode(Settings.self, from: json)

    #expect(settings.docLang == .portuguese)
    #expect(settings.refLang == .spanish)
    #expect(settings.uiLang == .french)
    #expect(settings.isDarkModeEnabled == false)
    #expect(settings.lastApplicationVersion == "1.5.0")
    #expect(settings.lastSelectedCardId == "card-789")
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
    #expect(settings.lastSelectedCardId == "")
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
    Settings.shared.lastSelectedCardId = "card-123"

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
    #expect(loadedSettings.lastSelectedCardId == "card-123")
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
}
