import AVFoundation
import Foundation
import scvCore

// MARK: - AudioEvent

/// Segment events that trigger audio announcements
public enum AudioEvent: Sendable {
  case play
  case pause
  case header
  case section
  case paragraph
  case segment
  case noText
  case endSutta
}

// MARK: - IAudioEffects

/// Protocol abstracting audio effects for dependency injection and testing.
/// Enables segment playback to announce events without coupling to AudioEffects
/// implementation.
@MainActor
public protocol IAudioEffects {
  /// Announce an audio event which triggers appropriate sound effect
  func announce(_ event: AudioEvent)

  /// Announce an audio event asynchronously and wait for sound to finish
  func announceAsync(_ event: AudioEvent) async

  /// Stop any active audio playback and announce pause event
  func cancel()
}

// MARK: - AudioEffects

@MainActor
public final class AudioEffects: NSObject, ObservableObject, IAudioEffects {
  public static let shared = AudioEffects()
  public enum Sound {
    case silent
    case noAudio
    case click
    case bell
    case block
    case swoosh
    case pageTurn
    case chirp

    var filename: String {
      switch self {
      case .silent:
        "SILENT"
      case .noAudio:
        "scv-no-audio"
      case .click:
        "513481__budek__click"
      case .bell:
        "370507__craigmaloney__bell"
      case .chirp:
        "753271__heckfricker__single-chirp"
      case .block:
        "742279__sadiquecat__ashboy34-temple-block-lunarlander-1969"
      case .swoosh:
        "577049__nezuai__cartoon-air-swoosh-6"
      case .pageTurn:
        "383542__alixgaus__turn-page"
      }
    }

    /// Volume bias multiplier for this sound (relative to soundEffectVolume)
    var bias: Float {
      switch self {
      case .click:
        0.5
      case .chirp:
        0.025
      case .block:
        0.5
      default:
        1.0
      }
    }
  } // Sound

  public enum Event {
    case silent
    case pause
    case header
    case section
    case paragraph
    case noText
    case endSutta
  }

  private var audioPlayer: AVAudioPlayer?
  private var soundContinuation: CheckedContinuation<Void, Never>?
  private let cc = ColorConsole(#file, #function, dbg.AudioEffects.other)

  override init() {
    super.init()
    cc.ok2(
      #line,
      #function,
      "AudioEffects initialized with volume: \(Settings.shared.soundEffectVolume)",
    )
  }

  /// Get current sound effect volume from Settings
  public var soundEffectVolume: Float {
    Settings.shared.soundEffectVolume
  }

  /// IAudioEffects protocol: Announce an audio event
  public func announce(_ event: AudioEvent) {
    let internalEvent = audioEventToInternalEvent(event)
    announce(internalEvent)
  }

  /// Internal announce - maps internal Event to sound
  private func announce(_ event: Event) {
    let sound = eventToSound(event)
    playSound(sound: sound, msDelay: 0)
  }

  /// IAudioEffects protocol: Announce event asynchronously and wait for
  /// completion
  public func announceAsync(_ event: AudioEvent) async {
    let internalEvent = audioEventToInternalEvent(event)
    let sound = eventToSound(internalEvent)
    await performPlaySoundAsync(sound)
  }

  /// Play a specific sound with optional delay
  public func playSound(sound: Sound, msDelay: Int = 0) {
    if soundEffectVolume <= 0 { return }

    let delay = Double(msDelay) / 1000.0

    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      self.performPlaySound(sound)
    }
  }

  /// Stop any active audio playback and announce pause event
  public func cancel() {
    audioPlayer?.stop()
    audioPlayer = nil
    announce(AudioEvent.pause)
    cc.ok2(#line, #function, "audio cancelled")
  }

  private func soundUrl(_ sound: Sound) -> URL? {
    if sound == .silent {
      cc.ok1(#line, #function, sound)
      return nil
    }
    if soundEffectVolume <= 0 {
      cc.ok1(#line, #function, sound, "muted")
      return nil
    }
    guard let url = Bundle.module.url(
      forResource: sound.filename,
      withExtension: "mp3",
    ) else {
      cc.bad1(
        #line,
        #function,
        "Could not find audio file: \(sound.filename).mp3",
      )
      return nil
    }

    cc.ok1(#line, #function, url)
    return url
  }

  private func performPlaySound(_ sound: Sound) {
    guard let url = soundUrl(sound) else {
      cc.ok1(#line, #function, sound)
      return
    }

    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.volume = sound.bias * soundEffectVolume
      audioPlayer?.play()
      cc.ok1(#line, #function, sound.filename)
    } catch {
      cc.bad1(#line, #function, error)
    }
  }

  /// Play a sound asynchronously and wait for completion
  private func performPlaySoundAsync(_ sound: Sound) async {
    guard let url = soundUrl(sound) else {
      cc.ok1(#line, #function, sound)
      return
    }

    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.volume = sound.bias * soundEffectVolume
      audioPlayer?.delegate = self
      audioPlayer?.play()
      cc.ok2(#line, #function, sound.filename)

      // Wait for playback to complete via delegate callback
      // Use short timeout (100ms) to prevent continuation leak if delegate
      // never fires
      // The delegate should fire much faster in real scenarios
      await withCheckedContinuation { continuation in
        soundContinuation = continuation

        // Schedule timeout to resume if delegate doesn't fire
        // 100ms is enough time for most audio to start playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          if let cont = self.soundContinuation {
            self.soundContinuation = nil
            cont.resume()
          }
        }
      }

      cc.ok1(#line, #function, sound.filename)
    } catch {
      cc.bad1(#line, #function, error)
    }
  }

  private func audioEventToInternalEvent(_ event: AudioEvent) -> Event {
    switch event {
    case .play, .segment:
      .silent
    case .pause:
      .pause
    case .endSutta:
      .endSutta
    case .noText:
      .noText
    case .header:
      .header
    case .section:
      .section
    case .paragraph:
      .paragraph
    }
  }

  private func eventToSound(_ event: Event) -> Sound {
    switch event {
    case .silent:
      .silent
    case .pause:
      .chirp
    case .endSutta:
      .bell
    case .noText:
      .chirp
    case .header:
      .block
    case .section:
      .pageTurn
    case .paragraph:
      .click
    }
  }
}

// MARK: - AVAudioPlayerDelegate

extension AudioEffects: @preconcurrency AVAudioPlayerDelegate {
  /// Called when audio playback finishes
  public nonisolated func audioPlayerDidFinishPlaying(
    _: AVAudioPlayer,
    successfully _: Bool,
  ) {
    // Resume continuation on main thread (continuation handler is safe to call
    // from any thread)
    MainActor.assumeIsolated {
      if let continuation = soundContinuation {
        soundContinuation = nil
        continuation.resume()
      }
    }
  }

  /// Called on audio decode error
  public nonisolated func audioPlayerDecodeErrorDidOccur(
    _: AVAudioPlayer,
    error: Error?,
  ) {
    MainActor.assumeIsolated {
      let cc = ColorConsole(#file, #function, dbg.AudioEffects.other)
      if let error {
        cc.bad1(#line, #function, error)
      } else {
        cc.bad1(#line, #function, "Audio decode error: unknown")
      }
      // Signal continuation anyway so caller isn't stuck waiting
      if let continuation = soundContinuation {
        soundContinuation = nil
        continuation.resume()
      }
    }
  }
}
