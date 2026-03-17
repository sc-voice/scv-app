import AVFoundation
import Foundation
@testable import scvCore
@testable import scvUI
import SwiftData
import Testing

// MARK: - Test Configuration

private func testAdapter(synthTime: TimeInterval = 0,
                         mock: Bool = false) -> IAVAdapter?
{
  guard mock else { return nil }
  let thisFile = #filePath
  let fileURL = URL(fileURLWithPath: thisFile)
  let testsDir = fileURL.deletingLastPathComponent().path
  let testAudioPath = (testsDir as NSString)
    .appendingPathComponent("Data/test-audio.caf")
  return MockAVAdapter(testAudioPath: testAudioPath, synthTime: synthTime)
}

// MARK: - MockSpeechSynthesizer for SuttaPlayer testing

// Test-only class: mark as @MainActor to match ISpeechSynthesizer protocol
@MainActor
class MockSpeechSynthesizerForSuttaPlayer: ISpeechSynthesizer,
  @unchecked Sendable
{
  var isSpeaking = false
  var delegate: AVSpeechSynthesizerDelegate?
  var playbackDelegate: IPlaybackDelegate?

  var stopSpeakingWasCalled = false
  var stopSpeakingBoundary: AVSpeechBoundary?

  var playTextWasCalled = false
  var lastPlayTextText: String?
  var lastPlayTextAudioContext: AudioContext?

  func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
    stopSpeakingWasCalled = true
    stopSpeakingBoundary = boundary
    isSpeaking = false
    return true
  }

  func playText(_ text: String, audioContext: AudioContext) throws {
    playTextWasCalled = true
    lastPlayTextText = text
    lastPlayTextAudioContext = audioContext
    isSpeaking = true
  }

  func resetSynthesizer() {
    isSpeaking = false
  }

  // MARK: - Playback event helpers for testing

  nonisolated func triggerDidStart() {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackStarted()
    }
  }

  nonisolated func triggerDidPause() {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackPaused()
    }
  }

  nonisolated func triggerDidContinue() {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackContinued()
    }
  }

  nonisolated func triggerDidFinish() {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackFinished()
    }
  }

  // Helper to simulate speech completion
  func simulateSpeechCompletion() {
    isSpeaking = false
  }
}

@Suite("S15s:SuttaPlayerTests")
struct SuttaPlayerTests {
  @Test
  @MainActor
  func S15s_suttaPlayerUpdatesCurrentScidWhenPlayingSegment() async {
    // Create a mock MLDocument with segments
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      // Load the document
      player.load(mlDoc)

      // Set starting position to segment 1 (skips audio effects on first
      // segment)
      mlDoc.currentScid = segments[1].scid

      // Use minimal segment pause for faster tests
      Settings.shared.segmentPause = 0.01

      // Play from segment 1
      player.play()

      // Wait for async Task to start and execute playText (20ms minimum)
      try? await Task.sleep(nanoseconds: 20_000_000)

      // Verify playText was called and currentScid is set to segment 1
      #expect(mockSynthesizer.playTextWasCalled == true)
      let currentScid = player.currentSutta?.currentScid
      #expect(currentScid == segments[1].scid)
    }
  }

  @Test
  @MainActor
  func S15s_suttaPlayerJumpToSegmentWhilePlaying() async {
    // Create a mock MLDocument with segments
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      // Load the document
      player.load(mlDoc)

      // Start at segment 1 to skip audio effects on first segment
      mlDoc.currentScid = segments[1].scid

      // Use minimal segment pause for faster tests
      Settings.shared.segmentPause = 0.01

      // Start playing from segment 1
      player.play()

      // Wait for async Task to start and execute (20ms minimum)
      try? await Task.sleep(nanoseconds: 20_000_000)

      // Verify playing segment 1
      let currentScid1 = player.currentSutta?.currentScid
      #expect(currentScid1 == segments[1].scid)

      // User jumps to segment 3 while segment 1 is still playing
      // This should pause playback and update to segment 3
      player.jumpToSegment(scid: segments[3].scid)

      // Verify currentScid is updated to segment 3
      let currentScid3 = player.currentSutta?.currentScid
      #expect(currentScid3 == segments[3].scid)

      // Verify that playback stopped
      #expect(player.isPlaying == false)
    }
  }

  @Test
  @MainActor
  func S15s_suttaPlayerDidStartCallbackUpdatesSynthesizerSpeakingState() async {
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)

      player.load(mlDoc)
      player.play()

      // Initial state: isSynthesizerSpeaking should be false before didStart
      #expect(player.isSynthesizerSpeaking == false)

      // Trigger didStart callback
      mockSynthesizer.triggerDidStart()

      // Wait for async MainActor dispatch to complete
      try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

      // Verify isSynthesizerSpeaking updates to true
      #expect(player.isSynthesizerSpeaking == true)
    }
  }

  @Test
  @MainActor
  func S15s_suttaPlayerDidPauseCallbackUpdatesSynthesizerSpeakingState() async {
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)

      player.load(mlDoc)
      player.play()

      // Start playback
      mockSynthesizer.triggerDidStart()
      try? await Task.sleep(nanoseconds: 10_000_000)
      #expect(player.isSynthesizerSpeaking == true)

      // Trigger didPause callback
      mockSynthesizer.triggerDidPause()
      try? await Task.sleep(nanoseconds: 10_000_000)

      // Verify isSynthesizerSpeaking updates to false
      #expect(player.isSynthesizerSpeaking == false)
    }
  }

  @Test
  @MainActor
  func S15s_suttaPlayerDidContinueCallbackUpdatesSynthesizerSpeakingState(
  ) async {
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)

      player.load(mlDoc)
      player.play()

      // Start and pause
      mockSynthesizer.triggerDidStart()
      try? await Task.sleep(nanoseconds: 10_000_000)
      mockSynthesizer.triggerDidPause()
      try? await Task.sleep(nanoseconds: 10_000_000)
      #expect(player.isSynthesizerSpeaking == false)

      // Trigger didContinue callback
      mockSynthesizer.triggerDidContinue()
      try? await Task.sleep(nanoseconds: 10_000_000)

      // Verify isSynthesizerSpeaking updates back to true
      #expect(player.isSynthesizerSpeaking == true)
    }
  }

  @Test
  @MainActor
  func S15s_suttaPlayerDidFinishCallbackAutoAdvancesToNextSegment() async {
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      player.load(mlDoc)

      // Start at segment 1 to skip audio effects on first segment
      mlDoc.currentScid = segments[1].scid

      // Use minimal segment pause for faster tests
      Settings.shared.segmentPause = 0.01

      player.play()

      // Wait for async Task to start and set currentScid (20ms minimum)
      try? await Task.sleep(nanoseconds: 20_000_000)

      // Start playback of segment 1
      mockSynthesizer.triggerDidStart()
      try? await Task.sleep(nanoseconds: 10_000_000)
      let segment1Scid = player.currentSutta?.currentScid
      #expect(segment1Scid == segments[1].scid)

      // Simulate realistic playback duration (415ms) - avoids silent failure
      // detection (MIN_SPEAK_SECONDS = 0.4s + segmentPause = 0.01s)
      try? await Task.sleep(nanoseconds: 415_000_000)

      // Simulate playback finishing - should auto-advance to segment 2
      mockSynthesizer.triggerDidFinish()
      // Wait for iterator loop to advance to next segment (20ms minimum)
      try? await Task.sleep(nanoseconds: 20_000_000)

      // Verify isSynthesizerSpeaking is false
      #expect(player.isSynthesizerSpeaking == false)

      // Verify auto-advance: should advance from segment 1 to segment 2
      let currentScid = player.currentSutta?.currentScid
      #expect(currentScid == segments[2].scid)
    }
  }

  @Test
  @MainActor
  func S15s_suttaPlayerDidFinishCallbackStopsWhenNotPlaying() async {
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      player.load(mlDoc)

      // Start at segment 1 to skip audio effects on first segment
      mlDoc.currentScid = segments[1].scid

      // Use minimal segment pause for faster tests
      Settings.shared.segmentPause = 0.01

      player.play()

      // Wait for async Task to start and set currentScid (20ms minimum)
      try? await Task.sleep(nanoseconds: 20_000_000)

      // Start playback of segment 1
      mockSynthesizer.triggerDidStart()
      try? await Task.sleep(nanoseconds: 10_000_000)
      let segment1Scid = player.currentSutta?.currentScid
      #expect(segment1Scid == segments[1].scid)

      // User pauses playback
      player.pause()
      #expect(player.isPlaying == false)
      #expect(player.isSynthesizerSpeaking == false)

      // Trigger didFinish while not playing - should NOT advance
      mockSynthesizer.triggerDidFinish()
      try? await Task.sleep(nanoseconds: 10_000_000)

      // Verify still at segment 1 (didn't advance)
      let currentScid = player.currentSutta?.currentScid
      #expect(currentScid == segments[1].scid)
    }
  }

  @Test
  @MainActor
  func S15s_suttaPlayerIntegrationWithC16s() async throws {
    // Create temp AudioStore for CachedSynthesizer
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(
      path: tempDir,
      type: .caf,
      adapter: testAdapter(),
    )

    // Create CachedSynthesizer with test store
    let synth = CachedSynthesizer(audioStore: testStore)

    // Create SuttaPlayer with CachedSynthesizer
    let player = SuttaPlayer(synthesizer: synth)

    // Verify SuttaPlayer initialized successfully
    #expect(player.currentSutta == nil)
    #expect(player.isPlaying == false)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func S15s_suttaPlayerIntegrationWithC15rLoadsDocument() async throws {
    // Create temp AudioStore
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(
      path: tempDir,
      type: .caf,
      adapter: testAdapter(),
    )

    // Create SuttaPlayer with CachedSynthesizer
    let synth = CachedSynthesizer(audioStore: testStore)
    let player = SuttaPlayer(synthesizer: synth)

    // Load mock document
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      player.load(mlDoc)

      // Verify document loaded and not playing yet
      #expect(player.currentSutta != nil)
      #expect(player.isPlaying == false)
    }

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func S15s_suttaPlayerPrecachedAudio() async throws {
    // Create temp AudioStore and pre-cache audio for first segment
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(
      path: tempDir,
      type: .caf,
      adapter: testAdapter(),
    )

    let audioContext = AudioContext(for: "en")

    // Load mock document
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let segments = mlDoc.segments()
      let segment1Text = segments[1].doc ?? "test"

      // Pre-cache audio for segment 1
      _ = try await testStore.storeAudio(
        text: segment1Text,
        audioContext: audioContext,
      )

      // Create SuttaPlayer with CachedSynthesizer
      let synth = CachedSynthesizer(audioStore: testStore)
      let player = SuttaPlayer(synthesizer: synth)

      player.load(mlDoc)

      // Start at segment 1 to skip audio effects on first segment
      mlDoc.currentScid = segments[1].scid

      // Use minimal segment pause for faster tests
      Settings.shared.segmentPause = 0.01

      // Play segment 1 (should work because audio is cached)
      player.play()

      // Wait for async Task to start and set currentScid (20ms minimum)
      try? await Task.sleep(nanoseconds: 20_000_000)

      // Verify playback started (CachedSynthesizer will have called playText)
      #expect(player.isPlaying == true)
      #expect(player.currentSutta?.currentScid == segments[1].scid)

      // Pause to stop playback
      player.pause()
    }

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func S15s_suttaPlayerIntegrationWithC15rHandlesPlaybackError() async throws {
    // Create temp AudioStore with NO pre-cached audio
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(
      path: tempDir,
      type: .caf,
      adapter: testAdapter(),
    )

    // Load mock document
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      // Create SuttaPlayer with CachedSynthesizer
      let synth = CachedSynthesizer(audioStore: testStore)
      let player = SuttaPlayer(synthesizer: synth)

      player.load(mlDoc)

      // Try to play without pre-cached audio
      // CachedSynthesizer.playText() will throw because audio not cached
      // Note: play() sets isPlaying=true before attempting synthesis,
      // so even if synthesis fails, isPlaying remains true. This is expected
      // behavior.
      player.play()

      // Verify play was called (isPlaying will be true)
      // The error from CachedSynthesizer.playText() is caught and logged by
      // SuttaPlayer
      #expect(player.isPlaying == true)

      // Pause to stop playback
      player.pause()
      #expect(player.isPlaying == false)
    }

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func S15s_suttaPlayerIsActivePropertyDefaultsTrueAndCanBeToggled() async {
    // Create a fresh instance (doesn't use .shared to avoid state pollution)
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(
      path: tempDir,
      type: .caf,
      adapter: testAdapter(),
    )
    let synth = CachedSynthesizer(audioStore: testStore)
    let player = SuttaPlayer(synthesizer: synth)

    // Verify isActive defaults to true
    #expect(player.isActive == true)

    // Call setActive(false) - SuttaPlayer should skip interruption handling
    player.setActive(false)
    #expect(player.isActive == false)

    // Call setActive(true) - SuttaPlayer should resume interruption handling
    player.setActive(true)
    #expect(player.isActive == true)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func S15s_suttaPlayerDetectsSilentSynthesisFailureAndStops() async {
    // Test: playback finishes too quickly (< 0.25s) indicates silent synthesis
    // failure. SuttaPlayer should detect, stop playback, and show alert.
    // NO automatic retry (that was the infinite loop problem).
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      player.load(mlDoc)

      // Use segment with sufficient text (>= 30 chars) for validateSynthesis check
      // validateSynthesis is only set to true if text.count >= 30
      // sn42.11:1.2 has long English translation
      mlDoc.currentScid = "sn42.11:1.2"

      // Use minimal segment pause for faster tests
      Settings.shared.segmentPause = 0.01

      player.play()

      try? await Task.sleep(nanoseconds: 20_000_000)

      // Verify initial playText was called
      #expect(mockSynthesizer.playTextWasCalled == true)
      #expect(player.isPlaying == true)

      // Reset the call flag to count subsequent calls
      mockSynthesizer.playTextWasCalled = false

      // Trigger didStart: sets playbackStartTime
      mockSynthesizer.triggerDidStart()
      try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
      #expect(player.isSynthesizerSpeaking == true)

      // Immediately trigger didFinish (simulating < 0.25s playback duration)
      // This should trigger silent failure detection and STOP playback
      mockSynthesizer.triggerDidFinish()
      try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

      // Verify NO retry: playText should NOT be called again
      #expect(mockSynthesizer.playTextWasCalled == false)

      // Verify playback stopped
      #expect(player.isPlaying == false)
    }
  }
}
