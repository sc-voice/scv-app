//
//  AudioContextTests.swift
//  scv-core
//
//  Created by Visakha on 21/01/2026.
//

import AVFoundation
import Foundation
import Testing

@testable import scvCore

// MARK: - AudioContextTests

@Suite struct AudioContextTests {
  // MARK: - Initialization Tests

  @Test("Initialize with Settings.shared using default voiceId")
  func initWithDefaultVoiceId() {
    let context = AudioContext(for: "en")

    #expect(context.docLang == "en")
    #expect(!context.voiceId.isEmpty) // Should resolve to actual voice ID
    #expect(context.pitch == 1.0)
    #expect(context.rate == 1.0)
    #expect(context.segmentPause > 0)
  }

  @Test("Initialize with explicit voiceId from settings")
  func initWithExplicitVoiceId() {
    let settings = Settings()
    settings.docLang = .english

    // Set explicit voice ID
    if let englishSettings = settings.docLangSettings[.english] {
      var updated = englishSettings
      if let voices = AVSpeechSynthesisVoice.speechVoices().first {
        updated.voiceId = voices.identifier
        settings.docLangSettings[.english] = updated
      }
    }

    let context = AudioContext(for: "en", from: settings)

    #expect(context.docLang == "en")
    #expect(!context.voiceId.isEmpty)
  }

  @Test("Initialize with different languages")
  func initWithDifferentLanguages() {
    let context_en = AudioContext(for: "en")
    let context_de = AudioContext(for: "de")

    #expect(context_en.docLang == "en")
    #expect(context_de.docLang == "de")
  }

  @Test("Resolve default voice to actual voice ID")
  func resolveDefaultVoiceToActualId() {
    let settings = Settings()
    settings.docLang = .english

    // Ensure voiceId is empty (Default)
    if var englishSettings = settings.docLangSettings[.english] {
      englishSettings.voiceId = ""
      settings.docLangSettings[.english] = englishSettings
    }

    let context = AudioContext(for: "en", from: settings)

    // Should resolve empty string to actual voice ID
    #expect(!context.voiceId.isEmpty)

    // Verify it's a valid voice ID
    let allVoiceIds = AVSpeechSynthesisVoice.speechVoices()
      .map(\.identifier)
    #expect(allVoiceIds.contains(context.voiceId))
  }

  // MARK: - Hash Consistency Tests

  @Test("Hash property matches computeHash result")
  func hashPropertyMatchesComputeHash() {
    let context = AudioContext(for: "en")

    // Verify hash property matches computeHash() result
    #expect(context.hash == context.computeHash())
  }

  @Test("Hash is consistent for same settings")
  func hashConsistency() {
    let context1 = AudioContext(for: "en")
    let context2 = AudioContext(for: "en")

    // Both contexts created from same language with same defaults
    // should produce same hash
    #expect(context1.hash == context2.hash)
  }

  @Test("Hash differs for different docLang")
  func hashChangesWithDocLang() {
    let context_en = AudioContext(for: "en")
    let context_de = AudioContext(for: "de")

    #expect(context_en.hash != context_de.hash)
  }

  @Test("Hash differs for different pitch")
  func hashChangesWithPitch() {
    let settings1 = Settings()
    settings1.docLang = .english
    if var englishSettings = settings1.docLangSettings[.english] {
      englishSettings.pitch = 1.0
      settings1.docLangSettings[.english] = englishSettings
    }

    let settings2 = Settings()
    settings2.docLang = .english
    if var englishSettings = settings2.docLangSettings[.english] {
      englishSettings.pitch = 1.5
      settings2.docLangSettings[.english] = englishSettings
    }

    let context1 = AudioContext(for: "en", from: settings1)
    let context2 = AudioContext(for: "en", from: settings2)

    #expect(context1.hash != context2.hash)
  }

  @Test("Hash differs for different rate")
  func hashChangesWithRate() {
    let settings1 = Settings()
    settings1.docLang = .english
    if var englishSettings = settings1.docLangSettings[.english] {
      englishSettings.rate = 1.0
      settings1.docLangSettings[.english] = englishSettings
    }

    let settings2 = Settings()
    settings2.docLang = .english
    if var englishSettings = settings2.docLangSettings[.english] {
      englishSettings.rate = 1.5
      settings2.docLangSettings[.english] = englishSettings
    }

    let context1 = AudioContext(for: "en", from: settings1)
    let context2 = AudioContext(for: "en", from: settings2)

    #expect(context1.hash != context2.hash)
  }

  @Test("Hash differs for different segmentPause")
  func hashChangesWithSegmentPause() {
    let settings1 = Settings()
    settings1.docLang = .english
    settings1.segmentPause = 0.0

    let settings2 = Settings()
    settings2.docLang = .english
    settings2.segmentPause = 0.5

    let context1 = AudioContext(for: "en", from: settings1)
    let context2 = AudioContext(for: "en", from: settings2)

    #expect(context1.hash != context2.hash)
  }

  @Test("Hash is deterministic")
  func hashIsDeterministic() {
    let settings = Settings()
    let context = AudioContext(for: "en", from: settings)

    let hash1 = context.hash
    let hash2 = context.hash
    let hash3 = context.hash

    #expect(hash1 == hash2)
    #expect(hash2 == hash3)
  }

  @Test("Hash format is valid MD5 (32 hex chars)")
  func hashFormatIsValidMD5() {
    let context = AudioContext(for: "en")
    let hash = context.hash

    // MD5 hashes are 32 hex characters
    #expect(hash.count == 32)

    // All characters should be hex (0-9, a-f)
    let hexChars = Set("0123456789abcdef")
    #expect(hash.allSatisfy { hexChars.contains($0) })
  }

  // MARK: - Codable Tests

  @Test("Encode and decode round-trip")
  func codableRoundTrip() throws {
    let context = AudioContext(for: "en")

    let encoder = JSONEncoder()
    let encoded = try encoder.encode(context)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AudioContext.self, from: encoded)

    #expect(decoded.docLang == context.docLang)
    #expect(decoded.voiceId == context.voiceId)
    #expect(decoded.pitch == context.pitch)
    #expect(decoded.rate == context.rate)
    #expect(decoded.segmentPause == context.segmentPause)
  }

  @Test("Encode produces valid JSON")
  func encodeProducesValidJSON() throws {
    let context = AudioContext(for: "en")

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(context)
    let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

    #expect(json?["docLang"] as? String == "en")
    #expect(json?["voiceId"] as? String != nil)
    #expect(json?["pitch"] as? NSNumber != nil)
    #expect(json?["rate"] as? NSNumber != nil)
    #expect(json?["segmentPause"] as? NSNumber != nil)
  }

  @Test("Decode from JSON")
  func decodeFromJSON() throws {
    let json = """
    {
      "docLang": "de",
      "voiceId": "com.apple.ttsbundle.Anna-compact",
      "pitch": 1.2,
      "rate": 0.95,
      "segmentPause": 0.3
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let context = try decoder.decode(AudioContext.self, from: json)

    #expect(context.docLang == "de")
    #expect(context.voiceId == "com.apple.ttsbundle.Anna-compact")
    #expect(abs(context.pitch - 1.2) < 0.01)
    #expect(abs(context.rate - 0.95) < 0.01)
    #expect(abs(context.segmentPause - 0.3) < 0.01)
  }

  // MARK: - Hashable Tests

  @Test("AudioContext can be used as dictionary key")
  func useAsHashableKey() {
    let context1 = AudioContext(for: "en")
    let context2 = AudioContext(for: "de")

    var dict: [AudioContext: String] = [:]
    dict[context1] = "English"
    dict[context2] = "German"

    #expect(dict[context1] == "English")
    #expect(dict[context2] == "German")
    #expect(dict.count == 2)
  }

  @Test("Equal contexts have equal hash")
  func equalContextsHaveEqualHash() {
    let settings = Settings()
    let context1 = AudioContext(for: "en", from: settings)
    let context2 = AudioContext(for: "en", from: settings)

    // Both created from same settings should be equal
    #expect(context1 == context2)
    #expect(context1.hashValue == context2.hashValue)
  }

  @Test("Can use contexts in Set")
  func useInSet() {
    let context1 = AudioContext(for: "en")
    let context2 = AudioContext(for: "de")
    let context3 = AudioContext(for: "en") // Same as context1

    let set: Set<AudioContext> = [context1, context2, context3]

    // context3 is equal to context1, so set should have 2 elements
    #expect(set.count == 2)
    #expect(set.contains(context1))
    #expect(set.contains(context2))
  }

  // MARK: - Edge Cases

  @Test("Handle invalid language code gracefully")
  func invalidLanguageCodeFallsback() {
    let context = AudioContext(for: "invalid-lang")

    #expect(context.docLang == "invalid-lang")
    #expect(!context.voiceId.isEmpty) // Should fall back to default
  }

  @Test("Pali language support")
  func paliLanguageSupport() {
    let context = AudioContext(for: "pli")

    #expect(context.docLang == "pli")
    // voiceId may be empty if no Pali-specific voice, but should not crash
  }

  @Test("All documented properties are captured")
  func allPropertiesAccountedFor() {
    let context = AudioContext(for: "en")

    // Verify all properties used in speech synthesis are captured
    #expect(!context.docLang.isEmpty)
    #expect(!context.voiceId.isEmpty)
    #expect(context.pitch >= 0.5 && context.pitch <= 2.0)
    #expect(context.rate >= 0.1 && context.rate <= 2.0)
    #expect(context.segmentPause >= 0.0)
  }
}
