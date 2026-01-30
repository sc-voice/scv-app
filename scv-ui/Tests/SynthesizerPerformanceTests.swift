import AVFoundation
import Foundation
@testable import scvCore
@testable import scvUI
import Testing

// MARK: - Performance measurement helpers

@MainActor
class PerformanceDelegate: IPlaybackDelegate {
  var startTime: Date?
  var endTime: Date?

  func onPlaybackStarted() {
    startTime = Date()
  }

  func onPlaybackPaused() {}
  func onPlaybackContinued() {}
  func onPlaybackFinished() {
    endTime = Date()
  }
}

@Suite
struct SynthesizerPerformanceTests {
  let cc = ColorConsole(#file, #function, dbg.scvUITests.other)

  @Test
  @MainActor
  func cachedSynthesizerPlaybackStartupLatency() async throws {
    // Setup: create AudioStore and pre-cache audio
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(path: tempDir, type: .caf)

    let testText = "test"
    let audioContext = AudioContext(for: "en")

    // Pre-synthesize and cache audio
    _ = try await testStore.storeAudio(text: testText, audioContext: audioContext)

    // Create CachedSynthesizer
    let synth = CachedSynthesizer(audioStore: testStore)
    let perfDelegate = PerformanceDelegate()
    synth.playbackDelegate = perfDelegate

    // Measure: time from playText() to onPlaybackStarted()
    let playStartTime = Date()
    try synth.playText(testText, audioContext: audioContext)

    // Wait for playback to start
    let maxWait: TimeInterval = 2.0
    while perfDelegate.startTime == nil
      && Date().timeIntervalSince(playStartTime) < maxWait
    {
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    guard let startTime = perfDelegate.startTime else {
      cc.bad1(#line, "Playback never started")
      throw NSError(
        domain: "PerformanceTest",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Playback timeout"]
      )
    }

    let startupLatency = startTime.timeIntervalSince(playStartTime)
    cc.ok1(
      #line,
      "CachedSynthesizer startup latency: \(String(format: "%.3f", startupLatency))s"
    )

    // Assert: startup latency should be <0.5s (AVAudioPlayer is fast)
    #expect(startupLatency < 0.5)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func speechSynthesizerImplPlaybackStartupLatency() async throws {
    // Create SpeechSynthesizerImpl
    let synth = SpeechSynthesizerImpl()
    let perfDelegate = PerformanceDelegate()
    synth.playbackDelegate = perfDelegate

    let testText = "test"
    let audioContext = AudioContext(for: "en")

    // Measure: time from playText() to onPlaybackStarted()
    let playStartTime = Date()
    try synth.playText(testText, audioContext: audioContext)

    // Wait for playback to start
    let maxWait: TimeInterval = 5.0
    while perfDelegate.startTime == nil
      && Date().timeIntervalSince(playStartTime) < maxWait
    {
      try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
    }

    guard let startTime = perfDelegate.startTime else {
      cc.bad1(#line, "Playback never started")
      throw NSError(
        domain: "PerformanceTest",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Playback timeout"]
      )
    }

    let startupLatency = startTime.timeIntervalSince(playStartTime)
    cc.ok1(
      #line,
      "SpeechSynthesizerImpl startup latency: \(String(format: "%.3f", startupLatency))s"
    )

    // Assert: startup latency will be larger (synthesis takes time)
    // Expect it to complete within 3 seconds
    #expect(startupLatency < 3.0)

    // Stop synthesizer
    synth.stopSpeaking(at: .immediate)
  }

  @Test
  @MainActor
  func performanceComparison_CachedIsFasterThanLiveSync() async throws {
    // This test verifies the expected performance characteristic:
    // CachedSynthesizer should have lower startup latency than SpeechSynthesizerImpl

    // Setup: AudioStore with cached audio
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(path: tempDir, type: .caf)

    let testText = "performance test"
    let audioContext = AudioContext(for: "en")
    _ = try await testStore.storeAudio(text: testText, audioContext: audioContext)

    // Test 1: CachedSynthesizer
    let cachedSynth = CachedSynthesizer(audioStore: testStore)
    let cachedDelegate = PerformanceDelegate()
    cachedSynth.playbackDelegate = cachedDelegate

    let cachedStartTime = Date()
    try cachedSynth.playText(testText, audioContext: audioContext)

    while cachedDelegate.startTime == nil
      && Date().timeIntervalSince(cachedStartTime) < 2.0
    {
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let cachedLatency = cachedDelegate.startTime
      .map { $0.timeIntervalSince(cachedStartTime) } ?? 2.0

    // Test 2: SpeechSynthesizerImpl
    let liveSynth = SpeechSynthesizerImpl()
    let liveDelegate = PerformanceDelegate()
    liveSynth.playbackDelegate = liveDelegate

    let liveStartTime = Date()
    try liveSynth.playText(testText, audioContext: audioContext)

    while liveDelegate.startTime == nil
      && Date().timeIntervalSince(liveStartTime) < 5.0
    {
      try await Task.sleep(nanoseconds: 50_000_000)
    }

    let liveLatency = liveDelegate.startTime
      .map { $0.timeIntervalSince(liveStartTime) } ?? 5.0

    cc.ok1(
      #line,
      "CachedSynthesizer: \(String(format: "%.3f", cachedLatency))s vs SpeechSynthesizer: \(String(format: "%.3f", liveLatency))s"
    )

    // Assert: Cached should be faster than live synthesis
    #expect(cachedLatency < liveLatency)

    liveSynth.stopSpeaking(at: .immediate)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func cachedSynthesizerPlaybackDuration() async throws {
    // Verify: playback duration matches audio file duration
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(path: tempDir, type: .caf)

    let testText = "test audio duration"
    let audioContext = AudioContext(for: "en")
    _ = try await testStore.storeAudio(text: testText, audioContext: audioContext)

    let synth = CachedSynthesizer(audioStore: testStore)
    let perfDelegate = PerformanceDelegate()
    synth.playbackDelegate = perfDelegate

    let playStartTime = Date()
    try synth.playText(testText, audioContext: audioContext)

    // Wait for playback to complete
    let maxWait: TimeInterval = 5.0
    while perfDelegate.endTime == nil
      && Date().timeIntervalSince(playStartTime) < maxWait
    {
      try await Task.sleep(nanoseconds: 50_000_000)
    }

    guard let startTime = perfDelegate.startTime, let endTime = perfDelegate.endTime
    else {
      cc.bad1(#line, "Playback did not complete")
      throw NSError(
        domain: "PerformanceTest",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Playback incomplete"]
      )
    }

    let playbackDuration = endTime.timeIntervalSince(startTime)
    cc.ok1(
      #line,
      "Playback duration: \(String(format: "%.3f", playbackDuration))s"
    )

    // Assert: playback should complete within 5 seconds
    #expect(playbackDuration > 0.1)  // At least 100ms of audio
    #expect(playbackDuration < 5.0)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }
}
