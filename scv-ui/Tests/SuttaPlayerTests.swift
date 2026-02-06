import AVFoundation
import Foundation
@testable import scvCore
@testable import scvUI
import SwiftData
import Testing

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

  var queueSynthesisOnlyWasCalled = false
  var queuedTexts: [String] = []

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

  func queueSynthesisOnly(text: String, audioContext _: AudioContext) {
    queueSynthesisOnlyWasCalled = true
    queuedTexts.append(text)
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

@Suite
struct SuttaPlayerTests {
  let cc = ColorConsole(#file, #function, dbg.scvUITests.other)

  @Test
  @MainActor
  func suttaPlayerUpdatesCurrentScidWhenPlayingSegment() async {
    // Create a mock MLDocument with segments
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      // Load the document
      player.load(mlDoc)

      // Play first segment
      player.play()

      // Verify playText was called and currentScid is set
      #expect(mockSynthesizer.playTextWasCalled == true)
      let firstSegmentScid = segments[0].scid
      let currentScid = player.currentSutta?.currentScid
      #expect(currentScid == firstSegmentScid)
      cc.ok1(#line, "passed")
    }
  }

  @Test
  @MainActor
  func suttaPlayerJumpToSegmentWhilePlaying() async {
    // Create a mock MLDocument with segments
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      // Load the document
      player.load(mlDoc)

      // Start playing segment 0
      player.play()

      // Verify playing segment 0
      let currentScid0 = player.currentSutta?.currentScid
      #expect(currentScid0 == segments[0].scid)

      // User jumps to segment 3 while segment 0 is still playing
      // This should pause playback and update to segment 3
      player.jumpToSegment(scid: segments[3].scid)

      // Verify currentScid is updated to segment 3
      let currentScid3 = player.currentSutta?.currentScid
      #expect(currentScid3 == segments[3].scid)

      // Verify that playback stopped
      #expect(player.isPlaying == false)
      cc.ok1(#line, "passed")
    }
  }

  @Test
  @MainActor
  func suttaPlayerDidStartCallbackUpdatesSynthesizerSpeakingState() async {
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
      cc.ok1(#line, "passed")
    }
  }

  @Test
  @MainActor
  func suttaPlayerDidPauseCallbackUpdatesSynthesizerSpeakingState() async {
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
      cc.ok1(#line, "passed")
    }
  }

  @Test
  @MainActor
  func suttaPlayerDidContinueCallbackUpdatesSynthesizerSpeakingState() async {
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
      cc.ok1(#line, "passed")
    }
  }

  @Test
  @MainActor
  func suttaPlayerDidFinishCallbackAutoAdvancesToNextSegment() async {
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      player.load(mlDoc)
      player.play()

      // Start playback of segment 0
      mockSynthesizer.triggerDidStart()
      try? await Task.sleep(nanoseconds: 10_000_000)
      let segment0Scid = player.currentSutta?.currentScid
      #expect(segment0Scid == segments[0].scid)

      // Simulate playback finishing - should auto-advance to segment 1
      mockSynthesizer.triggerDidFinish()
      try? await Task.sleep(nanoseconds: 10_000_000)

      // Verify isSynthesizerSpeaking is false
      #expect(player.isSynthesizerSpeaking == false)

      // Verify auto-advance: playSegmentAt was called with nextIndexToPlay
      // (which is 1)
      // currentScid should now be segment 1's scid
      let currentScid = player.currentSutta?.currentScid
      #expect(currentScid == segments[1].scid)
      cc.ok1(#line, "passed")
    }
  }

  @Test
  @MainActor
  func suttaPlayerDidFinishCallbackStopsWhenNotPlaying() async {
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let mockSynthesizer = MockSpeechSynthesizerForSuttaPlayer()
      let player = SuttaPlayer(synthesizer: mockSynthesizer)
      let segments = mlDoc.segments()

      player.load(mlDoc)
      player.play()

      // Start playback of segment 0
      mockSynthesizer.triggerDidStart()
      try? await Task.sleep(nanoseconds: 10_000_000)
      let segment0Scid = player.currentSutta?.currentScid
      #expect(segment0Scid == segments[0].scid)

      // User pauses playback
      player.pause()
      #expect(player.isPlaying == false)
      #expect(player.isSynthesizerSpeaking == false)

      // Trigger didFinish while not playing - should NOT advance
      mockSynthesizer.triggerDidFinish()
      try? await Task.sleep(nanoseconds: 10_000_000)

      // Verify still at segment 0 (didn't advance)
      let currentScid = player.currentSutta?.currentScid
      #expect(currentScid == segments[0].scid)
      cc.ok1(#line, "passed")
    }
  }

  @Test
  @MainActor
  func suttaPlayerIntegrationWithCachedSynthesizerInitializes() async throws {
    // Create temp AudioStore for CachedSynthesizer
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(path: tempDir, type: .caf)

    // Create CachedSynthesizer with test store
    let synth = CachedSynthesizer(audioStore: testStore)

    // Create SuttaPlayer with CachedSynthesizer
    let player = SuttaPlayer(synthesizer: synth)

    // Verify SuttaPlayer initialized successfully
    #expect(player.currentSutta == nil)
    #expect(player.isPlaying == false)
    cc.ok1(#line, "passed")

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func suttaPlayerIntegrationWithCachedSynthesizerLoadsDocument() async throws {
    // Create temp AudioStore
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(path: tempDir, type: .caf)

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
      cc.ok1(#line, "passed")
    }

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func suttaPlayerIntegrationWithCachedSynthesizerHandlesPlaybackWithPrecachedAudio(
  )
    async throws
  {
    // Create temp AudioStore and pre-cache audio for first segment
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(path: tempDir, type: .caf)

    let audioContext = AudioContext(for: "en")

    // Load mock document
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let segments = mlDoc.segments()
      let firstSegmentText = segments[0].doc ?? "test"

      // Pre-cache audio for first segment
      _ = try await testStore.storeAudio(
        text: firstSegmentText,
        audioContext: audioContext,
      )

      // Create SuttaPlayer with CachedSynthesizer
      let synth = CachedSynthesizer(audioStore: testStore)
      let player = SuttaPlayer(synthesizer: synth)

      player.load(mlDoc)

      // Play first segment (should work because audio is cached)
      player.play()

      // Verify playback started (CachedSynthesizer will have called playText)
      #expect(player.isPlaying == true)
      #expect(player.currentSutta?.currentScid == segments[0].scid)
      cc.ok1(#line, "passed")

      // Pause to stop playback
      player.pause()
    }

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test
  @MainActor
  func suttaPlayerIntegrationWithCachedSynthesizerHandlesPlaybackError(
  ) async throws {
    // Create temp AudioStore with NO pre-cached audio
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let testStore = AudioStore.create(path: tempDir, type: .caf)

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
      cc.ok1(#line, "passed")
    }

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

}
