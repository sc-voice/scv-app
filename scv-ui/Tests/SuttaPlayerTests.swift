import AVFoundation
import Foundation
@testable import scvCore
@testable import scvUI
import SwiftData
import Testing

// MARK: - MockSpeechSynthesizer for SuttaPlayer testing

// Test-only class: mark as nonisolated(unsafe) to allow cross-isolation access
// in Task
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

  // MARK: - Playback event helpers for testing

  // Note: These are called from @MainActor test methods, so no dispatch needed

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
      let segments = mlDoc.segments()

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

      // Trigger didFinish while not playing - should NOT advance
      mockSynthesizer.triggerDidFinish()
      try? await Task.sleep(nanoseconds: 10_000_000)

      // Verify still at segment 0 (didn't advance)
      let currentScid = player.currentSutta?.currentScid
      #expect(currentScid == segments[0].scid)
      cc.ok1(#line, "passed")
    }
  }
}
