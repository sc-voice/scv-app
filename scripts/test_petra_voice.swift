#!/usr/bin/env swift
import AVFoundation
import Foundation

print("=== Testing Petra Voice ===\n")

// Find Petra voice
let allVoices = AVSpeechSynthesisVoice.speechVoices()
if let petra = allVoices.first(where: { $0.identifier == "com.apple.voice.premium.de-DE.Petra" }) {
    print("✓ Found Petra voice:")
    print("  Name: \(petra.name)")
    print("  Identifier: \(petra.identifier)")
    print("  Language: \(petra.language)")
    print("  Quality: \(petra.quality.rawValue)")
    print()

    // Try to create a voice using the identifier
    print("Testing voice creation with identifier...")
    if let voiceFromId = AVSpeechSynthesisVoice(identifier: petra.identifier) {
        print("✓ Successfully created voice from identifier")
        print("  Name: \(voiceFromId.name)")
        print("  Identifier: \(voiceFromId.identifier)")
    } else {
        print("✗ Failed to create voice from identifier '\(petra.identifier)'")
    }
    print()

    // Try synthesis test
    print("Testing synthesis with Petra voice...")
    let utterance = AVSpeechUtterance(string: "so habe ich gehoert")
    utterance.voice = AVSpeechSynthesisVoice(identifier: petra.identifier)

    let synthesizer = AVSpeechSynthesizer()

    var completed = false
    var errorOccurred = false
    var errorMessage = ""

    // Use a simple delegate to track status
    class TestDelegate: NSObject, AVSpeechSynthesizerDelegate {
        var onComplete: (() -> Void)?
        var onError: ((String) -> Void)?

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
            print("  ✓ Synthesis started")
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            print("  ✓ Synthesis finished")
            onComplete?()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            print("  ✗ Synthesis cancelled")
            onError?("Synthesis was cancelled")
        }
    }

    let delegate = TestDelegate()
    delegate.onComplete = { completed = true }
    delegate.onError = { msg in
        errorOccurred = true
        errorMessage = msg
    }

    synthesizer.delegate = delegate
    synthesizer.speak(utterance)

    // Wait for completion (max 5 seconds)
    let startTime = Date()
    while !completed && !errorOccurred && Date().timeIntervalSince(startTime) < 5.0 {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    if completed {
        print("\n✓ Test PASSED: Petra voice works correctly")
    } else if errorOccurred {
        print("\n✗ Test FAILED: \(errorMessage)")
    } else {
        print("\n✗ Test FAILED: Timeout after 5 seconds")
    }

} else {
    print("✗ Petra voice not found in available voices")
}
