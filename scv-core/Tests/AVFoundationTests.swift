//
//  AVFoundationTests.swift
//  scv-core
//
//  Tests for raw AVFoundation synthesis behavior (not AVAdapter abstraction)
//

import AVFoundation
import Foundation
import Testing

@testable import scvCore

// MARK: - AVFoundationTests

// DN10 segment dn10:2.32.2 (constant for benchmarking)
let dn10_2_32_2_text = """
With clairvoyance that is purified and superhuman, they see sentient beings passing away and being reborn—inferior and superior, beautiful and ugly, in a good place or a bad place. They understand how sentient beings pass on according to their deeds. 'These dear beings did bad things by way of body, speech, and mind. They denounced the noble ones; they had wrong view; and they chose to act out of that wrong view. When their body breaks up, after death, they're reborn in a place of loss, a bad place, the underworld, hell. These dear beings, however, did good things by way of body, speech, and mind. They never denounced the noble ones; they had right view; and they chose to act out of that right view. When their body breaks up, after death, they're reborn in a good place, a heavenly realm.' And so, with clairvoyance that is purified and superhuman, they see sentient beings passing away and being reborn—inferior and superior, beautiful and ugly, in a good place or a bad place. They understand how sentient beings pass on according to their deeds.
"""

@Suite(.tags(.research))
struct AVFoundationTests {
  private let cc = ColorConsole(#file, #function, dbg.AudioStore.other)

  private func synthesizeToCAF(
    text: String,
    voiceIdentifier: String? = nil,
    voiceLanguage: String = "en",
    outputPath: String,
    timeout: TimeInterval = 5,
  ) {
    let fileManager = FileManager.default
    let outputURL = URL(fileURLWithPath: outputPath)

    // Ensure output directory exists
    let outputDir = outputURL.deletingLastPathComponent().path
    try? fileManager.createDirectory(
      atPath: outputDir,
      withIntermediateDirectories: true,
    )

    // Remove existing file
    try? fileManager.removeItem(at: outputURL)

    // Configure audio session (same as SuttaPlayer, iOS only)
    #if os(iOS)
      do {
        try AVAudioSession.sharedInstance()
          .setCategory(.playback, mode: .default, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        cc.bad2(#line, "Failed to configure audio session: \(error)")
      }
    #endif

    cc.ok2(#line, "Starting synthesis of '\(text)'...")
    let startTime = Date()

    // Create utterance
    let utterance = AVSpeechUtterance(string: text)
    if let voiceIdentifier {
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
        cc.bad2(#line, "Non-PCM buffer received")
        return
      }

      // Empty buffer signals completion
      if pcmBuffer.frameLength == 0 {
        cc.ok2(#line, "Synthesis complete")
        isComplete = true
        return
      }

      do {
        // First buffer: create file with Apple's preferred format
        if audioFile == nil {
          let format = pcmBuffer.format
          cc.ok2(#line, "Buffer format details:")
          cc.ok2(#line, "Sample rate: \(Int(format.sampleRate)) Hz")
          cc.ok2(#line, "Channels: \(format.channelCount)")
          cc.ok2(#line, "Format: \(format.commonFormat)")
          cc.ok2(#line, "Is interleaved: \(format.isInterleaved)")
          cc.ok2(#line, "Settings: \(format.settings)")
          cc.ok2(#line, "Frame length in buffer: \(pcmBuffer.frameLength)")

          audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: pcmBuffer.format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false,
          )
          cc.ok2(#line, "File created successfully")
        }

        // Write buffer to file
        try audioFile?.write(from: pcmBuffer)
      } catch {
        cc.bad2(#line, "Error writing audio buffer: \(error)")
        hasError = true
      }
    }

    // Start synthesis
    synthesizer.write(utterance, toBufferCallback: onBuffer)

    // Wait for completion (with configurable timeout)
    let timeoutDate = Date().addingTimeInterval(timeout)
    while !isComplete, !hasError, Date() < timeoutDate {
      usleep(50000) // 50ms sleep
    }

    let elapsed = Date().timeIntervalSince(startTime)

    // Check results - failure if synthesis exceeds timeout
    if Date() >= timeoutDate {
      cc.bad1(
        #line,
        "Synthesis timeout after \(String(format: "%.1f", elapsed))s",
      )
      #expect(
        Date() < timeoutDate,
        "Synthesis must complete within \(timeout)s (BUG if exceeded)",
      )
      return
    }

    if hasError {
      cc.bad1(#line, "Synthesis failed with error")
      #expect(!hasError, "Synthesis must complete without errors")
      return
    }

    // Verify file was created
    let fileSize = (try? fileManager
      .attributesOfItem(atPath: outputPath))?[.size] as? Int ?? 0
    cc.ok1(#line, "Synthesis complete in \(String(format: "%.2f", elapsed))s")
    cc.ok1(#line, "File saved to: \(outputPath)")
    cc.ok1(#line, "File size: \(fileSize) bytes")

    if fileSize == 0 {
      cc.bad2(#line, "File is empty - no audio data written")
    }
    #expect(
      fileSize >= 50000,
      "Audio file must contain audio data (expected >= 50KB, got \(fileSize) bytes)",
    )
  }

  @Test("Synthesize 'So I have heard.' to CAF file")
  func synthesizeSimpleUtterance() async {
    synthesizeToCAF(
      text: "So I have heard.",
      voiceLanguage: "en",
      outputPath: "\(projectRoot().path)/local/audio/so_i_have_heard.caf",
      timeout: 1,
    )
  }

  @Test("Synthesize 'So I have heard.' to CAF file with Sangeeta")
  func synthesizeSangeeta() async {
    synthesizeToCAF(
      text: "So I have heard.",
      voiceIdentifier: "com.apple.voice.enhanced.en-IN.Sangeeta",
      outputPath: "\(projectRoot().path)/local/audio/so_i_have_heard_sangeeta.caf",
      timeout: 1,
    )
  }

  @Test("Synthesize 'so habe ich gehoert' to CAF file with Sandy (DE)")
  func synthesizeSandy() async {
    synthesizeToCAF(
      text: "so habe ich gehoert",
      voiceIdentifier: "com.apple.eloquence.de-DE.Sandy",
      outputPath: "\(projectRoot().path)/local/audio/so_habe_ich_gehoert_sandy.caf",
      timeout: 1,
    )
  }

  @Test("Synthesize 'so habe ich gehoert' to CAF file with Petra (DE Premium)")
  func synthesizePetra() async {
    synthesizeToCAF(
      text: "so habe ich gehoert",
      voiceIdentifier: "com.apple.voice.premium.de-DE.Petra",
      outputPath: "\(projectRoot().path)/local/audio/so_habe_ich_gehoert_petra.caf",
      timeout: 1,
    )
  }

  private func verifyCAFFile(_ filePath: String) {
    let fileURL = URL(fileURLWithPath: filePath)

    cc.ok2(#line, "Loading \(filePath)...")

    do {
      let audioFile = try AVAudioFile(forReading: fileURL)

      let format = audioFile.processingFormat
      cc.ok2(#line, "File loaded successfully")
      cc.ok2(#line, "Channels: \(format.channelCount)")
      cc.ok2(#line, "Sample rate: \(Int(format.sampleRate)) Hz")

      let frameLength = audioFile.length
      cc.ok2(
        #line,
        "Duration: \(Double(frameLength) / format.sampleRate) seconds",
      )

      if frameLength > 0 {
        cc.ok1(#line, "Audio file contains \(frameLength) frames of audio data")
      } else {
        cc.bad1(#line, "Audio file has no frames")
      }
    } catch {
      cc.bad1(#line, "Failed to load audio file: \(error)")
    }
  }

  @Test("Verify 'So I have heard.' CAF file is playable")
  func verifyPlayback() {
    verifyCAFFile("\(projectRoot().path)/local/audio/so_i_have_heard.caf")
  }

  @Test("Verify 'So I have heard.' Sangeeta CAF file is playable")
  func verifySangeetaPlayback() {
    verifyCAFFile(
      "\(projectRoot().path)/local/audio/so_i_have_heard_sangeeta.caf",
    )
  }

  @Test("Verify 'so habe ich gehoert' Sandy CAF file is playable")
  func verifySandyPlayback() {
    verifyCAFFile(
      "\(projectRoot().path)/local/audio/so_habe_ich_gehoert_sandy.caf",
    )
  }

  @Test("Verify 'so habe ich gehoert' Petra CAF file is playable")
  func verifyPetraPlayback() {
    verifyCAFFile(
      "\(projectRoot().path)/local/audio/so_habe_ich_gehoert_petra.caf",
    )
  }
}
