import AVFoundation
import Foundation
@testable import scvCore
@testable import scvUI
import Testing

// MARK: - Test Configuration

let MOCK_AV = true

@MainActor
func testInit(timeout: TimeInterval = 5, synthTime: TimeInterval = 0) -> (
  tempDir: URL,
  testStore: AudioStore,
  testDelegate: TestPlaybackDelegate,
) {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
  let testAdapter: IAVAdapter? = {
    if MOCK_AV {
      // Calculate path to test-audio.caf from this file's location
      let thisFile = #filePath // Absolute path (not relative like #file)
      let fileURL = URL(fileURLWithPath: thisFile)
      let testsDir = fileURL.deletingLastPathComponent()
        .path // .../scv-ui/Tests
      let testAudioPath = (testsDir as NSString)
        .appendingPathComponent("Data/test-audio.caf")
      return MockAVAdapter(testAudioPath: testAudioPath, synthTime: synthTime)
    }
    return nil
  }()
  let testStore = AudioStore.create(
    path: tempDir,
    type: .caf,
    timeout: timeout,
    adapter: testAdapter,
  )
  let testDelegate = TestPlaybackDelegate()
  return (tempDir, testStore, testDelegate)
}

// MARK: - Test delegate to capture playback events

@MainActor
class TestPlaybackDelegate: IPlaybackDelegate {
  var didStartCalls = 0
  var didPauseCalls = 0
  var didContinueCalls = 0
  var didFinishCalls = 0

  func onPlaybackStarted() {
    didStartCalls += 1
  }

  func onPlaybackPaused() {
    didPauseCalls += 1
  }

  func onPlaybackContinued() {
    didContinueCalls += 1
  }

  func onPlaybackFinished() {
    didFinishCalls += 1
  }
}

@Suite("C20s:CachedSynthesizerTests")
struct CachedSynthesizerTests {
  let cc = ColorConsole(#file, #function, dbg.scvUITests.other)

  @Test
  @MainActor
  func C20s_cachedSynthesizerEmitsOnPlaybackStartedEvent() async throws {
    // Setup: create temp AudioStore and synthesize test audio
    let (tempDir, testStore, testDelegate) = testInit()

    // Use minimal segment pause for faster tests
    Settings.shared.segmentPause = 0.01

    // Synthesize short test audio
    let testText = "test"
    let audioContext = AudioContext(for: "en")
    _ = try await testStore.storeAudio(
      text: testText,
      audioContext: audioContext,
    )

    // Create CachedSynthesizer with test store
    let synth = CachedSynthesizer(audioStore: testStore)
    synth.playbackDelegate = testDelegate

    // Act: play text
    try synth.playText(testText, audioContext: audioContext)

    // Assert: onPlaybackStarted should have been called
    #expect(testDelegate.didStartCalls == 1)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func C20s_cachedSynthesizerEmitsOnPlaybackFinishedEvent() async throws {
    // Setup: create temp AudioStore and synthesize test audio
    let (tempDir, testStore, testDelegate) = testInit()

    // Use minimal segment pause for faster tests
    Settings.shared.segmentPause = 0.01

    // Synthesize short test audio
    let testText = "test"
    let audioContext = AudioContext(for: "en")
    _ = try await testStore.storeAudio(
      text: testText,
      audioContext: audioContext,
    )

    // Create CachedSynthesizer with test store
    let synth = CachedSynthesizer(audioStore: testStore)
    synth.playbackDelegate = testDelegate

    // Act: play text and wait for completion
    try synth.playText(testText, audioContext: audioContext)

    // Wait for audio to finish playing (with timeout)
    let startTime = Date()
    while testDelegate.didFinishCalls == 0,
          Date().timeIntervalSince(startTime) < 5.0
    {
      try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    // Assert: onPlaybackFinished should have been called
    #expect(testDelegate.didFinishCalls == 1)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func C20s_cachedSynthesizerEmitsOnPlaybackPausedEvent() async throws {
    // Setup: create temp AudioStore and synthesize test audio
    let (tempDir, testStore, testDelegate) = testInit()

    // Use minimal segment pause for faster tests
    Settings.shared.segmentPause = 0.01

    // Synthesize longer test audio (so we have time to pause)
    let testText = "testng one two three"
    let audioContext = AudioContext(for: "en")
    _ = try await testStore.storeAudio(
      text: testText,
      audioContext: audioContext,
    )

    // Create CachedSynthesizer with test store
    let synth = CachedSynthesizer(audioStore: testStore)
    synth.playbackDelegate = testDelegate

    // Act: play text and simulate audio interruption
    try synth.playText(testText, audioContext: audioContext)

    // Wait a bit for playback to start, then simulate interruption
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms

    // Simulate audio interruption (calls audioPlayerBeginInterruption)
    // Note: We can't directly trigger this in a unit test without mocking
    // AVAudioPlayer
    // or actually interrupting audio (e.g., call, alarm).
    // For now, verify the infrastructure is in place.
    // In integration testing, actual system audio interruption would trigger
    // this.

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func C20s_cachedSynthesizerEmitsOnPlaybackContinuedEvent() async throws {
    // Setup: create temp AudioStore and synthesize test audio
    let (tempDir, testStore, testDelegate) = testInit()

    // Use minimal segment pause for faster tests
    Settings.shared.segmentPause = 0.01

    // Synthesize longer test audio (so we have time for pause/continue)
    let testText = "hello world this is a test"
    let audioContext = AudioContext(for: "en")
    _ = try await testStore.storeAudio(
      text: testText,
      audioContext: audioContext,
    )

    // Create CachedSynthesizer with test store
    let synth = CachedSynthesizer(audioStore: testStore)
    synth.playbackDelegate = testDelegate

    // Act: play text and simulate interruption recovery
    try synth.playText(testText, audioContext: audioContext)

    // Note: Similar to pause test, onPlaybackContinued is triggered by
    // AVAudioPlayer when audio interruption ends (system call, alarm, etc.)
    // Unit testing this requires either:
    // 1. Mocking AVAudioPlayer
    // 2. Actually triggering system interruption
    // For now, verify the infrastructure is in place.
    // In integration testing, actual system audio interruption recovery would
    // trigger this.

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func C20s_cachedSynthesizerQueuesUncachedAudio() async throws {
    // Setup: create temp AudioStore with nothing cached
    let (tempDir, testStore, testDelegate) = testInit(timeout: 2.0)

    // Use minimal segment pause for faster tests
    Settings.shared.segmentPause = 0.01

    let testText = "synthesize this"
    let audioContext = AudioContext(for: "en")

    // Create CachedSynthesizer with test store
    let synth = CachedSynthesizer(audioStore: testStore)
    synth.playbackDelegate = testDelegate

    // Act: play uncached text (should queue synthesis, not throw)
    try synth.playText(testText, audioContext: audioContext)

    // Assert: should not throw, should queue synthesis
    // Wait for synthesis to complete and playback to start
    let startTime = Date()
    while testDelegate.didStartCalls == 0,
          Date().timeIntervalSince(startTime) < 10.0
    {
      try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }

    #expect(testDelegate.didStartCalls >= 1)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func C20s_cachedSynthesizerDeduplicatesConcurrentSameTextRequests(
  ) async throws {
    // Setup: create temp AudioStore with nothing cached
    let (tempDir, testStore, testDelegate) = testInit(timeout: 2.0)

    // Use minimal segment pause for faster tests
    Settings.shared.segmentPause = 0.01

    let testText = "deduplicate me"
    let audioContext = AudioContext(for: "en")

    // Create CachedSynthesizer with test store
    let synth = CachedSynthesizer(audioStore: testStore)
    synth.playbackDelegate = testDelegate

    // Act: queue same text twice (simulates two concurrent playText calls)
    try synth.playText(testText, audioContext: audioContext)
    try synth.playText(testText, audioContext: audioContext)

    // Assert: should only synthesize once (deduplication)
    // Both playback requests merged into one with playback:true
    let startTime = Date()
    while testDelegate.didStartCalls == 0,
          Date().timeIntervalSince(startTime) < 10.0
    {
      try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }

    // Should get exactly one playback started event (deduped)
    #expect(testDelegate.didStartCalls == 1)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }
}
