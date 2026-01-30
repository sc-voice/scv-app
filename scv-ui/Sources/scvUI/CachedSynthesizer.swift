import AVFoundation
import Foundation
import scvCore

/// Concrete implementation of ISpeechSynthesizer wrapping AVAudioPlayer for
/// cached audio playback.
/// Translates AVAudioPlayerDelegate callbacks to IPlaybackDelegate events.
/// Uses AudioStore to retrieve cached/synthesized audio files for playback.
///
/// IMPORTANT: @MainActor on class enforces playback lifecycle coordination with
/// AudioStore.
/// AudioStore contract: URLs are stable until next playText() call on
/// MainActor.
/// This isolation ensures background compression can't interfere with active
/// playback.
/// Also allows nonisolated delegate methods to safely access mutable state.
@MainActor
final class CachedSynthesizer: NSObject, ISpeechSynthesizer,
  AVAudioPlayerDelegate
{
  private let cc = ColorConsole(#file, #function, dbg.SuttaPlayer.other)
  private let audioStore: AudioStore
  private var audioPlayer: AVAudioPlayer?
  private var isCurrentlySpeaking = false

  var playbackDelegate: IPlaybackDelegate?

  init(audioStore: AudioStore = .shared) {
    self.audioStore = audioStore
    super.init()
    cc.ok2(#line, "init() complete")
  }

  var isSpeaking: Bool {
    isCurrentlySpeaking && (audioPlayer?.isPlaying ?? false)
  }

  var delegate: AVSpeechSynthesizerDelegate? {
    get { nil }
    set { /* AVAudioPlayer has no AVSpeechSynthesizerDelegate equivalent */ }
  }

  /// AudioStore automatically creates a new AVSpeechSynthesizer for each
  /// synthesis
  func resetSynthesizer() {}

  func stopSpeaking(at _: AVSpeechBoundary) -> Bool {
    guard isCurrentlySpeaking else { return false }
    audioPlayer?.stop()
    isCurrentlySpeaking = false
    cc.ok2(#line, "Stopped playback")
    return true
  }

  func playText(_ text: String, audioContext: AudioContext) throws {
    cc.ok2(#line, "playText starting: \(text.prefix(50))...")

    // Stop any current playback
    audioPlayer?.stop()
    isCurrentlySpeaking = false

    // Get cached audio file from AudioStore
    guard let audioUrl = audioStore.audioUrl(
      text: text,
      audioContext: audioContext,
    ) else {
      cc.bad1(#line, "Audio not cached for text: \(text.prefix(50))...")
      throw NSError(
        domain: "CachedSynthesizer",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Audio not cached for playback"],
      )
    }
    cc.ok2(#line, "Got audio URL: \(audioUrl.lastPathComponent)")

    // Create and configure AVAudioPlayer
    let player = try AVAudioPlayer(contentsOf: audioUrl)
    player.delegate = self
    audioPlayer = player

    // Start playback
    isCurrentlySpeaking = true
    player.play()
    cc.ok2(#line, "Playback started")

    // Emit playback started event (AVAudioPlayer has no "did start" callback)
    playbackDelegate?.onPlaybackStarted()
  }

  // MARK: - AVAudioPlayerDelegate (translate to IPlaybackDelegate)

  nonisolated func audioPlayerDidFinishPlaying(
    _: AVAudioPlayer,
    successfully _: Bool,
  ) {
    Task { @MainActor in
      self.isCurrentlySpeaking = false
      self.playbackDelegate?.onPlaybackFinished()
      self.cc.ok2(#line, "Playback finished")
    }
  }

  nonisolated func audioPlayerBeginInterruption(_: AVAudioPlayer) {
    Task { @MainActor in
      self.playbackDelegate?.onPlaybackPaused()
      self.cc.ok2(#line, "Playback paused by interruption")
    }
  }

  nonisolated func audioPlayerEndInterruption(
    _: AVAudioPlayer,
    withOptions flags: UInt,
  ) {
    Task { @MainActor in
      #if os(iOS)
        if flags == AVAudioSession.InterruptionOptions.shouldResume.rawValue {
          self.audioPlayer?.play()
          self.playbackDelegate?.onPlaybackContinued()
          self.cc.ok2(#line, "Playback resumed")
        }
      #else
        // On macOS, always resume
        self.audioPlayer?.play()
        self.playbackDelegate?.onPlaybackContinued()
        self.cc.ok2(#line, "Playback resumed")
      #endif
    }
  }
}
