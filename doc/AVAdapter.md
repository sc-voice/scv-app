# AVAdapter

## Overview

IAVAdapter protocol provides dependency injection wrapper for AVFoundation classes (AVSpeechSynthesizer, AVAudioPlayer) to enable fast unit tests without real audio synthesis or playback.

**Current problem:** Tests use real AVFoundation APIs requiring 29s execution time. CachedSynthesizerTests (8.3s), BackgroundPlayerViewTests (7.7s), and SynthesizerPerformanceTests (3.9s) all synthesize actual audio.

**Solution:** Protocol abstraction enables mock implementations for unit tests while preserving production behavior.

## Design

### 1. IAVAdapter Protocol

Location: `scv-core/Sources/AVAdapter.swift`

```swift
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
    outputURL: URL
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

/// Player identifier for dictionary lookup (hides AVAudioPlayer from clients)
public struct AudioPlayerID: Hashable, Sendable {
  private let id: UUID

  public init() {
    self.id = UUID()
  }
}

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
```

### 2. AVAdapter (Production Implementation)

Location: `scv-core/Sources/AVAdapter.swift` (same file as protocol)

Thin wrapper around actual AVFoundation APIs:
1. `synthesizeToFile`: Uses AVSpeechSynthesizer.write() with buffer callback, writes to AVAudioFile with pcmFormatFloat32
2. `createPlayer`: Creates AVAudioPlayer and stores in internal dictionary keyed by ID
3. Player methods: Simple pass-through to AVAudioPlayer instance for given ID
4. Delegate bridge: Translates AVAudioPlayerDelegate callbacks to IAVAudioPlayerDelegate calls

**Design principles:**
- No actor isolation - simple wrapper without threading management
- ID-based API hides AVAudioPlayer references from clients
- Synchronous wait loop in synthesizeToFile (usleep) matches AudioStore pattern
- Platform-conditional handling for AVAudioSession (iOS only)

See: `scv-core/Sources/AudioStore.swift` (synthesis pattern), `scv-ui/Sources/scvUI/CachedSynthesizer.swift` (playback client)

### 3. MockAVAdapter (Test Implementation)

Location: `scv-core/Tests/MockAVAdapter.swift`

Mock implementation for fast unit tests:
1. `synthesizeToFile`: Writes silent/minimal audio file instantly (no actual synthesis)
2. `createPlayer`: Returns token without creating real player
3. Player methods: Track state in memory, return immediately
4. Delegate calls: Manually triggerable for testing event sequences

**Benefits:**
- Zero synthesis time (instant file writes)
- No audio hardware required
- Deterministic playback simulation
- Controllable delegate event timing

## Usage Examples

### Production Usage

```swift
// In AudioStore
let adapter: IAVAdapter = AVAdapter() // Production implementation

func storeAudio(text: String, audioContext: AudioContext) async throws -> URL {
  let outputURL = audioUrl(text: text, audioContext: audioContext, forceUrl: true)!
  try await adapter.synthesizeToFile(
    text: text,
    audioContext: audioContext,
    outputURL: outputURL
  )
  return outputURL
}
```

### Test Usage

```swift
// In CachedSynthesizerTests
@Test
func cachedSynthesizerPlaysImmediately() async throws {
  let mockAdapter = MockAVAdapter()
  let testStore = AudioStore.create(
    path: tempDir,
    adapter: mockAdapter // Inject mock
  )

  let synth = CachedSynthesizer(audioStore: testStore)

  // Fast: mock synthesizes instantly
  try synth.playText("test", audioContext: AudioContext(for: "en"))

  #expect(mockAdapter.synthesisCallCount == 1)
  #expect(mockAdapter.playCallCount == 1)
}
```

## Implementation Notes

### AVAdapter (Production)

Implementation wraps actual AVFoundation APIs with ID-based access to AVAudioPlayer instances stored in internal dictionary.

### MockAVAdapter (Test)

Mock implementation writes silent/minimal audio files instantly and simulates playback state in memory without audio hardware.

## References

- `scv-core/Sources/AudioStore.swift` - Primary synthesis client
- `scv-ui/Sources/scvUI/CachedSynthesizer.swift` - Primary playback client
- `scv-ui/Sources/scvUI/ISpeechSynthesizer.swift` - Existing synthesis protocol (partial overlap)
- `scv-ui/Sources/scvUI/BackgroundPlayer.swift` - Secondary playback client
- `scv-ui/Tests/CachedSynthesizerTests.swift` - Target test suite (8.3s)
- `scv-ui/Tests/BackgroundPlayerViewTests.swift` - Target test suite (7.7s)
- `scv-ui/Tests/SynthesizerPerformanceTests.swift` - Target test suite (3.9s)

## Related Tasks

- T_AZyKy57xc: Create AVAdapter protocol and implementation (current task)
- T_AZyHnmfdc: Investigate slow scv-ui tests (blocked by current task)
