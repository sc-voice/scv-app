// Application-wide singleton that provides verbosity levels for invocation of
// ColorConsole
// methods.
public struct dbg: Sendable {
  public struct Shortcut: Sendable {
    public static let search: Int = 0
  }

  public struct SQLite: Sendable {
    public static let zstd: Int = 2
  }
}
