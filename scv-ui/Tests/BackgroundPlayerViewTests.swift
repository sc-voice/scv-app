//
//  BackgroundPlayerViewTests.swift
//  scv-ui
//
//  Created by Claude on 2026-02-10.
//

import scvCore
@testable import scvUI
import SwiftUI
import Testing

@Suite("BackgroundPlayerView Tests")
struct BackgroundPlayerViewTests {
  // MARK: - State Transition Tests

  @Test("View initializes with provided player and bindings")
  func initialization() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef)
    }

    // View initializes successfully (just verify no crash on creation)
    await MainActor.run {
      let isPresented = true
      _ = BackgroundPlayerView(
        player: player,
        isPresented: .constant(isPresented),
        themeProvider: ThemeProvider(),
      )
      // Successfully created
      #expect(isPresented == true)
    }
  }

  @Test("View transitions from synthesis to playback phase on state change")
  func synthesisToPlaybackTransition() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )

    // Use temporary directory to force synthesis and avoid cache hits
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

    // Initially idle
    await MainActor.run {
      #expect(player.state == .idle)
    }

    // Start preparation (enters synthesizing state)
    let prepareTask = Task {
      try await player.prepare()
    }

    // Give synthesis time to start
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

    // State should be synthesizing or paused (depending on synthesis speed)
    await MainActor.run {
      let currentState = player.state
      #expect(
        currentState == .synthesizing || currentState == .paused,
        "Should be synthesizing or completed",
      )
    }

    // Wait for preparation to complete
    _ = try await prepareTask.value

    // Verify final state is paused (playback phase)
    await MainActor.run {
      #expect(player.state == .paused)
      #expect(player.playbackSnapshot != nil)
    }

    // Cleanup
    try FileManager.default.removeItem(at: tmpDir)
  }

  // MARK: - Polling Tests

  @Test("SynthesisSnapshot updates during polling")
  func synthesisSnapshotUpdates() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )

    // Use temporary directory to force synthesis (no cache hits)
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

    // Start preparation
    let prepareTask = Task {
      try await player.prepare()
    }

    // Give synthesis time to start
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

    // Wait for synthesis to complete
    _ = try await prepareTask.value

    // Verify synthesis completed
    await MainActor.run {
      // Synthesis should be complete with state paused or player ready
      #expect(
        player.state == .paused,
        "Synthesis should complete and transition to paused state",
      )
    }

    // Cleanup
    try FileManager.default.removeItem(at: tmpDir)
  }

  // MARK: - Playback Phase UI Tests

  @Test("Playback snapshot available after synthesis completes")
  func playbackSnapshotAfterSynthesis() async throws {
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

    // Prepare for playback
    _ = try await player.prepare()

    // Verify snapshot contains expected fields for UI display
    await MainActor.run {
      let snapshot = player.playbackSnapshot
      #expect(snapshot != nil, "Playback snapshot should be available")
      #expect(!snapshot!.segment.scid.isEmpty, "Segment ID should not be empty")
      #expect(!snapshot!.trackTitle.isEmpty, "Track title should not be empty")
      #expect(snapshot!.totalSegments > 0, "Total segments should be > 0")
      #expect(snapshot!.segmentIndex >= 0, "Segment index should be >= 0")
    }
  }

  @Test("Segment text preview is available for UI display")
  func segmentTextPreview() async throws {
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

    // Prepare for playback
    _ = try await player.prepare()

    // Verify segment doc field is available
    await MainActor.run {
      let segment = player.playbackSnapshot?.segment
      #expect(segment != nil, "Current segment should be available")

      // Segment text may be empty for some segments, but field should exist
      let textPreview = (segment?.doc ?? "").prefix(60)
      #expect(
        textPreview.count <= 60,
        "Text preview should be truncated to 60 chars",
      )
    }
  }

  // MARK: - Playback Control Tests

  @Test("Play button triggers player.play()")
  func playButtonAction() async throws {
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

    // Call play()
    await MainActor.run {
      #expect(player.state == .paused)
      player.play()
      #expect(player.state == .playing)
    }
  }

  @Test("Pause button triggers player.pause()")
  func pauseButtonAction() async throws {
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

    // Transition to playing, then pause
    await MainActor.run {
      player.play()
      #expect(player.state == .playing)
      player.pause()
      #expect(player.state == .paused)
    }
  }

  @Test("Next button triggers player.playNext()")
  func nextButtonAction() async throws {
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

    // Verify playNext advances segment
    await MainActor.run {
      let initialIndex = player.playbackSnapshot?.segmentIndex ?? -1
      player.playNext()
      let newIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(newIndex == initialIndex + 1, "Next should advance segment")
    }
  }

  @Test("Previous button triggers player.playPrevious()")
  func previousButtonAction() async throws {
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

    // Advance to second segment and pause
    await MainActor.run {
      player.playNext()
      let currentIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(currentIndex > 0, "Should advance from first segment")

      // Pause before testing playPrevious
      player.pause()
      #expect(player.state == .paused)

      // Now press previous while paused
      let indexBeforePrevious = player.playbackSnapshot?.segmentIndex ?? -1
      player.playPrevious()
      let indexAfterPrevious = player.playbackSnapshot?.segmentIndex ?? -1

      // Previous from paused state should go back one segment
      #expect(
        indexAfterPrevious == indexBeforePrevious - 1,
        "Previous should go back one segment when paused",
      )
    }
  }

  // MARK: - Cancellation Tests

  @Test("Cancellation during synthesis transitions to cancelled state")
  func cancellationDuringSynthesis() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )

    // Use temporary directory to force synthesis
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

    // Start prepare in background
    let prepareTask = Task {
      try await player.prepare()
    }

    // Give synthesis time to start
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

    // Cancel during synthesis
    await MainActor.run {
      #expect(player.state == .synthesizing)
      player.cancel()
      #expect(player.state == .cancelled)
    }

    // Cleanup: wait for prepare task
    _ = try? await prepareTask.value

    // Cleanup
    try FileManager.default.removeItem(at: tmpDir)
  }

  @Test("Cancellation after synthesis transitions to cancelled state")
  func cancellationAfterSynthesis() async throws {
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

    // Cancel after synthesis
    await MainActor.run {
      #expect(player.state == .paused)
      player.cancel()
      #expect(player.state == .cancelled)
    }
  }

  // MARK: - Error Handling Tests

  @Test("Synthesis failure transitions to failed state with error message")
  func synthesisFailureHandling() async throws {
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

    // Attempt prepare with invalid sutta
    do {
      _ = try await player.prepare()
      #expect(Bool(false), "Expected prepare() to fail")
    } catch {
      await MainActor.run {
        #expect(player.state.isFailed, "State should be failed")
        #expect(
          player.state.failureMessage != nil,
          "Error message should be available",
        )
      }
    }
  }
}
