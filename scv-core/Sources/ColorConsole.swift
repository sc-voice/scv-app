import Foundation

/// ColorConsole produces colored messages to Xcode console using ANSI escape
/// codes
public final class ColorConsole: Sendable {
  private let sourceFile: String
  private let sourceMethod: String
  private let verbosity: Int
  private let context: String

  /// Initialize ColorConsole
  /// - Parameters:
  ///   - path: Source file path (default: #file)
  ///   - method: Source method name (default: #function)
  ///   - verbosity: Verbosity level (0=silent, 1=minimal, 2=verbose, default:
  /// 1)
  public init(
    _ path: String = #file,
    _ method: String = #function,
    _ verbosity: Int = 1,
  ) {
    sourceFile = URL(fileURLWithPath: path).deletingPathExtension()
      .lastPathComponent
    sourceMethod = method.components(separatedBy: "(").first ?? method
    self.verbosity = verbosity
    context = sourceFile == sourceMethod
      ? sourceFile + "::"
      : sourceFile + ":" + sourceMethod + ":"
  }

  /// Return formatted string from array of messages
  public func formatString(_ messages: [Any]) -> String {
    messages.map { String(describing: $0) }.joined(separator: " ")
  }

  /// Print bright green text and return colored string or nil based on
  /// verbosity
  /// - Returns: Colored result string if verbosity >= 1, nil if verbosity < 1
  @discardableResult
  public func ok1(_ messages: Any...) -> String? {
    if verbosity < 1 {
      return nil
    }
    let messageStr = formatString(messages)
    let result = "✅" + context + messageStr
    print(result)
    return result
  }

  /// Print bright red text and return colored string or nil based on verbosity
  /// - Returns: Colored result string if verbosity >= 1, nil if verbosity < 1
  @discardableResult
  public func bad1(_ messages: Any...) -> String? {
    if verbosity < 1 {
      return nil
    }
    let messageStr = formatString(messages)
    let result = "❌" + context + messageStr
    print(result)
    return result
  }

  /// Print checkmark text indented and return colored string or nil based on
  /// verbosity
  /// - Returns: Colored result string if verbosity >= 2, nil if verbosity < 2
  @discardableResult
  public func ok2(_ messages: Any...) -> String? {
    if verbosity < 2 {
      return nil
    }
    let messageStr = formatString(messages)
    let result = "↓🍀" + context + messageStr
    print(result)
    return result
  }

  /// Print X mark text indented and return colored string or nil based on
  /// verbosity
  /// - Returns: Colored result string if verbosity >= 2, nil if verbosity < 2
  @discardableResult
  public func bad2(_ messages: Any...) -> String? {
    if verbosity < 2 {
      return nil
    }
    let messageStr = formatString(messages)
    let result = "↓🌶️" + context + messageStr
    print(result)
    return result
  }
}

/// Global singleton instance
public let cc = ColorConsole()
