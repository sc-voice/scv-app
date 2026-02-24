import AVFoundation
import Foundation

// MARK: - AudioPlayerID

/// Player identifier for dictionary lookup (hides AVAudioPlayer from clients)
public struct AudioPlayerID: Hashable, Sendable {
  private let id: UUID

  public init() {
    id = UUID()
  }
}

// MARK: - IAVAudioPlayerDelegate

/// Simplified delegate protocol for audio playback events
public protocol IAVAudioPlayerDelegate: AnyObject {
  /// Called when audio finishes playing
  /// - Parameter successfully: True if completed without interruption
  func audioPlayerDidFinishPlaying(successfully: Bool)

  /// Called when audio playback is interrupted (call, alarm)
  func audioPlayerBeginInterruption()

  /// Called when interruption ends
  /// - Parameter shouldResume: True if system suggests resuming playback
  func audioPlayerEndInterruption(shouldResume: Bool)
}

// MARK: - IAVAdapter

/// Protocol wrapping AVFoundation classes for dependency injection
public protocol IAVAdapter {
  // MARK: - AVSpeechSynthesizer Operations

  /// Synthesize text to audio and write to file URL
  /// - Parameters:
  ///   - text: Text to synthesize
  ///   - audioContext: Voice settings (language, voiceId, pitch, rate)
  ///   - outputURL: File URL where audio will be written
  /// - Throws: On synthesis or file write errors
  func synthesizeToFile(
    text: String,
    audioContext: AudioContext,
    outputURL: URL,
  ) async throws

  // MARK: - AVAudioPlayer Operations

  /// Create audio player from file URL
  /// - Parameter url: Audio file URL (must exist on disk)
  /// - Returns: Player ID for use with other player methods
  /// - Throws: If file doesn't exist or format unsupported
  func createPlayer(contentsOf url: URL) throws -> AudioPlayerID

  /// Start playback for given player
  /// - Parameter id: Player ID returned from createPlayer
  func play(id: AudioPlayerID)

  /// Stop playback for given player
  /// - Parameter id: Player ID returned from createPlayer
  func stop(id: AudioPlayerID)

  /// Pause playback for given player
  /// - Parameter id: Player ID returned from createPlayer
  func pause(id: AudioPlayerID)

  /// Check if player is currently playing
  /// - Parameter id: Player ID returned from createPlayer
  /// - Returns: True if playing, false otherwise
  func isPlaying(id: AudioPlayerID) -> Bool

  /// Get duration of audio file in seconds
  /// - Parameter id: Player ID returned from createPlayer
  /// - Returns: Duration in seconds
  func duration(id: AudioPlayerID) -> TimeInterval

  /// Get current playback position in seconds
  /// - Parameter id: Player ID returned from createPlayer
  /// - Returns: Current time in seconds
  func currentTime(id: AudioPlayerID) -> TimeInterval

  /// Set playback position
  /// - Parameters:
  ///   - id: Player ID returned from createPlayer
  ///   - time: Target position in seconds
  func setCurrentTime(id: AudioPlayerID, time: TimeInterval)

  /// Set delegate for player callbacks
  /// - Parameters:
  ///   - id: Player ID returned from createPlayer
  ///   - delegate: Callback receiver
  func setDelegate(id: AudioPlayerID, delegate: IAVAudioPlayerDelegate?)
}

// MARK: - AVAdapter

/// Production implementation wrapping AVFoundation APIs
public class AVAdapter: NSObject, IAVAdapter {
  private var players: [AudioPlayerID: AVAudioPlayer] = [:]
  private var delegates: [AudioPlayerID: IAVAudioPlayerDelegate?] = [:]
  private var delegateBridges: [AVAudioPlayer: AudioPlayerID] = [:]
  private let cc = ColorConsole(#file, "AVAdapter", dbg.AudioStore.other)

  override public init() {
    super.init()
  }

  // MARK: - AVSpeechSynthesizer Operations

  public func synthesizeToFile(
    text: String,
    audioContext: AudioContext,
    outputURL: URL,
  ) async throws {
    let fileManager = FileManager.default
    let timeout: TimeInterval = 5.0

    let synthesizer = AVSpeechSynthesizer()
    let utterance = AVSpeechUtterance(string: text)

    // Configure utterance from audioContext
    utterance.voice = AVSpeechSynthesisVoice(identifier: audioContext.voiceId)
    utterance.pitchMultiplier = audioContext.pitch
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    utterance.volume = 1.0

    // Setup synthesis with file writing
    var audioFile: AVAudioFile?
    let lock = NSLock()
    var isComplete = false
    var synthesisError: Error?
    var totalBytes = 0

    let onBuffer: (AVAudioBuffer) -> Void = { buffer in
      lock.lock()
      defer { lock.unlock() }

      guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
        return
      }

      // Empty buffer signals completion
      if pcmBuffer.frameLength == 0 {
        isComplete = true
        return
      }

      do {
        // First buffer: create file
        if audioFile == nil {
          audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: pcmBuffer.format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false,
          )
        }

        // Write buffer to file
        try audioFile?.write(from: pcmBuffer)

        // Track total bytes written
        let format = pcmBuffer.format
        let bytesPerFrame = format.streamDescription.pointee.mBytesPerFrame
        let bufferBytes = Int(pcmBuffer.frameLength) * Int(bytesPerFrame)
        totalBytes += bufferBytes
      } catch {
        synthesisError = error
      }
    }

    // Start synthesis
    synthesizer.write(utterance, toBufferCallback: onBuffer)

    // Wait for completion (with timeout)
    let timeoutDate = Date().addingTimeInterval(timeout)
    while !isComplete, synthesisError == nil, Date() < timeoutDate {
      usleep(50000) // 50ms sleep
    }

    // If synthesis failed, clean up and throw
    if let error = synthesisError {
      try? fileManager.removeItem(at: outputURL)
      throw error
    }

    if Date() >= timeoutDate {
      try? fileManager.removeItem(at: outputURL)
      throw NSError(
        domain: "AVAdapter",
        code: -1,
        userInfo: [
          NSLocalizedDescriptionKey: "Synthesis timeout after \(timeout)s",
        ],
      )
    }

    // Log successful synthesis with total bytes written
    cc.ok1(
      #line,
      "Synthesis complete: \(outputURL.lastPathComponent), size: \(totalBytes) bytes",
    )

    // Validate synthesis produced sufficient audio data
    // Rough estimate: 1 second = ~88KB (22050 Hz * 4 bytes/sample)
    // Minimum: ~50 bytes/char to detect silent failures
    let minimumBytes = max(10000, text.count * 50)
    if totalBytes < minimumBytes {
      cc.bad1(
        #line,
        "Synthesis failed silently: \(totalBytes) bytes for \(text.count) chars - removing corrupt file",
      )
      do {
        try fileManager.removeItem(at: outputURL)
        cc.ok2(#line, "Corrupt file deleted: \(outputURL.lastPathComponent)")
      } catch {
        cc.bad1(#line, "Failed to delete corrupt file: \(error)")
      }
      throw NSError(
        domain: "AVAdapter",
        code: -2,
        userInfo: [
          NSLocalizedDescriptionKey: "Voice synthesis failed (insufficient audio data: \(totalBytes) bytes for \(text.count) chars)",
        ],
      )
    }
  }

  // MARK: - AVAudioPlayer Operations

  public func createPlayer(contentsOf url: URL) throws -> AudioPlayerID {
    let player = try AVAudioPlayer(contentsOf: url)
    let id = AudioPlayerID()
    players[id] = player
    delegateBridges[player] = id
    player.delegate = self
    return id
  }

  public func play(id: AudioPlayerID) {
    players[id]?.play()
  }

  public func stop(id: AudioPlayerID) {
    players[id]?.stop()
  }

  public func pause(id: AudioPlayerID) {
    players[id]?.pause()
  }

  public func isPlaying(id: AudioPlayerID) -> Bool {
    players[id]?.isPlaying ?? false
  }

  public func duration(id: AudioPlayerID) -> TimeInterval {
    players[id]?.duration ?? 0
  }

  public func currentTime(id: AudioPlayerID) -> TimeInterval {
    players[id]?.currentTime ?? 0
  }

  public func setCurrentTime(id: AudioPlayerID, time: TimeInterval) {
    players[id]?.currentTime = time
  }

  public func setDelegate(id: AudioPlayerID, delegate: IAVAudioPlayerDelegate?)
  {
    delegates[id] = delegate
  }
}

// MARK: - AVAudioPlayerDelegate

extension AVAdapter: @preconcurrency AVAudioPlayerDelegate {
  public func audioPlayerDidFinishPlaying(
    _ player: AVAudioPlayer,
    successfully flag: Bool,
  ) {
    guard let id = delegateBridges[player],
          let delegate = delegates[id] as? IAVAudioPlayerDelegate
    else { return }
    delegate.audioPlayerDidFinishPlaying(successfully: flag)
  }

  public func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
    guard let id = delegateBridges[player],
          let delegate = delegates[id] as? IAVAudioPlayerDelegate
    else { return }
    delegate.audioPlayerBeginInterruption()
  }

  public func audioPlayerEndInterruption(
    _ player: AVAudioPlayer,
    withOptions flags: Int,
  ) {
    guard let id = delegateBridges[player],
          let delegate = delegates[id] as? IAVAudioPlayerDelegate
    else { return }
    #if os(iOS) || os(tvOS) || os(watchOS)
      let shouldResume = (UInt(flags) & AVAudioSession.InterruptionOptions
        .shouldResume
        .rawValue) != 0
    #else
      // macOS doesn't have AVAudioSession
      let shouldResume = false
    #endif
    delegate.audioPlayerEndInterruption(shouldResume: shouldResume)
  }
}
