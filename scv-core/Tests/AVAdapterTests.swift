//
//  AVAdapterTests.swift
//  scv-core
//
//  Created by Visakha on 23/02/2026.
//

import AVFoundation
import Foundation
import Testing

@testable import scvCore

// MARK: - AVAdapterTests

@Suite struct AVAdapterTests {
  // MARK: - AudioPlayerID Tests

  @Test("createPlayer fails with non-existent file")
  func createPlayerFailsWithInvalidFile() {
    let adapter = AVAdapter()
    let invalidURL =
      URL(fileURLWithPath: "/tmp/nonexistent-audio-file-\(UUID()).caf")

    #expect(throws: Error.self) {
      try adapter.createPlayer(contentsOf: invalidURL)
    }
  }

  @Test("synthesizeToFile")
  func synthesizeToFile() async throws {
    let adapter: IAVAdapter = AVAdapter()

    // Create audio file in local/build
    let outDir = projectRoot().appendingPathComponent("local/audio", isDirectory: true)
    try? FileManager.default.createDirectory(
      at: outDir,
      withIntermediateDirectories: true,
    )
    let audioURL = outDir
      .appendingPathComponent("test-core-synthesizeToFile.caf")

    // Create minimal audio file using AudioContext
    let audioContext = AudioContext(for: "en")
    let text = "test synthesize to file"

    // Use AVSpeechSynthesizer to create a real audio file
    try await adapter.synthesizeToFile(
      text: text,
      audioContext: audioContext,
      outputURL: audioURL,
    )

    // Create two players from same file
    let id1 = try adapter.createPlayer(contentsOf: audioURL)
    let id2 = try adapter.createPlayer(contentsOf: audioURL)
    #expect(id1 != id2)

    let duration1 = adapter.duration(id: id1)
    let duration2 = adapter.duration(id: id2)
    #expect(duration1 >= 0)
    #expect(duration1 == duration2)

    #expect(!adapter.isPlaying(id: id1))

    let currentTime = adapter.currentTime(id: id1)
    #expect(currentTime == 0)

    // File should have non-zero size
    let attributes = try FileManager.default
      .attributesOfItem(atPath: audioURL.path)
    let fileSize = attributes[.size] as? Int ?? 0
    #expect(fileSize > 0)
  }

  // MARK: - Player State Tests

  @Test("synthesizeToFile respects audioContext settings")
  func synthesizeRespectsAudioContext() async throws {
    let adapter = AVAdapter()
    let tempDir = FileManager.default.temporaryDirectory

    // Create custom settings
    let settings = Settings()
    settings.docLang = .english
    if var englishSettings = settings.docLangSettings[.english] {
      englishSettings.pitch = 1.5
      englishSettings.rate = 0.8
      settings.docLangSettings[.english] = englishSettings
    }

    let audioContext = AudioContext(for: "en", from: settings)

    let audioURL = tempDir
      .appendingPathComponent("test-synthesis-custom-\(UUID()).caf")

    defer {
      try? FileManager.default.removeItem(at: audioURL)
    }

    // Should not throw with custom settings
    try await adapter.synthesizeToFile(
      text: "Test with custom settings",
      audioContext: audioContext,
      outputURL: audioURL,
    )

    #expect(FileManager.default.fileExists(atPath: audioURL.path))
  }
}
