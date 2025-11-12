//
//  ScvLanguageTests.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import Foundation
import Testing

@testable import scvCore

// MARK: - ScvLanguageTests

@Suite struct ScvLanguageTests {
  // MARK: - Initialization Tests

  @Test func initFromValidCode() {
    #expect(ScvLanguage(code: "en") == .english)
    #expect(ScvLanguage(code: "pt") == .portuguese)
    #expect(ScvLanguage(code: "es") == .spanish)
    #expect(ScvLanguage(code: "fr") == .french)
    #expect(ScvLanguage(code: "de") == .german)
    #expect(ScvLanguage(code: "ru") == .russian)
    #expect(ScvLanguage(code: "pli") == .pli)
    #expect(ScvLanguage(code: "it") == .italian)
  }

  @Test func initFromInvalidCode() {
    #expect(ScvLanguage(code: "en-XYUZ") == nil)
    #expect(ScvLanguage(code: "xx") == nil)
    #expect(ScvLanguage(code: "invalid") == nil)
    #expect(ScvLanguage(code: "") == nil)
  }

  // MARK: - Display Name Tests

  @Test func displayNames() {
    #expect(ScvLanguage.english.displayName == "English")
    #expect(ScvLanguage.portuguese.displayName == "Português")
    #expect(ScvLanguage.spanish.displayName == "Español")
    #expect(ScvLanguage.french.displayName == "Français")
    #expect(ScvLanguage.german.displayName == "Deutsch")
    #expect(ScvLanguage.russian.displayName == "Русский")
    #expect(ScvLanguage.pli.displayName == "Pali")
    #expect(ScvLanguage.italian.displayName == "Italiano")
  }

  // MARK: - Native Name Tests

  @Test func nativeNames() {
    #expect(ScvLanguage.english.nativeName == "English")
    #expect(ScvLanguage.portuguese.nativeName == "Português")
    #expect(ScvLanguage.spanish.nativeName == "Español")
    #expect(ScvLanguage.french.nativeName == "Français")
    #expect(ScvLanguage.german.nativeName == "Deutsch")
    #expect(ScvLanguage.russian.nativeName == "Русский")
    #expect(ScvLanguage.pli.nativeName == "Pali")
    #expect(ScvLanguage.italian.nativeName == "Italiano")
  }

  // MARK: - Code Property Tests

  @Test func codeProperty() {
    #expect(ScvLanguage.english.code == "en")
    #expect(ScvLanguage.portuguese.code == "pt")
    #expect(ScvLanguage.spanish.code == "es")
    #expect(ScvLanguage.french.code == "fr")
    #expect(ScvLanguage.german.code == "de")
    #expect(ScvLanguage.russian.code == "ru")
    #expect(ScvLanguage.pli.code == "pli")
    #expect(ScvLanguage.italian.code == "it")
  }

  // MARK: - toVoiceLanguage Tests

  @Test func toVoiceLanguageWithSupportedLanguage() {
    // Pali, English and German are supported voice languages
    #expect(ScvLanguage.toVoiceLanguage("pli") == .pli)
    #expect(ScvLanguage.toVoiceLanguage("en") == .english)
    #expect(ScvLanguage.toVoiceLanguage("de") == .german)
  }

  @Test func toVoiceLanguageWithBCP47Tags() {
    // Should extract language code from BCP 47 format
    #expect(ScvLanguage.toVoiceLanguage("en-US") == .english)
    #expect(ScvLanguage.toVoiceLanguage("en-GB") == .english)
    #expect(ScvLanguage.toVoiceLanguage("de-DE") == .german)
    #expect(ScvLanguage.toVoiceLanguage("de-AT") == .german)
    #expect(ScvLanguage.toVoiceLanguage("pi") == .pli)
  }

  @Test func toVoiceLanguageWithUnsupportedLanguage() {
    // Should return nil for unsupported languages
    #expect(ScvLanguage.toVoiceLanguage("pt") == nil)
    #expect(ScvLanguage.toVoiceLanguage("es") == nil)
    #expect(ScvLanguage.toVoiceLanguage("fr") == nil)
    #expect(ScvLanguage.toVoiceLanguage("ru") == nil)
  }

  @Test func toVoiceLanguageWithUnsupportedBCP47Tag() {
    // Should return nil for unsupported BCP 47 tags
    #expect(ScvLanguage.toVoiceLanguage("pt-PT") == nil)
    #expect(ScvLanguage.toVoiceLanguage("pt-BR") == nil)
    #expect(ScvLanguage.toVoiceLanguage("es-ES") == nil)
    #expect(ScvLanguage.toVoiceLanguage("zh-Hans") == nil)
  }

  @Test func toVoiceLanguageWithInvalidInput() {
    // Should return nil for invalid input
    #expect(ScvLanguage.toVoiceLanguage("") == nil)
    #expect(ScvLanguage.toVoiceLanguage("xx") == nil)
    #expect(ScvLanguage.toVoiceLanguage("invalid") == nil)
  }

  // MARK: - Default Language Tests

  @Test func defaultLanguage() {
    #expect(ScvLanguage.default == .english)
  }

  // MARK: - Voice Languages Tests

  @Test func voiceLanguages() {
    #expect(ScvLanguage.voiceLanguages == [.english, .german, .pli])
    #expect(ScvLanguage.voiceLanguages.contains(.english))
    #expect(ScvLanguage.voiceLanguages.contains(.german))
    #expect(ScvLanguage.voiceLanguages.contains(.pli))
    #expect(!ScvLanguage.voiceLanguages.contains(.portuguese))
    #expect(!ScvLanguage.voiceLanguages.contains(.french))
  }

  // MARK: - UI Languages Tests

  @Test func uiLanguages() {
    #expect(ScvLanguage.uiLanguages == [.english, .german, .french])
    #expect(ScvLanguage.uiLanguages.contains(.english))
    #expect(ScvLanguage.uiLanguages.contains(.german))
    #expect(ScvLanguage.uiLanguages.contains(.french))
    #expect(!ScvLanguage.uiLanguages.contains(.portuguese))
  }

  // MARK: - Codable Tests

  @Test func encode() throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(ScvLanguage.german)
    let jsonString = String(data: data, encoding: .utf8)

    #expect(jsonString == "\"de\"")
  }

  @Test func decode() throws {
    let json = "\"fr\"".data(using: .utf8)!
    let decoder = JSONDecoder()
    let language = try decoder.decode(ScvLanguage.self, from: json)

    #expect(language == .french)
  }

  // MARK: - CaseIterable Tests

  @Test func caseIterable() {
    let allLanguages = ScvLanguage.allCases
    #expect(allLanguages.count == 8)
    #expect(allLanguages.contains(.english))
    #expect(allLanguages.contains(.portuguese))
    #expect(allLanguages.contains(.spanish))
    #expect(allLanguages.contains(.french))
    #expect(allLanguages.contains(.german))
    #expect(allLanguages.contains(.russian))
    #expect(allLanguages.contains(.pli))
    #expect(allLanguages.contains(.italian))
  }
}
