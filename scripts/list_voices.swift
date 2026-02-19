#!/usr/bin/env swift
import AVFoundation

print("=== Available Speech Voices ===\n")

let allVoices = AVSpeechSynthesisVoice.speechVoices()
let germanVoices = allVoices.filter { $0.language.hasPrefix("de") }

print("German voices (\(germanVoices.count) total):")
for voice in germanVoices.sorted(by: { $0.name < $1.name }) {
  print("  Name: \(voice.name)")
  print("  Identifier: \(voice.identifier)")
  print("  Language: \(voice.language)")
  print("  Quality: \(voice.quality.rawValue)")
  print("  Gender: \(voice.gender.rawValue)")
  print("  ---")
}

print("\nAll voices (\(allVoices.count) total):")
for voice in allVoices.sorted(by: { $0.language < $1.language }) {
  print(
    "  \(voice.language): \(voice.name) [\(voice.quality.rawValue)] - \(voice.identifier)",
  )
}
