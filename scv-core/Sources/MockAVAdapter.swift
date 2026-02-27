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
  let cc = ColorConsole(#file, #function, dbg.AVAdapter.other)

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
  private let testAudioPath: String?
  private let synthTime: TimeInterval

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

  public init(testAudioPath: String? = nil, synthTime: TimeInterval = 0) {
    self.testAudioPath = testAudioPath
    self.synthTime = synthTime
  }

  // MARK: - IAVAdapter: Synthesis

  public func synthesizeToFile(
    text: String,
    audioContext _: AudioContext,
    outputURL: URL,
  ) async throws {
    cc.ok2(#line, #function, text)

    // Increment counter before work (incremented before method returns)
    stateLock.withLock { state in
      state.synthesisCallCount += 1
    }

    // Simulate synthesis delay if configured
    if synthTime > 0 {
      try await Task.sleep(for: .seconds(synthTime))
    }

    // Copy test audio file instead of synthesizing (fast mock for testing)
    // Use provided testAudioPath or calculate from #file location
    let resolvedTestAudioPath: String
    if let providedPath = testAudioPath {
      resolvedTestAudioPath = providedPath
    } else {
      // Locate test-audio.caf in Tests/Data directory
      // MockAVAdapter is in Sources/, test audio is in Tests/Data/
      let thisFile = #file
      let fileURL = URL(fileURLWithPath: thisFile)
      let sourceDir = fileURL.deletingLastPathComponent().path // .../Sources
      let scvCoreDir = URL(fileURLWithPath: sourceDir)
        .deletingLastPathComponent()
        .path // .../scv-core
      resolvedTestAudioPath = (scvCoreDir as NSString)
        .appendingPathComponent("Tests/Data/test-audio.caf")
    }

    guard FileManager.default.fileExists(atPath: resolvedTestAudioPath) else {
      throw NSError(
        domain: "MockAVAdapter",
        code: -1,
        userInfo: [
          NSLocalizedDescriptionKey: "Test audio file not found at \(resolvedTestAudioPath)",
        ],
      )
    }

    try FileManager.default.copyItem(
      atPath: resolvedTestAudioPath,
      toPath: outputURL.path,
    )
    cc.ok1(#line, #function, outputURL.path)
  }

  // MARK: - IAVAdapter: Player Creation

  public func createPlayer(contentsOf url: URL) throws -> AudioPlayerID {
    cc.ok2(#line, #function, url)

    // Verify file exists
    guard FileManager.default.fileExists(atPath: url.path) else {
      cc.bad1(#line, #function, "file?", url)
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

    cc.ok1(#line, #function, id)
    return id
  }

  // MARK: - IAVAdapter: Playback Control

  public func play(id: AudioPlayerID) {
    cc.ok2(#line, #function, id)
    stateLock.withLock { state in
      state.playCallCount += 1
      state.players[id]?.isPlaying = true
    }
    cc.ok1(#line, #function, id)
  }

  public func stop(id: AudioPlayerID) {
    cc.ok2(#line, #function, id)
    stateLock.withLock { state in
      state.stopCallCount += 1
      state.players[id]?.isPlaying = false
      state.players[id]?.currentTime = 0.0
    }
    cc.ok1(#line, #function, id)
  }

  public func pause(id: AudioPlayerID) {
    cc.ok2(#line, #function, id)
    stateLock.withLock { state in
      state.pauseCallCount += 1
      state.players[id]?.isPlaying = false
    }
    cc.ok1(#line, #function, id)
  }

  public func isPlaying(id: AudioPlayerID) -> Bool {
    cc.ok2(#line, #function, id)
    let result = stateLock.withLock { state in
      state.players[id]?.isPlaying ?? false
    }
    cc.ok1(#line, #function, id)
    return result
  }

  public func duration(id: AudioPlayerID) -> TimeInterval {
    cc.ok2(#line, #function, id)
    let result = stateLock.withLock { state in
      state.players[id]?.duration ?? 0
    }
    cc.ok1(#line, #function, id)
    return result
  }

  public func currentTime(id: AudioPlayerID) -> TimeInterval {
    cc.ok2(#line, #function, id)
    let result = stateLock.withLock { state in
      state.players[id]?.currentTime ?? 0
    }
    cc.ok1(#line, #function, id)
    return result
  }

  public func setCurrentTime(id: AudioPlayerID, time: TimeInterval) {
    cc.ok2(#line, #function, id)
    stateLock.withLock { state in
      if let duration = state.players[id]?.duration {
        state.players[id]?.currentTime = min(time, duration)
      }
    }
    cc.ok1(#line, #function, id)
  }

  public func setDelegate(id: AudioPlayerID,
                          delegate: IAVAudioPlayerDelegate?)
  {
    delegates[id] = delegate
    cc.ok1(#line, #function, id)
  }

  // MARK: - Test Helpers: Manual Delegate Triggering

  /// Manually trigger playback finished callback (for testing event sequences)
  public func simulatePlaybackFinished(id: AudioPlayerID, successfully: Bool) {
    let delegate = delegates[id] ?? nil
    cc.ok2(#line, #function, id)
    delegate?.audioPlayerDidFinishPlaying(successfully: successfully)
    cc.ok1(#line, #function, id)
  }

  /// Manually trigger interruption begin callback (for testing event sequences)
  public func simulateBeginInterruption(id: AudioPlayerID) {
    let delegate = delegates[id] ?? nil
    cc.ok2(#line, #function, id)
    delegate?.audioPlayerBeginInterruption()
    cc.ok1(#line, #function, id)
  }

  /// Manually trigger interruption end callback (for testing event sequences)
  public func simulateEndInterruption(id: AudioPlayerID, shouldResume: Bool) {
    let delegate = delegates[id] ?? nil
    cc.ok2(#line, #function, id)
    delegate?.audioPlayerEndInterruption(shouldResume: shouldResume)
    cc.ok1(#line, #function, id)
  }

  /// Manually trigger decode error callback (for testing event sequences)
  public func simulateDecodeError(id: AudioPlayerID, error: Error?) {
    let delegate = delegates[id] ?? nil
    cc.ok2(#line, #function, id)
    delegate?.audioPlayerDecodeErrorDidOccur(error: error)
    cc.ok1(#line, #function, id)
  }

  /// Get current player state (for test verification)
  public func playerState(id: AudioPlayerID)
    -> (isPlaying: Bool, duration: TimeInterval, currentTime: TimeInterval)?
  {
    stateLock.withLock { state in
      guard let playerState = state.players[id] else { return nil }
      cc.ok1(#line, #function, id)
      return (
        isPlaying: playerState.isPlaying,
        duration: playerState.duration,
        currentTime: playerState.currentTime,
      )
    }
  }
}
