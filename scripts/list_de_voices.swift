#!/usr/bin/env swift
import AVFoundation

print("=== Available German Voices ===\n")

let allVoices = AVSpeechSynthesisVoice.speechVoices()
let germanVoices = allVoices.filter { $0.language.hasPrefix("de") }

for voice in germanVoices.sorted(by: { $0.name < $1.name }) {
  print("Name: \(voice.name)")
  print("  Identifier: \(voice.identifier)")
  print("  Language: \(voice.language)")
  print("  Quality: \(voice.quality.rawValue)")
  print()
}

print("Total: \(germanVoices.count) German voices")
