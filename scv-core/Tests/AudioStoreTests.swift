import AVFoundation
import Foundation
@testable import scvCore
import Testing

// Note: MockAVAdapter is now in scvCore (Sources/MockAVAdapter.swift)
// and can be imported via scvCore

// Flag to control adapter type: false=real AVAdapter, true=MockAVAdapter
let MOCK_AV = true

@Suite("Audio Store")
struct AudioStoreTests {
  @Test(
    "A13s: audioUrl with forceUrl=true returns URL with exact path structure",
  )
  func audioUrlForceUrl() {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(
      path: tempDir,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
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

  @Test("A13s: create() with default path")
  func createDefault() {
    let store = AudioStore
      .create(adapter: MOCK_AV ? MockAVAdapter() : AVAdapter())
    let context = AudioContext(for: "en")
    let url = store.audioUrl(
      text: "test",
      audioContext: context,
      forceUrl: true,
    )
    #expect(url != nil, "Should return URL with default path")
  }

  @Test("A13s: create(path:) with custom path")
  func createCustomPath() async {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(
      path: tempDir,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
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

    let size = await store.diskSize()
    #expect(size == 0, "Empty store should have size 0, got \(size)")
  }

  @Test("A13s: shared is singleton")
  func sharedSingleton() {
    let store1 = AudioStore.shared
    let store2 = AudioStore.shared
    #expect(store1 === store2, "shared should return same instance")
  }

  @Test("A13s: create(path:) creates separate instances")
  func createSeparateInstances() {
    let path1 = URL(fileURLWithPath: "/tmp/audio-store-\(UUID().uuidString)")
    let path2 = URL(fileURLWithPath: "/tmp/audio-store-\(UUID().uuidString)")
    let store1 = AudioStore.create(
      path: path1,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    let store2 = AudioStore.create(
      path: path2,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    #expect(store1 !== store2, "create() should return separate instances")
  }

  @Test("A13s: timeout property has correct default")
  func timeoutDefault() {
    let store = AudioStore
      .create(adapter: MOCK_AV ? MockAVAdapter() : AVAdapter())
    #expect(store.timeout == 5, "Default timeout should be 5s")
  }

  @Test("A13s: timeout can be customized")
  func timeoutCustom() {
    let store = AudioStore.create(
      timeout: 2,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    #expect(store.timeout == 2, "Timeout should be customizable via create()")
  }

  @Test("A13s: storeAudio returns cached file on second call")
  func storeAudioCachesFile() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(
      path: tempDir,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    let context = AudioContext(for: "en")
    let text = "So I have heard."

    // Initial cache size
    let sizeStart = await store.diskSize()
    #expect(sizeStart == 0, "expected 0 cache size")

    // First synthesis
    let startTime1 = Date()
    let url1 = try await store.storeAudio(text: text, audioContext: context)
    let elapsed1 = Date().timeIntervalSince(startTime1)

    // Verify file has content
    let fileSize = try FileManager.default
      .attributesOfItem(atPath: url1.path)[.size] as? Int ?? 0
    #expect(
      fileSize > 50000,
      "Synthesized CAF file should be at least 50KB (got \(fileSize) bytes)",
    )
    // After synthesis: size should be positive
    let sizeAfter1 = await store.diskSize()
    #expect(
      sizeAfter1 > 50000,
      "Size should be > 50KB after synthesis, got \(sizeAfter1) bytes",
    )

    // Second call should return immediately (cached)
    let startTime2 = Date()
    let url2 = try await store.storeAudio(text: text, audioContext: context)
    let elapsed2 = Date().timeIntervalSince(startTime2)

    #expect(url1 == url2, "Same text should return same URL")
    #expect(
      elapsed2 < elapsed1 / 2,
      "Cached call should be much faster (expected <\(elapsed1 / 2)s, got \(elapsed2)s)",
    )

    // After synthesis: size should be same
    let sizeAfter2 = await store.diskSize()
    #expect(sizeAfter1 == sizeAfter2, "expected same cache size")
  }

  @Test("A13s: storeAudio throws on empty text")
  func storeAudioEmptyText() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(
      path: tempDir,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    let context = AudioContext(for: "en")

    do {
      _ = try await store.storeAudio(text: "", audioContext: context)
      #expect(Bool(false), "Should throw error for empty text")
    } catch {
      #expect(
        "\(error)".contains("empty text"),
        "Error should indicate empty text: \(error)",
      )
    }
  }

  // Test disabled: Premium voices (Petra) work fine in native macOS
  // environment.
  // The bug only manifests when running as iPad-on-Mac compatibility mode app.
  // In that mode, premium voices fail silently with 1024 bytes instead of
  // ~100KB+.
  // Our validation logic correctly detects and throws error in that case.
  @Test("A13s: storeAudio throws on premium voice failure (Petra)", .disabled())
  func storeAudioPetraFails() async throws {
    let tempDir =
      URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
    let store = AudioStore.create(
      path: tempDir,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )

    // Create settings with Petra voice
    let settings = Settings()
    settings.docLangSettings[.german]?.voiceId =
      "com.apple.voice.premium.de-DE.Petra"

    let context = AudioContext(for: "de", from: settings)
    let text = "so habe ich gehoert"

    do {
      _ = try await store.storeAudio(text: text, audioContext: context)
      #expect(Bool(false), "Should throw error for unavailable premium voice")
    } catch {
      cc.ok1(#line, "Expected error caught: \(error)")
      #expect(
        "\(error)".contains("insufficient audio data"),
        "Error should indicate insufficient audio data: \(error)",
      )
    }
  }

  #if COMPACT_CONTEXT_VOLUMES
    @Test("A13s: compactContextVolumes with no volumes returns zero status")
    func compactContextVolumesEmptyStore() async {
      let tempDir =
        URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
      let store = AudioStore.create(
        path: tempDir,
        adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
      )
      let context = AudioContext(for: "en")

      let status = await store.compactContextVolumes(context: context)

      #expect(status.volumesScanned == 0, "Should scan zero volumes")
      #expect(status.volumesDeleted == 0, "Should delete zero volumes")
      #expect(status.volumesKept == 0, "Should keep zero volumes")
      #expect(status.elapsedSeconds >= 0, "Elapsed time should be non-negative")
    }

    @Test("A13s: compactContextVolumes keeps current context volume")
    func compactContextVolumesKeepsCurrentVolume() async throws {
      let tempDir =
        URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
      let store = AudioStore.create(
        path: tempDir,
        adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
      )
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
      #expect(
        status.volumesKept == 1,
        "Should keep one volume (current context)",
      )
    }

    @Test(
      "A13s: compactContextVolumes deletes orphaned volumes with different hash",
    )
    func compactContextVolumesDeletesOrphaned() async throws {
      let tempDir =
        URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
      let store = AudioStore.create(
        path: tempDir,
        adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
      )
      let text = "So I have heard."

      // Create single Settings instance for this test
      let settings = Settings()

      // Create audio with first context
      let contextV1 = AudioContext(for: "en", from: settings)
      _ = try await store.storeAudio(text: text, audioContext: contextV1)

      // Modify settings and create audio with different context (simulating
      // user
      // changing pitch)
      settings.docLangSettings[.english]?.pitch = 1.5
      let contextV2 = AudioContext(for: "en", from: settings)

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
      #expect(
        status.volumesKept == 1,
        "Should keep one volume (current context)",
      )

      // Verify orphaned volume was deleted
      let volumesAfter = try await store.listVolumes()
      let enVolumesAfter = volumesAfter.filter { $0.hasPrefix("en-") }
      #expect(
        enVolumesAfter.count == 1,
        "Should have one volume after compaction",
      )
    }

    @Test("A13s: compactContextVolumes ignores other languages")
    func compactContextVolumesIgnoresOtherLanguages() async throws {
      let tempDir =
        URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
      let store = AudioStore.create(
        path: tempDir,
        adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
      )
      let text = "test"

      // Create single Settings instance for this test
      let settings = Settings()

      // Create audio for English
      let contextEn = AudioContext(for: "en", from: settings)
      _ = try await store.storeAudio(text: text, audioContext: contextEn)

      // Create audio for German
      let contextDe = AudioContext(for: "de", from: settings)
      _ = try await store.storeAudio(text: text, audioContext: contextDe)

      // Modify settings and create new English context with different settings
      // (simulating user
      // changing pitch)
      settings.docLangSettings[.english]?.pitch = 1.5
      let contextEnV2 = AudioContext(for: "en", from: settings)
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

    @Test("A13s: compactContextVolumes measures elapsed time")
    func compactContextVolumesMeasuresElapsed() async throws {
      let tempDir =
        URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
      let store = AudioStore.create(
        path: tempDir,
        adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
      )
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

    @Test(
      "A13s: compactContextVolumes returns consistent results on empty store",
    )
    func compactContextVolumesEmptyStoreConsistent() async {
      let tempDir =
        URL(fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)")
      let store = AudioStore.create(
        path: tempDir,
        adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
      )
      let context = AudioContext(for: "en")

      // Run twice on empty store
      let status1 = await store.compactContextVolumes(context: context)
      let status2 = await store.compactContextVolumes(context: context)

      #expect(status1.volumesScanned == status2.volumesScanned)
      #expect(status1.volumesDeleted == status2.volumesDeleted)
      #expect(status1.volumesKept == status2.volumesKept)
    }
  #endif // COMPACT_CONTEXT_VOLUMES

  @Test("A13s: BENCHMARK: dn10:2.32.2 CAF synthesis performance")
  func benchmarkDN10CAFSynthesis() async throws {
    let fileManager = FileManager.default
    let root = projectRoot()
    let outputDir = root.appendingPathComponent("local/audio")
    try fileManager.createDirectory(
      at: outputDir,
      withIntermediateDirectories: true,
    )

    let store = AudioStore.create(
      path: outputDir,
      type: .caf,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    let context = AudioContext(for: "en")

    print("\n=== dn10:2.32.2 CAF SYNTHESIS BENCHMARK ===")
    print("Segment: dn10:2.32.2")
    print("Text: \(dn10_2_32_2_text.prefix(100))...")
    print("Text length: \(dn10_2_32_2_text.count) characters\n")

    let synthesisStart = Date()
    do {
      let url = try await store.storeAudio(
        text: dn10_2_32_2_text,
        audioContext: context,
      )
      let synthesisElapsed = Date().timeIntervalSince(synthesisStart)
      let fileSize = try FileManager.default
        .attributesOfItem(atPath: url.path)[.size] as? Int ?? 0

      print("=== CAF SYNTHESIS RESULTS ===")
      print("Synthesis time: \(String(format: "%.3f", synthesisElapsed))s")
      print("File size: \(fileSize) bytes (\(fileSize / 1024) KB)")

      cc.ok1(
        #line,
        "dn10:2.32.2 CAF benchmark: \(String(format: "%.3f", synthesisElapsed))s, \(fileSize / 1024) KB",
      )
    } catch {
      print("=== CAF SYNTHESIS FAILED ===")
      print("Error: \(error)")
      cc.bad1(#line, "dn10:2.32.2 CAF synthesis failed: \(error)")
    }
  }

  @Test("A13s: BENCHMARK: DN10:2.32.2 CAF synthesis and M4A conversion")
  func benchmarkDN10_2_32_2_CAF_M4A() async throws {
    let root = projectRoot()
    let outputDir = root.appendingPathComponent("local/audio")
    let cafStore = AudioStore.create(
      path: outputDir,
      type: .caf,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    let context = AudioContext(for: "en")

    print("Text: \(dn10_2_32_2_text.prefix(100))...")
    print("Text length: \(dn10_2_32_2_text.count) characters\n")

    // 1️⃣ Synthesize to CAF
    print("1️⃣ CAF Synthesis (synthesis + file write):")
    let cafStart = Date()
    let cafUrl = try await cafStore.storeAudio(
      text: dn10_2_32_2_text,
      audioContext: context,
    )
    let cafTime = Date().timeIntervalSince(cafStart)
    let cafSize = try FileManager.default
      .attributesOfItem(atPath: cafUrl.path)[.size] as? Int ?? 0

    print("   Time: \(String(format: "%.3f", cafTime))s")
    print("   Size: \(cafSize) bytes (\(cafSize / 1024) KB)\n")

    // 2️⃣ Convert CAF to M4A (measure conversion time only)
    print("2️⃣ CAF→M4A Conversion (read CAF + afconvert + write M4A):")
    let m4aUrl = URL(fileURLWithPath: cafUrl.path.replacingOccurrences(
      of: ".caf",
      with: ".m4a",
    ))

    let conversionStart = Date()
    do {
      // Run afconvert process
      let process = Process()
      process.launchPath = "/usr/bin/afconvert"
      process.arguments = [
        "-f", "m4af", // Output format: M4A file
        "-d", "aac", // Data format: AAC codec
        cafUrl.path,
        m4aUrl.path,
      ]

      let errorPipe = Pipe()
      process.standardError = errorPipe
      process.standardOutput = Pipe()

      try process.run()
      process.waitUntilExit()

      let conversionTime = Date().timeIntervalSince(conversionStart)

      if process.terminationStatus != 0 {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw NSError(
          domain: "AudioStore",
          code: -4,
          userInfo: [
            NSLocalizedDescriptionKey: "afconvert failed: \(errorMsg.trimmingCharacters(in: .whitespacesAndNewlines))",
          ],
        )
      }

      let m4aSize = try FileManager.default
        .attributesOfItem(atPath: m4aUrl.path)[.size] as? Int ?? 0

      print("   Time: \(String(format: "%.3f", conversionTime))s")
      print("   Size: \(m4aSize) bytes (\(m4aSize / 1024) KB)\n")

      let compressionRatio = Double(cafSize) / Double(m4aSize)
      let spaceSaved = cafSize - m4aSize

      print("=== RESULTS ===")
      print("Segment: dn10:2.32.2 (\(dn10_2_32_2_text.count) chars)")
      print(
        "CAF synthesis: \(String(format: "%.3f", cafTime))s → \(cafSize / 1024) KB",
      )
      print(
        "CAF→M4A conversion: \(String(format: "%.3f", conversionTime))s → \(m4aSize / 1024) KB",
      )
      print("Compression ratio: \(String(format: "%.2f", compressionRatio))x")
      print(
        "Space saved: \(spaceSaved / 1024) KB (\((cafSize - m4aSize) * 100 / cafSize)%)",
      )

      cc.ok1(
        #line,
        "dn10:2.32.2 conversion: synthesis=\(String(format: "%.3f", cafTime))s, convert=\(String(format: "%.3f", conversionTime))s, ratio=\(String(format: "%.2f", compressionRatio))x",
      )
    } catch {
      print("   ✗ Conversion failed: \(error)\n")
      print("=== RESULTS (CAF only) ===")
      print("Segment: dn10:2.32.2")
      print(
        "CAF synthesis: \(String(format: "%.3f", cafTime))s → \(cafSize / 1024) KB",
      )
      print("M4A conversion: ❌ \(error)")
      cc.bad1(#line, "dn10:2.32.2 conversion failed: \(error)")
    }
  }

  @Test("A13s: RESEARCH: AVAudioConverter - Convert so_i_have_heard.caf to M4A")
  func aVAudioConverterResearch() async throws {
    let fileManager = FileManager.default
    let root = projectRoot()
    let inputPath = root
      .appendingPathComponent("local/audio/so_i_have_heard.caf").path
    let outputPath = root
      .appendingPathComponent("local/audio/so_i_have_heard_av.m4a").path

    // Verify input file exists
    #expect(
      fileManager.fileExists(atPath: inputPath),
      "Input CAF file not found",
    )

    // Clean up output if it exists
    try? fileManager.removeItem(atPath: outputPath)

    print("\n=== AVAudioConverter Research ===\n")
    print("Input:  \(inputPath)")
    print("Output: \(outputPath)\n")

    let startTime = Date()

    // Step 1: Read CAF file
    print("1️⃣ Reading CAF file...")
    let inputURL = URL(fileURLWithPath: inputPath)
    let inputAudioFile = try AVAudioFile(forReading: inputURL)
    let inputFormat = inputAudioFile.processingFormat
    let frameCount = AVAudioFramePosition(inputAudioFile.length)

    print("   Format: \(inputFormat)")
    print("   Frames: \(frameCount)")
    print(
      "   Duration: \(Double(frameCount) / inputFormat.sampleRate) seconds\n",
    )

    // Step 2: Create PCM output format for converter
    print("2️⃣ Creating PCM output format...")
    let outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: inputFormat.sampleRate,
      channels: inputFormat.channelCount,
      interleaved: false,
    )!

    print("   Output format: \(outputFormat)\n")

    // Step 3: Create converter
    print("3️⃣ Creating AVAudioConverter...")
    guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
    else {
      throw NSError(
        domain: "AVAudioConverter",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to create converter"],
      )
    }
    print("   Converter created\n")

    // Step 4: Create output file with AAC settings
    print("4️⃣ Creating output M4A file...")
    let m4aSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: inputFormat.sampleRate,
      AVNumberOfChannelsKey: inputFormat.channelCount,
    ]

    let outputURL = URL(fileURLWithPath: outputPath)
    let outputAudioFile = try AVAudioFile(
      forWriting: outputURL,
      settings: m4aSettings,
    )
    print("   Output file created\n")

    // Step 5: Convert in chunks
    print("5️⃣ Converting audio in chunks...")
    let bufferSize: AVAudioFrameCount = 4096
    var totalFramesProcessed: AVAudioFrameCount = 0

    while totalFramesProcessed < frameCount {
      let framesRemaining = frameCount -
        AVAudioFramePosition(totalFramesProcessed)
      let framesToRead = AVAudioFrameCount(min(
        framesRemaining,
        AVAudioFramePosition(bufferSize),
      ))

      // Read chunk from input
      let inputBuffer = AVAudioPCMBuffer(
        pcmFormat: inputFormat,
        frameCapacity: framesToRead,
      )!
      try inputAudioFile.read(into: inputBuffer, frameCount: framesToRead)

      if inputBuffer.frameLength == 0 {
        break
      }

      // Create output buffer for converted data
      let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: outputFormat,
        frameCapacity: bufferSize,
      )!

      // Convert chunk
      try converter.convert(to: outputBuffer, from: inputBuffer)

      // Write converted buffer
      try outputAudioFile.write(from: outputBuffer)

      totalFramesProcessed += inputBuffer.frameLength
      print("   Progress: \(totalFramesProcessed) / \(frameCount) frames")
    }

    print("   Conversion complete\n")

    // Step 6: Get file sizes
    print("6️⃣ Benchmarking results...")
    let inputSize = try fileManager
      .attributesOfItem(atPath: inputPath)[.size] as? Int ?? 0
    let outputSize = try fileManager
      .attributesOfItem(atPath: outputPath)[.size] as? Int ?? 0
    let totalTime = Date().timeIntervalSince(startTime)

    let compressionRatio = inputSize > 0 ? Double(inputSize) /
      Double(outputSize) : 0
    let spaceSaved = inputSize - outputSize
    let spaceSavedPercent = inputSize > 0 ? (spaceSaved * 100) / inputSize : 0

    print("   Input size:  \(inputSize) bytes (\(inputSize / 1024) KB)")
    print("   Output size: \(outputSize) bytes (\(outputSize / 1024) KB)")
    print("   Compression ratio: \(String(format: "%.2f", compressionRatio))x")
    print("   Space saved: \(spaceSaved) bytes (\(spaceSavedPercent)%)")
    print("   Total time: \(String(format: "%.3f", totalTime))s\n")

    // Step 7: Verify output
    print("7️⃣ Verification...")
    #expect(
      fileManager.fileExists(atPath: outputPath),
      "Output M4A file not created",
    )
    #expect(outputSize > 0, "Output file is empty")
    #expect(outputSize < inputSize, "Output file should be smaller than input")

    print("   ✓ Output file exists")
    print("   ✓ Output file is non-empty")
    print("   ✓ Output file is smaller than input\n")

    cc.ok1(
      #line,
      "so_i_have_heard: input=\(inputSize / 1024)KB, output=\(outputSize / 1024)KB, ratio=\(String(format: "%.2f", compressionRatio))x, time=\(String(format: "%.3f", totalTime))s",
    )
  }

  @Test("A13s: BENCHMARK: DN10:2.32.2 AVAudioConverter M4A conversion")
  func benchmarkDN10AVAudioConverterM4A() async throws {
    let fileManager = FileManager.default
    let root = projectRoot()
    let outputDir = root.appendingPathComponent("local/audio")
    let cafStore = AudioStore.create(
      path: outputDir,
      type: .caf,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    let context = AudioContext(for: "en")

    print("Text: \(dn10_2_32_2_text.prefix(100))...")
    print("Text length: \(dn10_2_32_2_text.count) characters\n")

    // 1️⃣ Synthesize to CAF
    print("1️⃣ CAF Synthesis:")
    let cafStart = Date()
    let cafUrl = try await cafStore.storeAudio(
      text: dn10_2_32_2_text,
      audioContext: context,
    )
    let cafTime = Date().timeIntervalSince(cafStart)
    let cafSize = try FileManager.default
      .attributesOfItem(atPath: cafUrl.path)[.size] as? Int ?? 0
    print("   Time: \(String(format: "%.3f", cafTime))s")
    print("   Size: \(cafSize) bytes (\(cafSize / 1024) KB)\n")

    // 2️⃣ Convert CAF to M4A using AVAudioConverter
    print("2️⃣ CAF→M4A Conversion (AVAudioConverter):")
    let m4aUrl = URL(fileURLWithPath: cafUrl.path.replacingOccurrences(
      of: ".caf",
      with: "_av.m4a",
    ))
    try? fileManager.removeItem(atPath: m4aUrl.path)

    let conversionStart = Date()
    let inputAudioFile = try AVAudioFile(forReading: cafUrl)
    let inputFormat = inputAudioFile.processingFormat
    let frameCount = AVAudioFramePosition(inputAudioFile.length)

    let m4aSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: inputFormat.sampleRate,
      AVNumberOfChannelsKey: inputFormat.channelCount,
    ]

    let outputAudioFile = try AVAudioFile(
      forWriting: m4aUrl,
      settings: m4aSettings,
    )
    let outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: inputFormat.sampleRate,
      channels: inputFormat.channelCount,
      interleaved: false,
    )!

    guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
    else {
      throw NSError(domain: "AVAudioConverter", code: -1)
    }

    let bufferSize: AVAudioFrameCount = 4096
    var totalFramesProcessed: AVAudioFrameCount = 0

    while totalFramesProcessed < frameCount {
      let framesRemaining = frameCount -
        AVAudioFramePosition(totalFramesProcessed)
      let framesToRead = AVAudioFrameCount(min(
        framesRemaining,
        AVAudioFramePosition(bufferSize),
      ))

      let inputBuffer = AVAudioPCMBuffer(
        pcmFormat: inputFormat,
        frameCapacity: framesToRead,
      )!
      try inputAudioFile.read(into: inputBuffer, frameCount: framesToRead)

      if inputBuffer.frameLength == 0 { break }

      let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: outputFormat,
        frameCapacity: bufferSize,
      )!
      try converter.convert(to: outputBuffer, from: inputBuffer)
      try outputAudioFile.write(from: outputBuffer)

      totalFramesProcessed += inputBuffer.frameLength
    }

    let conversionTime = Date().timeIntervalSince(conversionStart)
    let m4aSize = try fileManager
      .attributesOfItem(atPath: m4aUrl.path)[.size] as? Int ?? 0

    print("   Time: \(String(format: "%.3f", conversionTime))s")
    print("   Size: \(m4aSize) bytes (\(m4aSize / 1024) KB)\n")

    let compressionRatio = Double(cafSize) / Double(m4aSize)
    let spaceSaved = cafSize - m4aSize

    print("=== RESULTS ===")
    print("Segment: dn10:2.32.2 (\(dn10_2_32_2_text.count) chars)")
    print(
      "CAF synthesis: \(String(format: "%.3f", cafTime))s → \(cafSize / 1024) KB",
    )
    print(
      "CAF→M4A conversion: \(String(format: "%.3f", conversionTime))s → \(m4aSize / 1024) KB",
    )
    print("Compression ratio: \(String(format: "%.2f", compressionRatio))x")
    print(
      "Space saved: \(spaceSaved / 1024) KB (\((cafSize - m4aSize) * 100 / cafSize)%)\n",
    )

    cc.ok1(
      #line,
      "dn10:2.32.2 AVAudioConverter: synthesis=\(String(format: "%.3f", cafTime))s, convert=\(String(format: "%.3f", conversionTime))s, ratio=\(String(format: "%.2f", compressionRatio))x",
    )
  }

  #if TEST_PLAYBACK
    @Test("A13s: PLAYBACK: Play 'So I have heard.' from AudioStore")
    func playbackStoreAudioCAF() async throws {
      let root = projectRoot()
      let testDir = root.appendingPathComponent("local/test-audio")
      let store = AudioStore.create(
        path: testDir,
        type: .caf,
        adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
      )
      let context = AudioContext(for: "en")

      let text = "playback ok"
      let url = try await store.storeAudio(text: text, audioContext: context)

      #expect(url.pathExtension == "caf", "Should return CAF file")

      let player = try AVAudioPlayer(contentsOf: url)
      #expect(player.prepareToPlay(), "Player should prepare successfully")
      #expect(player.duration > 0, "Audio duration should be positive")

      print(#file, #line, "You should hear \"\(text)\"")
      player.play()

      // Wait for playback to complete
      try await Task.sleep(for: .seconds(player.duration + 0.05))
      print(#file, #line, "You should have heard \"\(text)\"")
    }
  #endif

  @Test("A13s: diskSize() returns 0 for non-existent store")
  func diskSizeNonExistentStore() async {
    let tempDir =
      URL(
        fileURLWithPath: "/tmp/audio-store-test-\(UUID().uuidString)/non-existent",
      )
    let store = AudioStore.create(
      path: tempDir,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )

    let size = await store.diskSize()

    #expect(
      size == 0,
      "Non-existent store should return 0, got \(size)",
    )
  }

  @Test("A13s: ASYNC: M4A conversion doesn't block CAF playback")
  func asyncM4AConversionDoesntBlock() async throws {
    let root = projectRoot()
    let testDir = root.appendingPathComponent("local/test-audio-m4a")

    // Clean up test directory to ensure fresh test
    try? FileManager.default.removeItem(at: testDir)

    let store = AudioStore.create(
      path: testDir,
      type: .m4a,
      adapter: MOCK_AV ? MockAVAdapter() : AVAdapter(),
    )
    let context = AudioContext(for: "en")

    print("\n=== ASYNC M4A CONVERSION TEST ===")
    print("Testing async conversion with type: .m4a\n")

    let startTime = Date()
    let url = try await store.storeAudio(
      text: "So I have heard.",
      audioContext: context,
    )
    let elapsed = Date().timeIntervalSince(startTime)

    print("storeAudio returned in \(String(format: "%.3f", elapsed))s")

    // 1. Verify returned URL is CAF (not M4A)
    #expect(
      url.pathExtension == "caf",
      "Should return CAF file for immediate playback",
    )
    print("✓ Returned CAF file: \(url.lastPathComponent)")

    // 2. Verify CAF file exists
    #expect(
      FileManager.default.fileExists(atPath: url.path),
      "CAF file should exist",
    )
    print("✓ CAF file exists")

    // 3. Verify CAF is playable immediately
    let player = try AVAudioPlayer(contentsOf: url)
    #expect(player.prepareToPlay(), "CAF should be playable immediately")
    #expect(player.duration > 0, "CAF duration should be positive")
    print(
      "✓ CAF is playable (duration: \(String(format: "%.2f", player.duration))s)",
    )

    // 4. Wait briefly for async conversion (max 2 seconds)
    let m4aUrl = URL(fileURLWithPath: url.path.replacingOccurrences(
      of: ".caf",
      with: ".m4a",
    ))
    print("\nWaiting for async M4A conversion...")
    var m4aExists = FileManager.default.fileExists(atPath: m4aUrl.path)

    if !m4aExists {
      for i in 1 ... 20 {
        try await Task.sleep(for: .milliseconds(100))
        if FileManager.default.fileExists(atPath: m4aUrl.path) {
          m4aExists = true
          print("✓ M4A appeared after \(i * 100)ms")
          break
        }
      }
    } else {
      print("✓ M4A already exists (conversion completed during synthesis)")
    }

    #expect(m4aExists, "M4A should appear after async conversion completes")

    // 5. Verify M4A is valid
    let m4aPlayer = try AVAudioPlayer(contentsOf: m4aUrl)
    #expect(m4aPlayer.prepareToPlay(), "M4A should be playable")
    print("✓ M4A is playable")

    // 6. Verify CAF still exists (not deleted until next storeAudio returns
    // M4A)
    let cafStillExists = FileManager.default.fileExists(atPath: url.path)
    #expect(
      cafStillExists,
      "CAF should remain until next storeAudio call returns M4A",
    )
    print("✓ CAF still exists (correct - not deleted yet)")

    // 7. Second storeAudio call should return M4A and delete CAF
    print("\nCalling storeAudio again...")
    let url2 = try await store.storeAudio(
      text: "So I have heard.",
      audioContext: context,
    )
    #expect(url2.pathExtension == "m4a", "Second call should return M4A")
    print("✓ Second call returned M4A")

    // 8. Now CAF should be deleted
    let cafExistsAfterM4AReturn = FileManager.default
      .fileExists(atPath: url.path)
    #expect(
      !cafExistsAfterM4AReturn,
      "CAF should be deleted when M4A is returned",
    )
    print("✓ CAF deleted after M4A was returned")

    print("\n=== TEST COMPLETE ===\n")
  }
}
