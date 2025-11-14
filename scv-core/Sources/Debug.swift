// Application-wide singleton that provides verbosity levels for invocation of
// ColorConsole
// methods.
public struct Debug: Sendable {
  public static let shared = Debug()

  public struct Shortcut: Sendable {
    public static let search: Int = 0
  }
}

public let dbg = Debug.shared
