import Foundation
import scvCore
@testable import scvUI
import Testing

// MARK: - Test Configuration

private func testAdapter(synthTime: TimeInterval = 0,
                         mock: Bool = true) -> IAVAdapter?
{
  guard mock else { return nil }
  let thisFile = #filePath
  let fileURL = URL(fileURLWithPath: thisFile)
  let testsDir = fileURL.deletingLastPathComponent().path
  let testAudioPath = (testsDir as NSString)
    .appendingPathComponent("Data/test-audio.caf")
  return MockAVAdapter(testAudioPath: testAudioPath, synthTime: synthTime)
}

@Suite("B19s:BackgroundPlayerTests")
struct BackgroundPlayerTests {
  // MARK: - PlaybackState Tests

  @Test("B19s:PlaybackState equality comparison")
  func playbackStateEquality() {
    #expect(PlaybackState.idle == .idle)
    #expect(PlaybackState.playing == .playing)
    #expect(PlaybackState.paused == .paused)
    #expect(PlaybackState.idle != .playing)
  }

  @Test("B19s:PlaybackState failed variant with message")
  func playbackStateFailedMessage() {
    let state = PlaybackState.failed("Test error")
    #expect(state.isFailed == true)
    #expect(state.failureMessage == "Test error")
  }

  @Test("B19s:PlaybackState non-failed variants")
  func playbackStateNotFailed() {
    #expect(PlaybackState.idle.isFailed == false)
    #expect(PlaybackState.playing.isFailed == false)
    #expect(PlaybackState.paused.isFailed == false)
    #expect(PlaybackState.idle.failureMessage == nil)
  }

  // MARK: - Preparation Tests

  @Test("B19s:prepare() loads segments and transitions state")
  func prepareLoadSegments() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: projectRoot()
          .appendingPathComponent("local/build/test-background-player").path,
      )
    let testAudioStore = AudioStore.create(
      path: testAudioStorePath,
      adapter: testAdapter(),
    )

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

  @Test("B19s:prepare() throws when sutta not found")
  func prepareThrowsNoSegments() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "nonexistent",
      lang: "en",
      author: "sujato",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: projectRoot()
          .appendingPathComponent("local/build/test-background-player").path,
      )
    let testAudioStore = AudioStore.create(
      path: testAudioStorePath,
      adapter: testAdapter(),
    )

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

  @Test("B19s:cancel() from idle state transitions to cancelled")
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

  @Test("B19s:cancel() from paused state transitions to cancelled")
  func cancelFromPaused() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: projectRoot()
          .appendingPathComponent("local/build/test-background-player").path,
      )
    let testAudioStore = AudioStore.create(
      path: testAudioStorePath,
      adapter: testAdapter(),
    )

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

  @Test("B19s:cancel() during synthesis transitions to cancelled")
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
    let testAudioStore = AudioStore.create(
      path: tmpDir,
      adapter: testAdapter(synthTime: 0.5),
    )

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

  @Test("B19s:play() and pause() are idempotent and update snapshot timing")
  func playPauseControl() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: projectRoot()
          .appendingPathComponent("local/build/test-background-player").path,
      )
    let testAudioStore = AudioStore.create(
      path: testAudioStorePath,
      adapter: testAdapter(),
    )

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    let initialSnapshot = try await player.prepare()

    await MainActor.run {
      #expect(player.state == .paused)
      #expect(initialSnapshot.playbackDuration == 0) // Initial: no duration
      #expect(initialSnapshot
        .elapsedPlaybackTime == 0) // Initial: no elapsed time

      // pause() when already paused should do nothing
      player.pause()
      #expect(player.state == .paused)

      // play() transitions to playing
      player.play()
      #expect(player.state == .playing)
    }

    // Wait for async playback task to start and load audio
    // (includes time for audio effects announcements to complete)
    try await Task.sleep(for: .milliseconds(200))

    await MainActor.run {
      let playingSnapshot = player.playbackSnapshot
      #expect(playingSnapshot != nil)
      #expect((playingSnapshot?.playbackDuration ?? 0) > 0) // Duration loaded
      #expect((playingSnapshot?.elapsedPlaybackTime ?? 0) >=
        0) // Elapsed time available

      // play() when already playing should be idempotent
      player.play()
      #expect(player.state == .playing)
      #expect(player.playbackSnapshot == playingSnapshot) // Snapshot unchanged

      // pause() while playing transitions to paused
      player.pause()
      #expect(player.state == .paused)
      #expect(player.playbackSnapshot != nil) // Snapshot persists

      // pause() when already paused should do nothing
      player.pause()
      #expect(player.state == .paused)
    }
  }

  // MARK: - Segment Navigation Tests

  @Test("B19s:playNext() advances to next segment and plays")
  func testPlayNext() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: projectRoot()
          .appendingPathComponent("local/build/test-background-player").path,
      )
    let testAudioStore = AudioStore.create(
      path: testAudioStorePath,
      adapter: testAdapter(),
    )

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

      player.cancel() // Cleanup playback
    }
  }

  @Test("B19s:playNext() at last segment does nothing")
  func playNextAtLastSegment() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath =
      URL(
        fileURLWithPath: projectRoot()
          .appendingPathComponent("local/build/test-background-player").path,
      )
    let testAudioStore = AudioStore.create(
      path: testAudioStorePath,
      adapter: testAdapter(),
    )

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

      currentPlayer.cancel() // Cleanup playback
    }
  }

  @Test("B19s:playPrevious() moves backward and does nothing at first segment")
  func playPreviousBehavior() async throws {
    guard let suttaRef = SuttaRef.create("thig1.1:0.2/de/sabbamitta") else {
      #expect(Bool(false), "Failed to create SuttaRef with segment")
      return
    }
    let testAudioStorePath =
      URL(
        fileURLWithPath: projectRoot()
          .appendingPathComponent("local/build/test-background-player").path,
      )
    let testAudioStore = AudioStore.create(
      path: testAudioStorePath,
      adapter: testAdapter(),
    )

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state starting at segment 0.2 (index 1)
    _ = try await player.prepare()

    await MainActor.run {
      let currentIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(currentIndex == 1) // Starts at segment 0.2

      // playPrevious() moves to previous segment
      player.playPrevious()

      var newIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(newIndex == 0) // Moved back to first segment

      // playPrevious() at first segment does nothing
      player.playPrevious()

      newIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(newIndex == 0) // Stays at first segment

      player.cancel() // Cleanup playback
    }
  }
}
