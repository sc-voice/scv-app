import Foundation

// Application-wide singleton that provides verbosity levels for invocation of
// ColorConsole methods.
public struct dbg: Sendable {
  static let SYNTH_WRITE: Int = 0 // AVSpeechSynthesizer.write(), AudioStore
  static let SYNTH_SPEAK: Int = 0 // AVSpeechSynthesizer.speak()
  static let SYNTH: Int = max(SYNTH_WRITE, SYNTH_SPEAK)
  static let LAUNCH: Int = 0
  static let PLAYER: Int = 0
  static let EBT_DATA: Int = 0
  static let SPECIAL: Int = 0

  public struct AboutCardView: Sendable {
    public static let other: Int = 0
  }

  public struct App: Sendable {
    public static let other: Int = max(0, LAUNCH)
  }

  public struct AppController: Sendable {
    public static let other: Int = LAUNCH
  }

  public struct AppRootView: Sendable {
    public static let other: Int = LAUNCH
  }

  public struct AudioContext: Sendable {
    public static let other: Int = SYNTH_WRITE
  }

  public struct AudioEffects: Sendable {
    public static let other: Int = max(0, PLAYER)
  }

  public struct AudioStore: Sendable {
    public static let other: Int = max(0, SYNTH)
  }

  public struct AudioSynthesisSession: Sendable {
    public static let other: Int = max(0, SYNTH)
  }

  public struct AutoComplete: Sendable {
    public static let other: Int = 0
  }

  public struct AVAdapter: Sendable {
    public static let other: Int = 0
  }

  public struct BackgroundPlayer: Sendable {
    public static let other: Int = max(0, PLAYER)
  }

  public struct BackgroundPlayerView: Sendable {
    public static let other: Int = max(0, PLAYER)
  }

  public struct CachedSynthesizer: Sendable {
    public static let other: Int = max(0, SYNTH)
  }

  public struct CardManager: Sendable {
    public static let other: Int = 0
  }

  public struct CardSidebarView: Sendable {
    public static let other: Int = 0
  }

  public struct ContentView: Sendable {
    public static let other: Int = 0
  }

  public struct EbtData: Sendable {
    public static let other: Int = EBT_DATA
    public static let segmentsOfSuttaRef: Int = max(1,EBT_DATA)
  }

  public struct EbtDBBuilder: Sendable {
    public static let other: Int = 2
  }

  public struct EbtQuery: Sendable {
    public static let other: Int = EBT_DATA
  }

  public struct EbtSeeker: Sendable {
    public static let other: Int = EBT_DATA
    public static let search: Int = EBT_DATA
  }

  public struct IOSView: Sendable {
    public static let other: Int = 0
  }

  public struct Lemmatizer: Sendable {
    public static let other: Int = 0
  }

  public struct OpenURL: Sendable {
    public static let other: Int = 0
  }

  public struct SCVApp: Sendable {
    public static let other: Int = 0
  }

  public struct SearchCardView: Sendable {
    public static let other: Int = 0
  }

  public struct SegmentLayout: Sendable {
    public static let other: Int = 0
  }

  public struct SegmentPlaybackIterator: Sendable {
    public static let other: Int = max(0, PLAYER)
  }

  public struct SegmentView: Sendable {
    public static let other: Int = 0
  }

  public struct Settings: Sendable {
    public static let other: Int = 0
  }

  public struct Shortcut: Sendable {
    public static let search: Int = 0
  }

  public struct SpeechSynthesizer: Sendable {
    public static let other: Int = max(0, SYNTH_SPEAK)
  }

  public struct SuttaPlayer: Sendable {
    public static let other: Int = max(SYNTH, PLAYER)
  }

  public struct SuttaCardView: Sendable {
    public static let other: Int = 0
    public static let player: Int = PLAYER
  }

  public struct SuttaRef: Sendable {
    public static let other: Int = 0
  }

  public struct Tipitaka: Sendable {
    public static let other: Int = 0
  }

  public struct TipitakaView: Sendable {
    public static let other: Int = 0
  }

  public struct ZStd: Sendable {
    public static let other: Int = 0
  }

  public struct scvUITests: Sendable {
    public static let other: Int = 0
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
