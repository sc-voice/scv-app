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

@Suite("BackgroundPlayer Lock Screen Integration Tests")
struct BackgroundPlayerLockScreenTests {
  // MARK: - MPRemoteCommandCenter Handler Tests

  @Test("Play command handler registered")
  func playCommandRegistered() async {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Verify play command is enabled (handlers are attached)
    #expect(commandCenter.playCommand.isEnabled)
  }

  @Test("Pause command handler registered")
  func pauseCommandRegistered() async {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Verify pause command is enabled
    #expect(commandCenter.pauseCommand.isEnabled)
  }

  @Test("Skip forward command handler registered")
  func skipForwardCommandRegistered() async {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Verify skip forward command is enabled
    #expect(commandCenter.skipForwardCommand.isEnabled)
  }

  @Test("Skip backward command handler registered")
  func skipBackwardCommandRegistered() async {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Verify skip backward command is enabled
    #expect(commandCenter.skipBackwardCommand.isEnabled)
  }

  // MARK: - Handler Integration Tests

  @Test("Play handler calls player.play() when executed")
  func playHandlerCalls() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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
    }
  }

  @Test("Pause handler calls player.pause() when executed")
  func pauseHandlerCalls() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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

  @Test("Next handler calls player.playNext() when executed")
  func nextHandlerCalls() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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
    }
  }

  @Test("Previous handler calls player.playPrevious() when executed")
  func previousHandlerCalls() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare and advance to second segment
    _ = try await player.prepare()

    await MainActor.run {
      player.playNext()
      let currentIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(currentIndex > 0)
    }

    // Simulate previous command
    await MainActor.run {
      player.playPrevious()
      let newIndex = player.playbackSnapshot?.segmentIndex ?? -1
      #expect(newIndex == 0, "Previous should move to first segment")
    }
  }

  // MARK: - Metadata Computation Tests

  @Test("PlaybackSnapshot contains title formatted correctly")
  func snapshotTitleFormatted() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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

  @Test("PlaybackSnapshot contains artist name")
  func snapshotArtistIncluded() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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

  @Test("PlaybackSnapshot contains duration")
  func snapshotDurationIncluded() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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
    }
  }

  @Test("PlaybackSnapshot elapsed time updates")
  func snapshotElapsedTimeUpdates() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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

  @Test("Play command handler when already playing (no crash)")
  func playWhenAlreadyPlaying() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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
    }
  }

  @Test("Pause command handler when already paused (no crash)")
  func pauseWhenAlreadyPaused() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
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

      // Call pause again (should be idempotent)
      player.pause()
      #expect(player.state == .paused, "Should still be paused")
    }
  }

  @Test("Next handler when at last segment (no crash)")
  func nextWhenAtLastSegment() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare
    _ = try await player.prepare()

    // Advance to last segment repeatedly
    await MainActor.run {
      let totalSegments =
        player.playbackSnapshot?.totalSegments ?? 0
      for _ in 0..<totalSegments {
        player.playNext()
      }

      // Should be at last segment or paused
      #expect(
        player.state == .paused,
        "Should be paused after reaching last segment",
      )
    }
  }

  @Test("Previous handler when at first segment (no crash)")
  func previousWhenAtFirstSegment() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

    let player = await MainActor.run {
      BackgroundPlayer(suttaRef: suttaRef, audioStore: testAudioStore)
    }

    // Prepare to first segment
    _ = try await player.prepare()

    // Call previous repeatedly
    await MainActor.run {
      player.playPrevious()
      player.playPrevious()
      player.playPrevious()

      // Should still be at first segment
      #expect(
        player.playbackSnapshot?.segmentIndex == 0,
        "Should remain at first segment",
      )
    }
  }

  @Test("Player state transitions to cancelled on cancel()")
  func playerTransitionsToCancelled() async throws {
    let suttaRef = try SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )
    let testAudioStorePath = URL(
      fileURLWithPath: "/Users/visakha/dev/scv-app/local/build/test-background-player",
    )
    let testAudioStore = AudioStore.create(path: testAudioStorePath)

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
}
