// Application-wide singleton that provides verbosity levels for invocation of
// ColorConsole methods.
public struct dbg: Sendable {
  public struct AppController: Sendable {
    public static let other: Int = 2
  }

  public struct AppRootView: Sendable {
    public static let other: Int = 2
  }

  public struct ContentView: Sendable {
    public static let other: Int = 2
  }

  public struct DemoIOSApp: Sendable {
    public static let other: Int = 2
  }

  public struct OpenURL: Sendable {
    public static let other: Int = 2
  }

  public struct Shortcut: Sendable {
    public static let search: Int = 0
  }

  public struct SQLite: Sendable {
    public static let zstd: Int = 2
  }

  public struct SuttaPlayer: Sendable {
    public static let other: Int = 2
  }

  public struct scvUITests: Sendable {
    public static let other: Int = 2
  }
}
