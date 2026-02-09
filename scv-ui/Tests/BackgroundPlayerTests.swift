import Foundation
import Testing
import scvCore
@testable import scvUI

@Suite("BackgroundPlayer Tests")
struct BackgroundPlayerTests {

  // MARK: - Initialization Tests

  @Test("Initializes with valid SuttaRef")
  func testInitialization() async throws {
    let suttaRef = try SuttaRef(suttaUid: "mn1", lang: "en", author: "sujato")
    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef)
    }

    await MainActor.run {
      #expect(player.state == .idle)
      #expect(player.synthesisSnapshot == nil)
      #expect(player.playbackSnapshot == nil)
    }
  }

  @Test("Initializes with custom AudioContext")
  func testInitializationWithCustomContext() async throws {
    let suttaRef = try SuttaRef(suttaUid: "mn1", lang: "en", author: "sujato")
    let context = AudioContext(for: "en")
    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioContext: context)
    }

    await MainActor.run {
      #expect(player.state == .idle)
    }
  }

  // MARK: - PlaybackState Tests

  @Test("PlaybackState equality comparison")
  func testPlaybackStateEquality() {
    #expect(PlaybackState.idle == .idle)
    #expect(PlaybackState.playing == .playing)
    #expect(PlaybackState.paused == .paused)
    #expect(PlaybackState.idle != .playing)
  }

  @Test("PlaybackState failed variant with message")
  func testPlaybackStateFailedMessage() {
    let state = PlaybackState.failed("Test error")
    #expect(state.isFailed == true)
    #expect(state.failureMessage == "Test error")
  }

  @Test("PlaybackState non-failed variants")
  func testPlaybackStateNotFailed() {
    #expect(PlaybackState.idle.isFailed == false)
    #expect(PlaybackState.playing.isFailed == false)
    #expect(PlaybackState.paused.isFailed == false)
    #expect(PlaybackState.idle.failureMessage == nil)
  }

  // MARK: - Observable Tests

  @Test("@Published observables are nil initially")
  func testObservablesInitial() async throws {
    let suttaRef = try SuttaRef(suttaUid: "mn1", lang: "en", author: "sujato")
    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef)
    }

    await MainActor.run {
      #expect(player.synthesisSnapshot == nil)
      #expect(player.playbackSnapshot == nil)
    }
  }

  // MARK: - Preparation Tests

  @Test("prepare() loads segments and transitions state")
  func testPrepareLoadSegments() async throws {
    let suttaRef = try SuttaRef(suttaUid: "thig1.1", lang: "de", author: "sabbamitta")
    let testAudioStorePath = URL(fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player")
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    await MainActor.run {
      #expect(player.state == .idle)
    }

    // Prepare synthesis
    let snapshot = try await player.prepare()

    await MainActor.run {
      #expect(player.state == .paused)
      #expect(snapshot.totalSegments > 0)
      #expect(snapshot.segmentIndex == 0)
      #expect(snapshot.segment.scid == "thig1.1:0.1")
      #expect(!snapshot.trackTitle.isEmpty)
      #expect(snapshot.artist == "sabbamitta")
      #expect(player.playbackSnapshot != nil)
      #expect(player.playbackSnapshot?.totalSegments == snapshot.totalSegments)
    }
  }

  @Test("prepare() throws when sutta not found")
  func testPrepareThrowsNoSegments() async throws {
    let suttaRef = try SuttaRef(suttaUid: "nonexistent", lang: "en", author: "sujato")
    let testAudioStorePath = URL(fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player")
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    do {
      _ = try await player.prepare()
      #expect(Bool(false), "Expected prepare() to throw")
    } catch BackgroundPlayerError.noSegments {
      await MainActor.run {
        #expect(player.state.isFailed)
      }
    }
  }

  // MARK: - Cancellation Tests

  @Test("cancel() from idle state transitions to cancelled")
  func testCancelFromIdle() async throws {
    let suttaRef = try SuttaRef(suttaUid: "mn1", lang: "en", author: "sujato")
    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef)
    }

    await MainActor.run {
      #expect(player.state == .idle)
      player.cancel()
      #expect(player.state == .cancelled)
    }
  }

  @Test("cancel() from paused state transitions to cancelled")
  func testCancelFromPaused() async throws {
    let suttaRef = try SuttaRef(suttaUid: "thig1.1", lang: "de", author: "sabbamitta")
    let testAudioStorePath = URL(fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player")
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      #expect(player.state == .paused)
      player.cancel()
      #expect(player.state == .cancelled)
    }
  }

  @Test("cancel() during synthesis transitions to cancelled")
  func testCancelDuringSynthesis() async throws {
    let suttaRef = try SuttaRef(suttaUid: "thig1.1", lang: "de", author: "sabbamitta")

    // Use temporary directory for AudioStore to prevent cache hits
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    let testAudioStore = AudioStore.create(path: tmpDir)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Start prepare but cancel before it completes
    let prepareTask = Task {
      try await player.prepare()
    }

    // Give synthesis time to start
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

    var sessionToVerify: AudioSynthesisSession?
    await MainActor.run {
      #expect(player.state == .synthesizing)
      player.cancel()
      #expect(player.state == .cancelled)
      sessionToVerify = player.synthesisSession
    }

    // Cleanup: wait for prepare task to complete (will be cancelled)
    _ = try? await prepareTask.value

    // Verify AudioSynthesisSession state is also cancelled
    if let session = sessionToVerify {
      let sessionSnapshot = await session.value
      #expect(sessionSnapshot.state == .cancelled)
    }

    // Clean up temp directory
    try FileManager.default.removeItem(at: tmpDir)
  }

}
