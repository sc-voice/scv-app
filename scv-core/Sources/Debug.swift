import Foundation

// Application-wide singleton that provides verbosity levels for invocation of
// ColorConsole methods.
public struct dbg: Sendable {
  static let AUDIO: Int = 0
  static let SYNTH: Int = 2

  public struct AboutCardView: Sendable {
    public static let other: Int = 0
  }

  public struct App: Sendable {
    public static let other: Int = 2
  }

  public struct AppController: Sendable {
    public static let other: Int = 2
  }

  public struct AppRootView: Sendable {
    public static let other: Int = 0
  }

  public struct AudioContext: Sendable {
    public static let other: Int = AUDIO
  }

  public struct AudioEffects: Sendable {
    public static let other: Int = AUDIO
  }

  public struct AudioStore: Sendable {
    public static let other: Int = max(SYNTH, AUDIO)
  }

  public struct AudioSynthesisSession: Sendable {
    public static let other: Int = max(SYNTH, AUDIO)
  }

  public struct AutoComplete: Sendable {
    public static let other: Int = 0
  }

  public struct CachedSynthesizer: Sendable {
    public static let other: Int = max(SYNTH, AUDIO)
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
    public static let other: Int = 2
  }

  public struct EbtDBBuilder: Sendable {
    public static let other: Int = 2
  }

  public struct EbtQuery: Sendable {
    public static let other: Int = 0
  }

  public struct EbtSeeker: Sendable {
    public static let other: Int = 2
    public static let search: Int = 0
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

  public struct SegmentView: Sendable {
    public static let other: Int = 0
  }

  public struct Settings: Sendable {
    public static let other: Int = 0
  }

  public struct Shortcut: Sendable {
    public static let search: Int = 0
  }

  public struct SuttaPlayer: Sendable {
    public static let other: Int = AUDIO
  }

  public struct SuttaCardView: Sendable {
    public static let other: Int = 0
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
