#!/usr/bin/env swift
//
//  generate-fixtures.swift
//  SC-Voice
//
//  Generates v1 serialization fixtures for all Card and Settings variants.
//  Fixtures are saved to scv-core/Tests/Fixtures/ with versioned filenames.
//
//  Usage: swift scripts/generate-fixtures.swift
//

import Foundation

// MARK: - Configuration

let projectRoot = FileManager.default.currentDirectoryPath
let scvCorePath = "\(projectRoot)/scv-core"
let fixturesPath = "\(scvCorePath)/Tests/Fixtures"
let versionFilePath = "\(scvCorePath)/Sources/Version.swift"

// MARK: - Read App Version

func readAppVersion() throws -> String {
  let versionContent = try String(
    contentsOfFile: versionFilePath,
    encoding: .utf8,
  )

  guard let versionLine = versionContent.split(separator: "\n")
    .first(where: { $0.contains("appVersion") }),
    let versionValue = versionLine.split(separator: "\"").dropFirst().first
  else {
    throw NSError(
      domain: "VersionError",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Could not parse app version"],
    )
  }

  return String(versionValue)
}

// MARK: - Create Fixtures Directory

func ensureFixturesDirectory() throws {
  try FileManager.default.createDirectory(
    atPath: fixturesPath,
    withIntermediateDirectories: true,
    attributes: nil,
  )
}

// MARK: - Generate and Save Fixtures

func generateFixtures() throws {
  let appVersion = try readAppVersion()
  try ensureFixturesDirectory()

  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

  print("📦 Generating serialization fixtures for version \(appVersion)")
  print("📁 Saving to: \(fixturesPath)\n")

  // MARK: - Card Fixtures

  // B221_Card_Search.json
  let cardSearchData: [String: Any] = [
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "createdAt": 733_650.5,
    "cardType": "search",
    "typeId": 1,
    "searchQuery": "root of suffering",
    "searchResults": NSNull(),
    "suttaReference": "",
    "mlDoc": NSNull(),
  ]

  let cardSearchJSON = try JSONSerialization.data(
    withJSONObject: cardSearchData,
    options: [.prettyPrinted, .sortedKeys],
  )
  let cardSearchFile = "\(fixturesPath)/v\(appVersion)_Card_Search.json"
  try cardSearchJSON.write(to: URL(fileURLWithPath: cardSearchFile))
  print("✓ \(URL(fileURLWithPath: cardSearchFile).lastPathComponent)")

  // B221_Card_Sutta.json
  let cardSuttaData: [String: Any] = [
    "uuid": "550e8400-e29b-41d4-a716-446655440001",
    "createdAt": 733_650.5,
    "cardType": "sutta",
    "typeId": 2,
    "searchQuery": "",
    "searchResults": NSNull(),
    "suttaReference": "sn42.11",
    "mlDoc": NSNull(),
  ]

  let cardSuttaJSON = try JSONSerialization.data(
    withJSONObject: cardSuttaData,
    options: [.prettyPrinted, .sortedKeys],
  )
  let cardSuttaFile = "\(fixturesPath)/v\(appVersion)_Card_Sutta.json"
  try cardSuttaJSON.write(to: URL(fileURLWithPath: cardSuttaFile))
  print("✓ \(URL(fileURLWithPath: cardSuttaFile).lastPathComponent)")

  // B221_Card_Search_Results.json
  let searchResultsData: [String: Any] = [
    "author": "sujato",
    "lang": "en",
    "searchLang": "en",
    "minLang": 0,
    "maxDoc": 10,
    "maxResults": 50,
    "pattern": "root of suffering",
    "method": "keyword",
    "resultPattern": "root|suffering",
    "segsMatched": 7,
    "bilaraPaths": [],
    "suttaRefs": ["sn42.11/en/sujato", "mn105/en/sujato"],
    "mlDocs": [],
    "searchError": NSNull(),
    "searchSuggestion": "",
  ]

  let cardSeekerResultsData: [String: Any] = [
    "uuid": "550e8400-e29b-41d4-a716-446655440002",
    "createdAt": 733_650.5,
    "cardType": "search",
    "typeId": 3,
    "searchQuery": "root of suffering",
    "searchResults": searchResultsData,
    "suttaReference": "",
    "mlDoc": NSNull(),
  ]

  let cardSeekerResultsJSON = try JSONSerialization.data(
    withJSONObject: cardSeekerResultsData,
    options: [.prettyPrinted, .sortedKeys],
  )
  let cardSeekerResultsFile = "\(fixturesPath)/v\(appVersion)_Card_Search_Results.json"
  try cardSeekerResultsJSON
    .write(to: URL(fileURLWithPath: cardSeekerResultsFile))
  print("✓ \(URL(fileURLWithPath: cardSeekerResultsFile).lastPathComponent)")

  // MARK: - Settings Fixtures

  // v0.0.221_Settings_Minimal.json
  let paliSpeechMinimal: [String: Any] = [
    "language": "en",
    "voiceId": "",
    "voiceName": "",
    "variant": "default",
    "pitch": 1.0,
    "rate": 1.0,
    "emphasis": true,
  ]

  let docSpeechMinimal: [String: Any] = [
    "language": "en",
    "voiceId": "",
    "voiceName": "",
    "variant": "default",
    "pitch": 1.0,
    "rate": 1.0,
    "emphasis": true,
  ]

  let settingsMinimalData: [String: Any] = [
    "version": 1,
    "docLang": "en",
    "refLang": "en",
    "uiLang": "en",
    "docAuthor": "sujato",
    "refAuthor": NSNull(),
    "paliSpeech": paliSpeechMinimal,
    "docSpeech": docSpeechMinimal,
    "isDarkModeEnabled": true,
    "lastApplicationVersion": appVersion,
    "maxDoc": 50,
  ]

  let settingsMinimalJSON = try JSONSerialization.data(
    withJSONObject: settingsMinimalData,
    options: [.prettyPrinted, .sortedKeys],
  )
  let settingsMinimalFile = "\(fixturesPath)/v\(appVersion)_Settings_Minimal.json"
  try settingsMinimalJSON.write(to: URL(fileURLWithPath: settingsMinimalFile))
  print("✓ \(URL(fileURLWithPath: settingsMinimalFile).lastPathComponent)")

  // v0.0.221_Settings_WithVoice.json
  let paliSpeechWithVoice: [String: Any] = [
    "language": "pli",
    "voiceId": "com.apple.ttsbundle.Daniel-compact",
    "voiceName": "Daniel",
    "variant": "default",
    "pitch": 1.1,
    "rate": 0.95,
    "emphasis": true,
  ]

  let docSpeechWithVoice: [String: Any] = [
    "language": "en",
    "voiceId": "com.apple.ttsbundle.Samantha-compact",
    "voiceName": "Samantha",
    "variant": "premium",
    "pitch": 1.0,
    "rate": 1.0,
    "emphasis": true,
  ]

  let settingsWithVoiceData: [String: Any] = [
    "version": 1,
    "docLang": "en",
    "refLang": "pli",
    "uiLang": "en",
    "docAuthor": "soma",
    "refAuthor": "ms",
    "paliSpeech": paliSpeechWithVoice,
    "docSpeech": docSpeechWithVoice,
    "isDarkModeEnabled": false,
    "lastApplicationVersion": appVersion,
    "maxDoc": 100,
  ]

  let settingsWithVoiceJSON = try JSONSerialization.data(
    withJSONObject: settingsWithVoiceData,
    options: [.prettyPrinted, .sortedKeys],
  )
  let settingsWithVoiceFile = "\(fixturesPath)/v\(appVersion)_Settings_WithVoice.json"
  try settingsWithVoiceJSON
    .write(to: URL(fileURLWithPath: settingsWithVoiceFile))
  print("✓ \(URL(fileURLWithPath: settingsWithVoiceFile).lastPathComponent)")

  print("\n✅ Generated 5 fixtures for version \(appVersion)")
}

// MARK: - Main

do {
  try generateFixtures()
} catch {
  print("❌ Error: \(error.localizedDescription)")
  exit(1)
}
