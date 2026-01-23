import AVFoundation
import Foundation
@testable import scvCore
import Testing

@Suite("Audio Store")
struct AudioStoreTests {
  private let cc = ColorConsole(
    "AudioStoreTests",
    "synthesizeToCAF",
    dbg.SuttaPlayer.other,
  )

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
      outputPath: "/Users/visakha/dev/scv-app/local/audio/so_i_have_heard.caf",
      timeout: 1,
    )
  }

  @Test("Synthesize 'So I have heard.' to CAF file with Sangeeta")
  func synthesizeSangeeta() async {
    synthesizeToCAF(
      text: "So I have heard.",
      voiceIdentifier: "com.apple.voice.enhanced.en-IN.Sangeeta",
      outputPath: "/Users/visakha/dev/scv-app/local/audio/so_i_have_heard_sangeeta.caf",
      timeout: 1,
    )
  }

  @Test("Synthesize 'so habe ich gehoert' to CAF file with Sandy (DE)")
  func synthesizeSandy() async {
    synthesizeToCAF(
      text: "so habe ich gehoert",
      voiceIdentifier: "com.apple.eloquence.de-DE.Sandy",
      outputPath: "/Users/visakha/dev/scv-app/local/audio/so_habe_ich_gehoert_sandy.caf",
      timeout: 1,
    )
  }

  @Test("Synthesize 'so habe ich gehoert' to CAF file with Petra (DE Premium)")
  func synthesizePetra() async {
    synthesizeToCAF(
      text: "so habe ich gehoert",
      voiceIdentifier: "com.apple.voice.premium.de-DE.Petra",
      outputPath: "/Users/visakha/dev/scv-app/local/audio/so_habe_ich_gehoert_petra.caf",
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
    verifyCAFFile("/Users/visakha/dev/scv-app/local/audio/so_i_have_heard.caf")
  }

  @Test("Verify 'So I have heard.' Sangeeta CAF file is playable")
  func verifySangeetaPlayback() {
    verifyCAFFile(
      "/Users/visakha/dev/scv-app/local/audio/so_i_have_heard_sangeeta.caf",
    )
  }

  @Test("Verify 'so habe ich gehoert' Sandy CAF file is playable")
  func verifySandyPlayback() {
    verifyCAFFile(
      "/Users/visakha/dev/scv-app/local/audio/so_habe_ich_gehoert_sandy.caf",
    )
  }

  @Test("Verify 'so habe ich gehoert' Petra CAF file is playable")
  func verifyPetraPlayback() {
    verifyCAFFile(
      "/Users/visakha/dev/scv-app/local/audio/so_habe_ich_gehoert_petra.caf",
    )
  }

  @Test("audioUrl with forceUrl=true returns URL with exact path structure")
  func audioUrlForceUrl() {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")
    let text = "test text"

    let url = store.audioUrl(text: text, audioContext: context, forceUrl: true)

    // Compute expected path manually
    let mj = MerkleJson()
    let storageKey = mj.hash(["text": text, "audioContext": context.hash])
    let hashPrefix = String(context.hash.prefix(7))
    let volume = "en-\(hashPrefix)"
    let chapter = String(storageKey.prefix(2))
    let expectedPath = "\(tempDir.path)/\(volume)/\(chapter)/\(storageKey).caf"

    #expect(
      url?.path == expectedPath,
      "URL path should be exact: \(expectedPath)",
    )
  }

  @Test("create() with default path")
  func createDefault() {
    let store = AudioStore.create()
    let context = AudioContext(for: "en")
    let url = store.audioUrl(
      text: "test",
      audioContext: context,
      forceUrl: true,
    )
    #expect(url != nil, "Should return URL with default path")
  }

  @Test("create(path:) with custom path")
  func createCustomPath() {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")
    let url = store.audioUrl(
      text: "test",
      audioContext: context,
      forceUrl: true,
    )
    #expect(
      url?.path.contains(tempDir.path) == true,
      "URL should use custom path",
    )
  }

  @Test("shared is singleton")
  func sharedSingleton() {
    let store1 = AudioStore.shared
    let store2 = AudioStore.shared
    #expect(store1 === store2, "shared should return same instance")
  }

  @Test("create(path:) creates separate instances")
  func createSeparateInstances() {
    let path1 = URL(fileURLWithPath: "/tmp/audio-store-\(UUID().uuidString)")
    let path2 = URL(fileURLWithPath: "/tmp/audio-store-\(UUID().uuidString)")
    let store1 = AudioStore.create(path: path1)
    let store2 = AudioStore.create(path: path2)
    #expect(store1 !== store2, "create() should return separate instances")
  }

  @Test("timeout property has correct default")
  func timeoutDefault() {
    let store = AudioStore.create()
    #expect(store.timeout == 5, "Default timeout should be 5s")
  }

  @Test("timeout can be customized")
  func timeoutCustom() {
    let store = AudioStore.create(timeout: 2)
    #expect(store.timeout == 2, "Timeout should be customizable via create()")
  }

  @Test("storeAudio synthesizes and returns URL")
  func storeAudioSynthesizes() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")
    let text = "So I have heard."

    let url = try await store.storeAudio(text: text, audioContext: context)

    // Verify file was created
    #expect(
      FileManager.default.fileExists(atPath: url.path),
      "Audio file should exist after synthesis",
    )

    // Verify file has content
    let fileSize = try FileManager.default
      .attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
    #expect(
      fileSize > 50000,
      "Synthesized CAF file should be at least 50KB (got \(fileSize) bytes)",
    )

    // Verify file is readable as audio
    let audioFile = try AVAudioFile(forReading: url)
    #expect(audioFile.length > 0, "Audio file should contain audio frames")
  }

  @Test("storeAudio returns cached file on second call")
  func storeAudioCachesFile() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")
    let text = "So I have heard."

    // First synthesis
    let startTime1 = Date()
    let url1 = try await store.storeAudio(text: text, audioContext: context)
    let elapsed1 = Date().timeIntervalSince(startTime1)

    // Second call should return immediately (cached)
    let startTime2 = Date()
    let url2 = try await store.storeAudio(text: text, audioContext: context)
    let elapsed2 = Date().timeIntervalSince(startTime2)

    #expect(url1 == url2, "Same text should return same URL")
    #expect(
      elapsed2 < elapsed1 / 2,
      "Cached call should be much faster (expected <\(elapsed1 / 2)s, got \(elapsed2)s)",
    )
  }

  @Test("storeAudio uses different contexts for different voices")
  func storeAudioDifferentContexts() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let entext = "So I have heard."
    let detext = "so habe ich gehoert."

    // Same text, different contexts should produce different files
    let contextEn = AudioContext(for: "en")
    let contextDe = AudioContext(for: "de")

    let urlEn = try await store.storeAudio(
      text: entext,
      audioContext: contextEn,
    )
    let urlDe = try await store.storeAudio(
      text: detext,
      audioContext: contextDe,
    )

    #expect(
      urlEn != urlDe,
      "Different contexts should produce different file paths",
    )
    #expect(
      FileManager.default.fileExists(atPath: urlEn.path),
      "English audio file should exist",
    )
    #expect(
      FileManager.default.fileExists(atPath: urlDe.path),
      "German audio file should exist",
    )
  }

  @Test("storeAudio throws on empty text")
  func storeAudioEmptyText() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")

    do {
      _ = try await store.storeAudio(text: "", audioContext: context)
      #expect(false, "Should throw error for empty text")
    } catch {
      #expect(
        "\(error)".contains("empty text"),
        "Error should indicate empty text: \(error)",
      )
    }
  }

  @Test("compactContextVolumes with no volumes returns zero status")
  func compactContextVolumesEmptyStore() async {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")

    let status = await store.compactContextVolumes(context: context)

    #expect(status.volumesScanned == 0, "Should scan zero volumes")
    #expect(status.volumesDeleted == 0, "Should delete zero volumes")
    #expect(status.volumesKept == 0, "Should keep zero volumes")
    #expect(status.elapsedSeconds >= 0, "Elapsed time should be non-negative")
  }

  @Test("compactContextVolumes keeps current context volume")
  func compactContextVolumesKeepsCurrentVolume() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")
    let text = "So I have heard."

    // Create audio file (builds current context volume)
    _ = try await store.storeAudio(text: text, audioContext: context)

    // Compact with same context
    let status = await store.compactContextVolumes(context: context)

    #expect(status.volumesScanned == 1, "Should scan one volume")
    #expect(
      status.volumesDeleted == 0,
      "Should delete zero volumes (current context)",
    )
    #expect(status.volumesKept == 1, "Should keep one volume (current context)")
  }

  @Test("compactContextVolumes deletes orphaned volumes with different hash")
  func compactContextVolumesDeletesOrphaned() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let text = "So I have heard."

    // Create audio with first context
    let contextV1 = AudioContext(for: "en")
    _ = try await store.storeAudio(text: text, audioContext: contextV1)

    // Create audio with different settings (simulating user changing pitch)
    var settingsV2 = Settings.shared
    settingsV2.docLangSettings[.english]?.pitch = 1.5
    let contextV2 = AudioContext(for: "en", from: settingsV2)

    _ = try await store.storeAudio(text: text, audioContext: contextV2)

    // Verify both volumes exist before compaction
    let volumesBefore = try await store.listVolumes()
    let enVolumes = volumesBefore.filter { $0.hasPrefix("en-") }
    #expect(
      enVolumes.count == 2,
      "Should have two volumes for en (different contexts)",
    )

    // Compact with contextV2 - should delete contextV1 volume
    let status = await store.compactContextVolumes(context: contextV2)

    #expect(status.volumesScanned == 2, "Should scan two volumes")
    #expect(status.volumesDeleted == 1, "Should delete one orphaned volume")
    #expect(status.volumesKept == 1, "Should keep one volume (current context)")

    // Verify orphaned volume was deleted
    let volumesAfter = try await store.listVolumes()
    let enVolumesAfter = volumesAfter.filter { $0.hasPrefix("en-") }
    #expect(
      enVolumesAfter.count == 1,
      "Should have one volume after compaction",
    )
  }

  @Test("compactContextVolumes ignores other languages")
  func compactContextVolumesIgnoresOtherLanguages() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let text = "test"

    // Create audio for English
    let contextEn = AudioContext(for: "en")
    _ = try await store.storeAudio(text: text, audioContext: contextEn)

    // Create audio for German
    let contextDe = AudioContext(for: "de")
    _ = try await store.storeAudio(text: text, audioContext: contextDe)

    // Create new English context with different settings (simulating user
    // changing pitch)
    var settingsEnV2 = Settings.shared
    settingsEnV2.docLangSettings[.english]?.pitch = 1.5
    let contextEnV2 = AudioContext(for: "en", from: settingsEnV2)
    _ = try await store.storeAudio(text: text, audioContext: contextEnV2)

    // Compact with contextEnV2 - should delete contextEn volume and keep
    // contextEnV2
    let status = await store.compactContextVolumes(context: contextEnV2)

    // Should only scan/process English volumes (2 total: old en and new en)
    #expect(status.volumesScanned == 2, "Should scan both English volumes")
    #expect(status.volumesDeleted == 1, "Should delete old English volume")
    #expect(status.volumesKept == 1, "Should keep new English volume")

    // Verify German volume still exists
    let volumesAfter = try await store.listVolumes()
    let deVolumesAfter = volumesAfter.filter { $0.hasPrefix("de-") }
    #expect(deVolumesAfter.count == 1, "German volume should not be affected")

    // Verify retained English volume is for current context (contextEnV2)
    let enVolumesAfter = volumesAfter.filter { $0.hasPrefix("en-") }
    let currentHashPrefix = String(contextEnV2.hash.prefix(7))
    let retainedEnVolume = enVolumesAfter
      .first { $0.contains(currentHashPrefix) }
    #expect(
      retainedEnVolume != nil,
      "Retained English volume should match current context hash: en-\(currentHashPrefix)",
    )
  }

  @Test("compactContextVolumes measures elapsed time")
  func compactContextVolumesMeasuresElapsed() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")
    let text = "So I have heard."

    // Create audio
    _ = try await store.storeAudio(text: text, audioContext: context)

    // Compact and verify elapsed time is recorded
    let status = await store.compactContextVolumes(context: context)

    #expect(
      status.elapsedSeconds >= 0,
      "Elapsed time must be non-negative",
    )
    #expect(
      status.elapsedSeconds < 10,
      "Compaction should complete within 10 seconds (BUG if exceeded)",
    )
  }

  @Test("compactContextVolumes returns consistent results on empty store")
  func compactContextVolumesEmptyStoreConsistent() async {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(path: tempDir)
    let context = AudioContext(for: "en")

    // Run twice on empty store
    let status1 = await store.compactContextVolumes(context: context)
    let status2 = await store.compactContextVolumes(context: context)

    #expect(status1.volumesScanned == status2.volumesScanned)
    #expect(status1.volumesDeleted == status2.volumesDeleted)
    #expect(status1.volumesKept == status2.volumesKept)
  }
}
