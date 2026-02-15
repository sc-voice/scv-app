#!/usr/bin/env swift
import AVFoundation
import Foundation

print("=== Checking Voice Download Status ===\n")

let allVoices = AVSpeechSynthesisVoice.speechVoices()
let germanVoices = allVoices.filter { $0.language.hasPrefix("de") }

print("German voices status:")
for voice in germanVoices.sorted(by: { $0.name < $1.name }) {
    print("\n\(voice.name) [\(voice.quality.rawValue)]:")
    print("  Identifier: \(voice.identifier)")

    // Try to actually use the voice for synthesis
    let utterance = AVSpeechUtterance(string: "test")
    if let createdVoice = AVSpeechSynthesisVoice(identifier: voice.identifier) {
        utterance.voice = createdVoice

        // Try to synthesize a buffer to see if voice is actually available
        let synthesizer = AVSpeechSynthesizer()
        var receivedBuffer = false
        var bufferWasEmpty = false

        synthesizer.write(utterance) { buffer in
            if let pcmBuffer = buffer as? AVAudioPCMBuffer {
                receivedBuffer = true
                if pcmBuffer.frameLength == 0 {
                    bufferWasEmpty = true
                }
            }
        }

        // Wait briefly for synthesis to start
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 0.5 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        if receivedBuffer {
            if bufferWasEmpty {
                print("  ✓ Voice can be created (synthesis completed)")
            } else {
                print("  ✓ Voice works (received audio data)")
            }
        } else {
            print("  ✗ Voice may not be downloaded (no buffers received)")
        }
    } else {
        print("  ✗ Cannot create voice from identifier")
    }
}
