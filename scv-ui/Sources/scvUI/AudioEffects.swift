import AVFoundation
import Foundation
import scvCore

// MARK: - AudioEvent

/// Segment events that trigger audio announcements
public enum AudioEvent: Sendable {
  case play
  case pause
  case endSutta
  case noText
  case section
  case segment
}

// MARK: - IAudioEffects

/// Protocol abstracting audio effects for dependency injection and testing.
/// Enables segment playback to announce events without coupling to AudioEffects
/// implementation.
@MainActor
public protocol IAudioEffects: Sendable {
  /// Announce an audio event which triggers appropriate sound effect
  func announce(_ event: AudioEvent)

  /// Stop any active audio playback and announce pause event
  func cancel()
}

// MARK: - AudioEffects

@MainActor
public final class AudioEffects: ObservableObject, IAudioEffects {
  public static let shared = AudioEffects()
  public enum Sound {
    case silent
    case click
    case bell
    case block
    case swoosh
    case pageTurn
    case chirp

    var filename: String {
      switch self {
      case .silent:
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
  }

  public enum Event {
    case play
    case pause
    case endSutta
    case noText
    case section
    case segment
  }

  private var audioPlayer: AVAudioPlayer?
  private let cc = ColorConsole(#file, #function, dbg.AudioEffects.other)

  init() {
    cc.ok2(
      #line,
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

  /// Play a specific sound with optional delay
  public func playSound(sound: Sound, msDelay: Int = 0) {
    // Muted when volume is 0
    guard soundEffectVolume > 0 else { return }

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
    cc.ok2(#line, "audio cancelled")
  }

  private func performPlaySound(_ sound: Sound) {
    guard let url = Bundle.module.url(
      forResource: sound.filename,
      withExtension: "mp3",
    ) else {
      cc.bad1(#line, "Could not find audio file: \(sound.filename).mp3")
      return
    }

    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.volume = sound.bias * soundEffectVolume
      audioPlayer?.play()
      cc.ok1(#line, #function, sound.filename)
    } catch {
      cc.bad1(#line, "Failed to play audio \(sound.filename): \(error)")
    }
  }

  private func audioEventToInternalEvent(_ event: AudioEvent) -> Event {
    switch event {
    case .play:
      .play
    case .pause:
      .pause
    case .endSutta:
      .endSutta
    case .noText:
      .noText
    case .section:
      .section
    case .segment:
      .segment
    }
  }

  private func eventToSound(_ event: Event) -> Sound {
    switch event {
    case .play:
      .block
    case .pause:
      .chirp
    case .endSutta:
      .bell
    case .noText:
      .chirp
    case .section:
      .pageTurn
    case .segment:
      .click
    }
  }
}
