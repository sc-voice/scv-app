import Foundation
import scvCore
@testable import scvUI
import Testing

@Suite("BackgroundPlayer Tests")
struct BackgroundPlayerTests {
  // MARK: - Initialization Tests

  @Test("Initializes with valid SuttaRef")
  func initialization() async throws {
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
  func initializationWithCustomContext() async throws {
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
  func playbackStateEquality() {
    #expect(PlaybackState.idle == .idle)
    #expect(PlaybackState.playing == .playing)
    #expect(PlaybackState.paused == .paused)
    #expect(PlaybackState.idle != .playing)
  }

  @Test("PlaybackState failed variant with message")
  func playbackStateFailedMessage() {
    let state = PlaybackState.failed("Test error")
    #expect(state.isFailed == true)
    #expect(state.failureMessage == "Test error")
  }

  @Test("PlaybackState non-failed variants")
  func playbackStateNotFailed() {
    #expect(PlaybackState.idle.isFailed == false)
    #expect(PlaybackState.playing.isFailed == false)
    #expect(PlaybackState.paused.isFailed == false)
    #expect(PlaybackState.idle.failureMessage == nil)
  }

  // MARK: - Observable Tests

  @Test("@Published observables are nil initially")
  func observablesInitial() async throws {
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
  func prepareLoadSegments() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
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
  func prepareThrowsNoSegments() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "nonexistent",
      lang: "en",
      author: "sujato",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
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
  func cancelFromIdle() async throws {
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
  func cancelFromPaused() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
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
  func cancelDuringSynthesis() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )

    // Use temporary directory for AudioStore to prevent cache hits
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: tmpDir,
      withIntermediateDirectories: true,
    )
    let testAudioStore = AudioStore.create(path: tmpDir)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Start prepare but cancel before it completes
    let prepareTask = Task {
      try await player.prepare()
    }

    // Give synthesis time to start
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

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

  // MARK: - Playback Control Tests

  @Test("play() from paused state transitions to playing")
  func playFromPaused() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      #expect(player.state == .paused)
      player.play()
      #expect(player.state == .playing)
      #expect(player.playbackSnapshot != nil)
      #expect((player.playbackSnapshot?.playbackDuration ?? 0) > 0)
    }
  }

  @Test("play() from playing state does nothing")
  func playFromPlayingDoesNothing() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      #expect(player.state == .paused)
      player.play()
      #expect(player.state == .playing)
      let firstSnapshot = player.playbackSnapshot
      player.play() // Call play again
      #expect(player.state == .playing)
      #expect(player.playbackSnapshot == firstSnapshot) // Snapshot unchanged
    }
  }

  @Test("pause() from playing state transitions to paused")
  func pauseFromPlaying() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      #expect(player.state == .paused)
      player.play()
      #expect(player.state == .playing)
      player.pause()
      #expect(player.state == .paused)
      #expect(player.playbackSnapshot != nil)
    }
  }

  @Test("pause() from paused state does nothing")
  func pauseFromPausedDoesNothing() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      #expect(player.state == .paused)
      player.pause() // Call pause when already paused
      #expect(player.state == .paused)
    }
  }

  @Test("playbackSnapshot updates with audio duration and elapsed time")
  func playbackSnapshotTiming() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    let initialSnapshot = try await player.prepare()

    await MainActor.run {
      #expect(initialSnapshot.playbackDuration == 0) // Before play
      #expect(initialSnapshot.elapsedPlaybackTime == 0)

      player.play()
      #expect(player.state == .playing)

      // After play, snapshot should have duration
      let playingSnapshot = player.playbackSnapshot
      #expect((playingSnapshot?.playbackDuration ?? 0) > 0)
      #expect((playingSnapshot?.elapsedPlaybackTime ?? 0) >= 0)
    }
  }

  // MARK: - Segment Navigation Tests

  @Test("playNext() advances to next segment and plays")
  func testPlayNext() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      let initialIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(initialIndex == 0) // Start at first segment

      player.playNext()
      #expect(player.state == .playing) // Should be playing new segment

      let nextIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(nextIndex == initialIndex + 1) // Advanced to next segment
    }
  }

  @Test("playNext() at last segment does nothing")
  func playNextAtLastSegment() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    let snapshot = try await player.prepare()
    let lastIndex = snapshot.totalSegments - 1

    await MainActor.run {
      // Manually set currentSegmentIndex to last segment
      let currentPlayer = player
      // Access to currentSegmentIndex is private, so we can't directly set it
      // Instead, playNext until we reach last segment
      while (currentPlayer.playbackSnapshot?.segmentIndex ?? 0) < lastIndex {
        currentPlayer.playNext()
      }

      let indexBeforeCall = currentPlayer.playbackSnapshot?.segmentIndex ?? -1
      currentPlayer.playNext() // Try to advance past last segment
      let indexAfterCall = currentPlayer.playbackSnapshot?.segmentIndex ?? -1

      // Should stay at same segment
      #expect(indexAfterCall == indexBeforeCall)
    }
  }

  @Test("playPrevious() from paused moves to previous segment")
  func playPreviousFromPaused() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      // Advance to second segment first
      player.playNext()
      #expect((player.playbackSnapshot?.segmentIndex ?? -1) == 1)

      let currentIndex = player.playbackSnapshot?.segmentIndex ?? -1
      player.pause()
      player.playPrevious() // From paused state

      let newIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(newIndex == currentIndex - 1) // Moved back one segment
    }
  }

  @Test("playPrevious() at first segment does nothing")
  func playPreviousAtFirstSegment() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
      )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      #expect((player.playbackSnapshot?.segmentIndex ?? -1) ==
        0) // At first segment

      player.playPrevious() // Try to move before first segment
      #expect((player.playbackSnapshot?.segmentIndex ?? -1) ==
        0) // Should stay at first
    }
  }
}
