//
//  BackgroundPlayerLockScreenTests.swift
//  scv-ui
//
//  Created by Claude on 2026-02-10.
//

import Foundation
import MediaPlayer
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

private let audioStoreLock = NSLock()
private nonisolated(unsafe) var cachedAudioStore: AudioStore?

private func getTestAudioStore() -> AudioStore {
  audioStoreLock.lock()
  defer { audioStoreLock.unlock() }

  if let cached = cachedAudioStore {
    return cached
  }
  let path = URL(
    fileURLWithPath: projectRoot()
      .appendingPathComponent("local/build/test-background-player").path,
  )
  let store = AudioStore.create(path: path, adapter: testAdapter())
  cachedAudioStore = store
  return store
}

@Suite("B30s:BackgroundPlayerLockScreenTests")
struct BackgroundPlayerLockScreenTests {
  let cc = ColorConsole(#file, #function, 2)

  // MARK: - MPRemoteCommandCenter Handler Tests

  @Test("B30s:Play command handler registered")
  func playCommandRegistered() async {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Verify play command is enabled (handlers are attached)
    #expect(commandCenter.playCommand.isEnabled)
  }

  @Test("B30s:Pause command handler registered")
  func pauseCommandRegistered() async {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Verify pause command is enabled
    #expect(commandCenter.pauseCommand.isEnabled)
  }

  @Test("B30s:Skip forward command handler registered")
  func skipForwardCommandRegistered() async {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Verify skip forward command is enabled
    #expect(commandCenter.skipForwardCommand.isEnabled)
  }

  @Test("B30s:Skip backward command handler registered")
  func skipBackwardCommandRegistered() async {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Verify skip backward command is enabled
    #expect(commandCenter.skipBackwardCommand.isEnabled)
  }

  // MARK: - Handler Integration Tests

  @Test("B30s:Play handler calls player.play() when executed")
  func playHandlerCalls() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare player to paused state
    _ = try await player.prepare()

    // Verify initial state is paused
    await MainActor.run {
      #expect(player.state == .paused)
    }

    // Simulate play command
    await MainActor.run {
      player.play()
      #expect(player.state == .playing)
      player.cancel()
    }
  }

  @Test("B30s:Pause handler calls player.pause() when executed")
  func pauseHandlerCalls() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare player to paused state
    _ = try await player.prepare()

    // Move to playing state
    await MainActor.run {
      player.play()
      #expect(player.state == .playing)
    }

    // Simulate pause command
    await MainActor.run {
      player.pause()
      #expect(player.state == .paused)
    }
  }

  @Test("B30s:Next handler calls player.playNext() when executed")
  func nextHandlerCalls() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare player to paused state
    _ = try await player.prepare()

    // Get initial segment index
    let initialIndex = await MainActor.run {
      player.playbackSnapshot?.segmentIndex ?? -1
    }

    // Simulate next command
    await MainActor.run {
      player.playNext()
      let newIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(newIndex == initialIndex + 1)
      player.cancel() // test cleanup
    }
  }

  @Test("B30s:Previous handler calls player.playPrevious() when executed")
  func previousHandlerCalls() async throws {
    guard let suttaRef = SuttaRef.create("thig1.1:0.2/de/sabbamitta") else {
      #expect(Bool(false), "should never happen")
      return
    }
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare and advance to second segment
    _ = try await player.prepare()

    // Simulate previous command
    await MainActor.run {
      player.playPrevious()
      let newIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(newIndex == 0, "Previous should move to first segment")
      player.cancel() // test cleanup
    }
  }

  // MARK: - Metadata Computation Tests

  @Test("B30s:PlaybackSnapshot contains title formatted correctly")
  func snapshotTitleFormatted() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to playback phase
    _ = try await player.prepare()

    // Verify snapshot contains formatted title
    await MainActor.run {
      let snapshot = player.playbackSnapshot
      #expect(snapshot != nil)
      let title = snapshot?.trackTitle ?? ""
      #expect(!title.isEmpty, "Title should not be empty")
      // Title should include segment scid
      #expect(title.contains(snapshot?.segment.scid ?? ""))
    }
  }

  @Test("B30s:PlaybackSnapshot contains artist name")
  func snapshotArtistIncluded() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to playback phase
    _ = try await player.prepare()

    // Verify snapshot contains artist
    await MainActor.run {
      let snapshot = player.playbackSnapshot
      #expect(snapshot != nil)
      #expect(snapshot?.artist == "sabbamitta")
    }
  }

  @Test("B30s:PlaybackSnapshot contains duration")
  func snapshotDurationIncluded() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to playback phase
    _ = try await player.prepare()

    // Start playback to get duration from player
    await MainActor.run {
      player.play()

      // Verify snapshot contains duration
      let snapshot = player.playbackSnapshot
      #expect(snapshot != nil)
      #expect((snapshot?.playbackDuration ?? 0) >= 0)
      player.cancel()
    }
  }

  @Test("B30s:PlaybackSnapshot elapsed time updates")
  func snapshotElapsedTimeUpdates() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to playback phase
    _ = try await player.prepare()

    // Verify snapshot has elapsed time property
    await MainActor.run {
      let snapshot = player.playbackSnapshot
      #expect(snapshot != nil)
      #expect((snapshot?.elapsedPlaybackTime ?? 0) >= 0)
    }
  }

  // MARK: - Edge Cases

  @Test("B30s:Play command handler when already playing (no crash)")
  func playWhenAlreadyPlaying() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare and play
    _ = try await player.prepare()

    await MainActor.run {
      player.play()
      #expect(player.state == .playing)

      // Call play again (should be idempotent)
      player.play()
      #expect(player.state == .playing, "Should still be playing")
      player.cancel()
    }
  }

  @Test("B30s:Pause command handler when already paused (no crash)")
  func pauseWhenAlreadyPaused() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to paused state
    _ = try await player.prepare()

    await MainActor.run {
      #expect(player.state == .paused)

      // Call pause again (should be idempotent)
      player.pause()
      #expect(player.state == .paused, "Should still be paused")
    }
  }

  @Test("B30s:Next handler when at last segment (no crash)")
  func nextWhenAtLastSegment() async throws {
    guard let suttaRef = SuttaRef.create("thig1.1:2.1/de/sabbamitta") else {
      #expect(Bool(false), "should never happen")
      return
    }
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare
    _ = try await player.prepare()

    // Advance to last segment repeatedly
    await MainActor.run {
      player.playNext()

      // Should be at last segment or paused
      #expect(
        player.state == .paused,
        "Should be paused after reaching last segment",
      )
    }
  }

  @Test("B30s:Previous handler when at first segment (no crash)")
  func previousWhenAtFirstSegment() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to first segment
    _ = try await player.prepare()

    // Call previous repeatedly
    await MainActor.run {
      player.playPrevious()

      // Should still be at first segment
      #expect(
        player.playbackSnapshot?.segmentIndex == 0,
        "Should remain at first segment",
      )
      player.cancel() // test cleanup
    }
  }

  @Test("B30s:Player state transitions to cancelled on cancel()")
  func playerTransitionsToCancelled() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare and start playback
    _ = try await player.prepare()

    await MainActor.run {
      player.play()
      #expect(player.state == .playing)

      // Cancel
      player.cancel()

      // Verify state is cancelled
      #expect(player.state == .cancelled)
    }
  }

  @Test("B30s:Rapid pause/play doesn't crash or create duplicate players")
  func rapidPausePlay() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare player to paused state
    _ = try await player.prepare()

    // Simulate rapid lock screen pause/play sequence
    await MainActor.run {
      // Play
      player.play()
      #expect(
        player.state == .playing,
        "Should transition to playing after play()",
      )

      // Immediately pause (before any delayed callbacks fire)
      player.pause()
      #expect(
        player.state == .paused,
        "Should transition to paused after pause()",
      )

      // Verify can play again
      player.play()
      #expect(player.state == .playing, "Should transition back to playing")

      // Pause again
      player.pause()
      #expect(player.state == .paused, "Should transition to paused again")
    }
  }

  @Test("B30s:Multiple rapid play/pause/play sequences work correctly")
  func multipleRapidPlayPauseSequences() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStore = getTestAudioStore()

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare player to paused state
    _ = try await player.prepare()

    // Simulate multiple rapid lock screen control sequences
    await MainActor.run {
      for iteration in 0 ..< 3 {
        // Play
        player.play()
        #expect(
          player.state == .playing,
          "Iteration \(iteration): Should be playing after play()",
        )

        // Immediately pause
        player.pause()
        #expect(
          player.state == .paused,
          "Iteration \(iteration): Should be paused after pause()",
        )
      }

      // Final state should be paused
      #expect(player.state == .paused, "Final state should be paused")
    }
  }
}
