//
//  Settings.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import Foundation

// MARK: - Settings Singleton

/// Serialized singleton for application settings with UserDefaults persistence
public class Settings: Codable {
  // MARK: - Static Properties

  /// Shared singleton instance
  /// nonisolated(unsafe): singleton initialized once, safe to access from any thread
  nonisolated(unsafe) public static let shared = Settings()

  // MARK: - Instance Properties

  /// Currently selected voice document language
  public var docLang: ScvLanguage = .default

  /// Currently selected voice reference language
  public var refLang: ScvLanguage = .default

  /// Currently selected voice ui language
  public var uiLang: ScvLanguage = .default

  /// Whether dark mode is enabled
  public var isDarkModeEnabled: Bool = true

  /// Application version when last run
  public var lastApplicationVersion: String = ""

  /// Last selected card ID for restoration on app launch
  public var lastSelectedCardId: String = ""

  // MARK: - Private Initialization

  private init() {
    load()
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case docLang
    case refLang
    case uiLang
    case isDarkModeEnabled
    case lastApplicationVersion
    case lastSelectedCardId
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(docLang, forKey: .docLang)
    try container.encode(refLang, forKey: .refLang)
    try container.encode(uiLang, forKey: .uiLang)
    try container.encode(isDarkModeEnabled, forKey: .isDarkModeEnabled)
    try container.encode(lastApplicationVersion, forKey: .lastApplicationVersion)
    try container.encode(lastSelectedCardId, forKey: .lastSelectedCardId)
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let docLangCode = try container.decodeIfPresent(String.self, forKey: .docLang) ?? "en"
    self.docLang = ScvLanguage(code: docLangCode) ?? .default
    let refLangCode = try container.decodeIfPresent(String.self, forKey: .refLang) ?? "en"
    self.refLang = ScvLanguage(code: refLangCode) ?? .default
    let uiLangCode = try container.decodeIfPresent(String.self, forKey: .uiLang) ?? "en"
    self.uiLang = ScvLanguage(code: uiLangCode) ?? .default
    self.isDarkModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDarkModeEnabled) ?? false
    self.lastApplicationVersion = try container.decodeIfPresent(String.self, forKey: .lastApplicationVersion) ?? ""
    self.lastSelectedCardId = try container.decodeIfPresent(String.self, forKey: .lastSelectedCardId) ?? ""
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
      self.docLang = decoded.docLang
      self.refLang = decoded.refLang
      self.uiLang = decoded.uiLang
      self.isDarkModeEnabled = decoded.isDarkModeEnabled
      self.lastApplicationVersion = decoded.lastApplicationVersion
      self.lastSelectedCardId = decoded.lastSelectedCardId
    }
  }

  /// Clears all settings and restores defaults
  public func reset() {
    docLang = .default
    refLang = .default
    uiLang = .default
    isDarkModeEnabled = false
    lastApplicationVersion = ""
    lastSelectedCardId = ""
    UserDefaults.standard.removeObject(forKey: "com.scv.settings")
  }
}
