import Foundation

// Application-wide singleton with ColorConsole verbosity levels:
//   2: verbose
//   1: terse
//   0: silent
public struct dbg: Sendable {
  // Verbosity Levels
  static let VERBOSE: Int = 2
  static let TERSE: Int = 1
  static let NONE: Int = 0

  // Functional areas
  static let SYNTH_WRITE: Int = 2 // AVSpeechSynthesizer.write(), AudioStore
  static let SYNTH_SPEAK: Int = 2 // AVSpeechSynthesizer.speak()
  static let SYNTH: Int = max(SYNTH_WRITE, SYNTH_SPEAK)
  static let LAUNCH: Int = VERBOSE
  static let LOAD: Int = VERBOSE
  static let PLAYER: Int = 0
  static let EBT_DATA: Int = 2
  static let BUILD: Int = 0
  static let TAP: Int = 2

  public struct AboutCardView: Sendable {
    public static let other: Int = NONE
  }

  public struct App: Sendable {
    public static let other: Int = LAUNCH
  }

  public struct AppController: Sendable {
    public static let other: Int = LAUNCH
  }

  public struct AppRootView: Sendable {
    public static let other: Int = LAUNCH
  }

  public struct AudioContext: Sendable {
    public static let other: Int = SYNTH
  }

  public struct AudioEffects: Sendable {
    public static let other: Int = PLAYER
  }

  public struct AudioStore: Sendable {
    public static let other: Int = SYNTH
  }

  public struct AudioSynthesisSession: Sendable {
    public static let other: Int = SYNTH
  }

  public struct AutoComplete: Sendable {
    public static let other: Int = NONE
  }

  public struct AVAdapter: Sendable {
    public static let other: Int = NONE
  }

  public struct BackgroundPlayer: Sendable {
    public static let other: Int = PLAYER
  }

  public struct BackgroundPlayerView: Sendable {
    public static let other: Int = PLAYER
  }

  public struct CachedSynthesizer: Sendable {
    public static let other: Int = SYNTH
  }

  public struct CardManager: Sendable {
    public static let other: Int = NONE
  }

  public struct CardSidebarView: Sendable {
    public static let other: Int = NONE
  }

  public struct ContentView: Sendable {
    public static let other: Int = NONE
  }

  public struct EbtData: Sendable {
    public static let other: Int = EBT_DATA
    public static let segmentsOfSuttaRef: Int = EBT_DATA
    public static let load: Int = LOAD
  }

  public struct EbtDBBuilder: Sendable {
    public static let other: Int = BUILD
  }

  public struct EbtQuery: Sendable {
    public static let other: Int = EBT_DATA
  }

  public struct EbtSeeker: Sendable {
    public static let other: Int = EBT_DATA
    public static let search: Int = EBT_DATA
  }

  public struct IOSView: Sendable {
    public static let other: Int = NONE
  }

  public struct Lemmatizer: Sendable {
    public static let other: Int = NONE
  }

  public struct OpenURL: Sendable {
    public static let other: Int = NONE
  }

  public struct SCVApp: Sendable {
    public static let other: Int = NONE
  }

  public struct SearchCardView: Sendable {
    public static let other: Int = NONE
  }

  public struct SegmentLayout: Sendable {
    public static let other: Int = NONE
  }

  public struct SegmentPlaybackIterator: Sendable {
    public static let other: Int = PLAYER
  }

  public struct SegmentView: Sendable {
    public static let other: Int = NONE
  }

  public struct Settings: Sendable {
    public static let other: Int = TERSE
  }

  public struct Shortcut: Sendable {
    public static let search: Int = NONE
  }

  public struct SpeechSynthesizer: Sendable {
    public static let other: Int = SYNTH_SPEAK
  }

  public struct SuttaPlayer: Sendable {
    public static let other: Int = max(SYNTH, PLAYER)
  }

  public struct SuttaCardView: Sendable {
    public static let other: Int = TERSE
    public static let player: Int = PLAYER
  }

  public struct SuttaRef: Sendable {
    public static let other: Int = NONE
  }

  public struct Tipitaka: Sendable {
    public static let other: Int = NONE
  }

  public struct TipitakaView: Sendable {
    public static let other: Int = NONE
  }

  public struct ZStd: Sendable {
    public static let other: Int = NONE
  }

  public struct scvUITests: Sendable {
    public static let other: Int = NONE
  }
}

/// Get project root directory.
///
/// Computes project root by splitting this file's path at "/scv-core/"
/// and taking the first part.
///
/// - Returns: URL to project root directory
public func projectRoot() -> URL {
  let currentFile = #file
  if let range = currentFile.range(of: "/scv-core/") {
    let rootPath = String(currentFile[..<range.lowerBound])
    return URL(fileURLWithPath: rootPath)
  }
  // Fallback: traverse up to find scv-app directory
  var current = URL(fileURLWithPath: currentFile).deletingLastPathComponent()
  while current.path != "/" {
    if current.lastPathComponent == "scv-app" {
      return current
    }
    current = current.deletingLastPathComponent()
  }
  return current
}

public func fileLineId(filename: String, line: Int) -> String {
  let fileURL = URL(fileURLWithPath: filename)
  let fname = fileURL.lastPathComponent.hasSuffix(".swift")
    ? String(fileURL.lastPathComponent.dropLast(6))
    : fileURL.lastPathComponent
  let first = fname.first.map(String.init) ?? "?"
  let last = fname.last.map(String.init) ?? "?"
  let count2 = "\(fname.count - 2)"
  let short = first + count2 + last
  return "\(short):\(line)"
}
