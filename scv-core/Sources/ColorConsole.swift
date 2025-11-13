import Foundation

/// ColorConsole produces colored messages to Xcode console using ANSI escape
/// codes
public final class ColorConsole: Sendable {
  // ANSI escape codes
  private static let reset = "\u{001B}[0m"
  private static let brightGreen = "\u{001B}[92m"
  private static let brightRed = "\u{001B}[91m"

  private let sourceFile: String
  private let sourceMethod: String

  public init(path: String = #file, method: String = #function) {
    sourceFile = URL(fileURLWithPath: path).deletingPathExtension()
      .lastPathComponent
    sourceMethod = method
  }

  /// Return string with ANSI color codes applied (variadic)
  public func colorString(_ color: String, _ messages: Any...) -> String {
    let output = messages.map { String(describing: $0) }.joined(separator: " ")
    return "\(color)\(output)\(Self.reset)"
  }

  /// Print bright green text (variadic) and return colored string
  public func ok1(_ messages: Any...) -> String {
    let result = colorString("✅", sourceFile, sourceMethod, messages)
    print(result)
    return result
  }

  /// Print bright red text (variadic) and return colored string
  public func bad1(_ messages: Any...) -> String {
    let result = colorString("❌", sourceFile, sourceMethod, messages)
    print(result)
    return result
  }
}

/// Global singleton instance
public let cc = ColorConsole()
