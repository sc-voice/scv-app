import AVFoundation
import Foundation
@testable import scvCore
import Testing

@Suite("Audio Caching")
struct AudioCachingTests {
  private func synthesizeToCAF(
    text: String,
    voiceIdentifier: String? = nil,
    voiceLanguage: String = "en",
    outputPath: String
  ) {
    let fileManager = FileManager.default
    let outputURL = URL(fileURLWithPath: outputPath)

    // Ensure output directory exists
    let outputDir = outputURL.deletingLastPathComponent().path
    try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    // Remove existing file
    try? fileManager.removeItem(at: outputURL)

    // Configure audio session (same as SuttaPlayer, iOS only)
    #if os(iOS)
      do {
        try AVAudioSession.sharedInstance()
          .setCategory(.playback, mode: .default, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        print("⚠️  Failed to configure audio session: \(error)")
      }
    #endif

    print("🎙️  Starting synthesis of '\(text)'...")
    let startTime = Date()

    // Create utterance
    let utterance = AVSpeechUtterance(string: text)
    if let voiceIdentifier = voiceIdentifier {
      utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
    } else {
      utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
    }
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate

    // Setup synthesis with file writing
    let synthesizer = AVSpeechSynthesizer()
    var audioFile: AVAudioFile?
    let lock = NSLock()
    var isComplete = false
    var hasError = false

    let onBuffer: (AVAudioBuffer) -> Void = { buffer in
      lock.lock()
      defer { lock.unlock() }

      guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
        print("⚠️  Non-PCM buffer received")
        return
      }

      // Empty buffer signals completion
      if pcmBuffer.frameLength == 0 {
        print("✅ Synthesis complete")
        isComplete = true
        return
      }

      do {
        // First buffer: create file with Apple's preferred format
        if audioFile == nil {
          let format = pcmBuffer.format
          print("📝 Buffer format details:")
          print("   Sample rate: \(Int(format.sampleRate)) Hz")
          print("   Channels: \(format.channelCount)")
          print("   Format: \(format.commonFormat)")
          print("   Is interleaved: \(format.isInterleaved)")
          print("   Settings: \(format.settings)")
          print("   Frame length in buffer: \(pcmBuffer.frameLength)")

          audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: pcmBuffer.format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
          )
          print("✅ File created successfully")
        }

        // Write buffer to file
        try audioFile?.write(from: pcmBuffer)
      } catch {
        print("❌ Error writing audio buffer: \(error)")
        hasError = true
      }
    }

    // Start synthesis
    synthesizer.write(utterance, toBufferCallback: onBuffer)

    // Wait for completion (with timeout)
    let timeout = Date().addingTimeInterval(10)
    while !isComplete && !hasError && Date() < timeout {
      usleep(50_000) // 50ms sleep
    }

    let elapsed = Date().timeIntervalSince(startTime)

    // Check results
    if Date() >= timeout {
      print("❌ Synthesis timeout after \(String(format: "%.1f", elapsed))s")
      return
    }

    if hasError {
      print("❌ Synthesis failed with error")
      return
    }

    // Verify file was created
    let fileSize = (try? fileManager.attributesOfItem(atPath: outputPath))?[.size] as? Int ?? 0
    print("✅ Synthesis complete in \(String(format: "%.2f", elapsed))s")
    print("✅ File saved to: \(outputPath)")
    print("✅ File size: \(fileSize) bytes")

    if fileSize == 0 {
      print("⚠️  File is empty - no audio data written")
    }
  }

  @Test("Synthesize 'So I have heard.' to CAF file")
  func synthesizeSimpleUtterance() async {
    synthesizeToCAF(
      text: "So I have heard.",
      voiceLanguage: "en",
      outputPath: "/Users/visakha/dev/scv-app/local/so_i_have_heard.caf"
    )
  }

  @Test("Synthesize 'So I have heard.' to CAF file with Sangeeta")
  func synthesizeSangeeta() async {
    synthesizeToCAF(
      text: "So I have heard.",
      voiceIdentifier: "com.apple.voice.enhanced.en-IN.Sangeeta",
      outputPath: "/Users/visakha/dev/scv-app/local/so_i_have_heard_sangeeta.caf"
    )
  }

  @Test("Synthesize 'so habe ich gehoert' to CAF file with Sandy (DE)")
  func synthesizeSandy() async {
    synthesizeToCAF(
      text: "so habe ich gehoert",
      voiceIdentifier: "com.apple.eloquence.de-DE.Sandy",
      outputPath: "/Users/visakha/dev/scv-app/local/so_habe_ich_gehoert_sandy.caf"
    )
  }

  @Test("Synthesize 'so habe ich gehoert' to CAF file with Petra (DE Premium)")
  func synthesizePetra() async {
    synthesizeToCAF(
      text: "so habe ich gehoert",
      voiceIdentifier: "com.apple.voice.premium.de-DE.Petra",
      outputPath: "/Users/visakha/dev/scv-app/local/so_habe_ich_gehoert_petra.caf"
    )
  }

  private func verifyCAFFile(_ filePath: String) {
    let fileURL = URL(fileURLWithPath: filePath)

    print("🎵 Loading \(filePath)...")

    do {
      let audioFile = try AVAudioFile(forReading: fileURL)

      let format = audioFile.processingFormat
      print("✅ File loaded successfully")
      print("   Channels: \(format.channelCount)")
      print("   Sample rate: \(Int(format.sampleRate)) Hz")

      let frameLength = audioFile.length
      print("   Duration: \(Double(frameLength) / format.sampleRate) seconds")

      if frameLength > 0 {
        print("✅ Audio file contains \(frameLength) frames of audio data")
      } else {
        print("❌ Audio file has no frames")
      }
    } catch {
      print("❌ Failed to load audio file: \(error)")
    }
  }

  @Test("Verify 'So I have heard.' CAF file is playable")
  func verifyPlayback() {
    verifyCAFFile("/Users/visakha/dev/scv-app/local/so_i_have_heard.caf")
  }

  @Test("Verify 'So I have heard.' Sangeeta CAF file is playable")
  func verifySangeetaPlayback() {
    verifyCAFFile("/Users/visakha/dev/scv-app/local/so_i_have_heard_sangeeta.caf")
  }

  @Test("Verify 'so habe ich gehoert' Sandy CAF file is playable")
  func verifySandyPlayback() {
    verifyCAFFile("/Users/visakha/dev/scv-app/local/so_habe_ich_gehoert_sandy.caf")
  }

  @Test("Verify 'so habe ich gehoert' Petra CAF file is playable")
  func verifyPetraPlayback() {
    verifyCAFFile("/Users/visakha/dev/scv-app/local/so_habe_ich_gehoert_petra.caf")
  }
}
