#!/usr/bin/env swift
import Foundation

// Read stored settings from UserDefaults
if let data = UserDefaults.standard.data(forKey: "com.scv.settings"),
   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
{
  print("=== Stored Settings ===\n")

  // Show docLangSettings
  if let docLangSettings = json["docLangSettings"] as? [String: [String: Any]] {
    print("Document Language Settings:")
    for (lang, settings) in docLangSettings.sorted(by: { $0.key < $1.key }) {
      print("\n  Language: \(lang)")
      if let voiceId = settings["voiceId"] as? String, !voiceId.isEmpty {
        print("    voiceId: \(voiceId)")
      }
      if let voiceName = settings["voiceName"] as? String, !voiceName.isEmpty {
        print("    voiceName: \(voiceName)")
      }
      if let pitch = settings["pitch"] as? Double {
        print("    pitch: \(pitch)")
      }
      if let rate = settings["rate"] as? Double {
        print("    rate: \(rate)")
      }
    }
  }

  print("\n\n=== Currently Stored Voice IDs ===\n")
  if let docLangSettings = json["docLangSettings"] as? [String: [String: Any]] {
    for (lang, settings) in docLangSettings.sorted(by: { $0.key < $1.key }) {
      if let voiceId = settings["voiceId"] as? String, !voiceId.isEmpty {
        print("\(lang): \(voiceId)")
      }
    }
  }
} else {
  print("No settings found in UserDefaults")
}
