import AVFoundation
import Foundation
import scvCore

@MainActor
public final class AudioEffects: ObservableObject {
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

  /// Announce an event which triggers appropriate sound
  public func announce(_ event: Event) {
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
    } catch {
      cc.bad1(#line, "Failed to play audio \(sound.filename): \(error)")
    }
  }

  private func eventToSound(_ event: Event) -> Sound {
    switch event {
    case .play:
      .block
    case .pause:
      .block
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
