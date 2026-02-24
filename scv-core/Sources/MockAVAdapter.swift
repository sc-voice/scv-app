//
//  MockAVAdapter.swift
//  scv-core
//
//  Mock implementation of IAVAdapter for fast unit tests without real audio
//  synthesis
//

import AVFoundation
import Foundation
import Synchronization

// MARK: - MockAVAdapter

/// Mock implementation of IAVAdapter for unit testing
/// - Writes minimal silent audio files instantly (no actual synthesis)
/// - Simulates playback state in memory (no real audio hardware)
/// - Allows manual delegate triggering for testing event sequences
public class MockAVAdapter: IAVAdapter {
  // MARK: - State Management

  private struct State {
    struct PlayerState {
      var isPlaying: Bool = false
      var duration: TimeInterval = 1.0
      var currentTime: TimeInterval = 0.0
    }

    var players: [AudioPlayerID: PlayerState] = [:]
    var synthesisCallCount: Int = 0
    var createPlayerCallCount: Int = 0
    var playCallCount: Int = 0
    var pauseCallCount: Int = 0
    var stopCallCount: Int = 0
  }

  private let stateLock = Mutex(State())
  private var delegates: [AudioPlayerID: IAVAudioPlayerDelegate?] =
    [:] // Outside Mutex (delegates aren't Sendable)

  // MARK: - Call Counters (for test verification)

  /// Number of times synthesizeToFile was called
  public var synthesisCallCount: Int {
    stateLock.withLock { $0.synthesisCallCount }
  }

  /// Number of times createPlayer was called
  public var createPlayerCallCount: Int {
    stateLock.withLock { $0.createPlayerCallCount }
  }

  /// Number of times play was called
  public var playCallCount: Int {
    stateLock.withLock { $0.playCallCount }
  }

  /// Number of times pause was called
  public var pauseCallCount: Int {
    stateLock.withLock { $0.pauseCallCount }
  }

  /// Number of times stop was called
  public var stopCallCount: Int {
    stateLock.withLock { $0.stopCallCount }
  }

  public init() {}

  // MARK: - IAVAdapter: Synthesis

  public func synthesizeToFile(
    text _: String,
    audioContext _: AudioContext,
    outputURL: URL,
  ) async throws {
    // Increment counter before work (incremented before method returns)
    stateLock.withLock { state in
      state.synthesisCallCount += 1
    }

    // Copy test audio file instead of synthesizing (fast mock for testing)
    // Locate test-audio.caf in Tests/Data directory
    // MockAVAdapter is in Sources/, test audio is in Tests/Data/
    let thisFile = #file
    let fileURL = URL(fileURLWithPath: thisFile)
    let sourceDir = fileURL.deletingLastPathComponent().path // .../Sources
    let scvCoreDir = URL(fileURLWithPath: sourceDir).deletingLastPathComponent()
      .path // .../scv-core
    let testAudioPath = (scvCoreDir as NSString)
      .appendingPathComponent("Tests/Data/test-audio.caf")

    guard FileManager.default.fileExists(atPath: testAudioPath) else {
      throw NSError(
        domain: "MockAVAdapter",
        code: -1,
        userInfo: [
          NSLocalizedDescriptionKey: "Test audio file not found at \(testAudioPath)",
        ],
      )
    }

    try FileManager.default.copyItem(
      atPath: testAudioPath,
      toPath: outputURL.path,
    )
  }

  // MARK: - IAVAdapter: Player Creation

  public func createPlayer(contentsOf url: URL) throws -> AudioPlayerID {
    // Verify file exists
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw NSError(
        domain: "MockAVAdapter",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "File not found: \(url.path)"],
      )
    }

    let id = AudioPlayerID()

    // Increment counter and create initial player state atomically
    stateLock.withLock { state in
      state.createPlayerCallCount += 1
      state.players[id] = State.PlayerState(duration: 1.0)
    }

    return id
  }

  // MARK: - IAVAdapter: Playback Control

  public func play(id: AudioPlayerID) {
    stateLock.withLock { state in
      state.playCallCount += 1
      state.players[id]?.isPlaying = true
    }
  }

  public func stop(id: AudioPlayerID) {
    stateLock.withLock { state in
      state.stopCallCount += 1
      state.players[id]?.isPlaying = false
      state.players[id]?.currentTime = 0.0
    }
  }

  public func pause(id: AudioPlayerID) {
    stateLock.withLock { state in
      state.pauseCallCount += 1
      state.players[id]?.isPlaying = false
    }
  }

  public func isPlaying(id: AudioPlayerID) -> Bool {
    stateLock.withLock { state in
      state.players[id]?.isPlaying ?? false
    }
  }

  public func duration(id: AudioPlayerID) -> TimeInterval {
    stateLock.withLock { state in
      state.players[id]?.duration ?? 0
    }
  }

  public func currentTime(id: AudioPlayerID) -> TimeInterval {
    stateLock.withLock { state in
      state.players[id]?.currentTime ?? 0
    }
  }

  public func setCurrentTime(id: AudioPlayerID, time: TimeInterval) {
    stateLock.withLock { state in
      if let duration = state.players[id]?.duration {
        state.players[id]?.currentTime = min(time, duration)
      }
    }
  }

  public func setDelegate(id: AudioPlayerID,
                          delegate: IAVAudioPlayerDelegate?)
  {
    delegates[id] = delegate
  }

  // MARK: - Test Helpers: Manual Delegate Triggering

  /// Manually trigger playback finished callback (for testing event sequences)
  public func simulatePlaybackFinished(id: AudioPlayerID, successfully: Bool) {
    let delegate = delegates[id] ?? nil
    delegate?.audioPlayerDidFinishPlaying(successfully: successfully)
  }

  /// Manually trigger interruption begin callback (for testing event sequences)
  public func simulateBeginInterruption(id: AudioPlayerID) {
    let delegate = delegates[id] ?? nil
    delegate?.audioPlayerBeginInterruption()
  }

  /// Manually trigger interruption end callback (for testing event sequences)
  public func simulateEndInterruption(id: AudioPlayerID, shouldResume: Bool) {
    let delegate = delegates[id] ?? nil
    delegate?.audioPlayerEndInterruption(shouldResume: shouldResume)
  }

  /// Get current player state (for test verification)
  public func playerState(id: AudioPlayerID)
    -> (isPlaying: Bool, duration: TimeInterval, currentTime: TimeInterval)?
  {
    stateLock.withLock { state in
      guard let playerState = state.players[id] else { return nil }
      return (
        isPlaying: playerState.isPlaying,
        duration: playerState.duration,
        currentTime: playerState.currentTime,
      )
    }
  }
}
