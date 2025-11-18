import Foundation

/// ColorConsole produces colored messages to Xcode console using ANSI escape
/// codes
///
/// ## Logging Best Practice
///
/// - `ok1(#line, message)`: Exactly once per valid code path. Provides 1-line
///   summary of successful outcome. Example: `cc.ok1(#line, "Selected card:",
///   card.name)`
///
/// - `ok2(#line, message)`: Document entry into code blocks and intermediate
///   steps. Added as needed for diagnostic debugging. Example:
///   `cc.ok2(#line, "conditional branch taken:", condition)`
///
/// - `bad1(#line, message)`: Used prior to exiting any method with unexpected
///   result (throw error or invalid argument). Shares error message that will
///   be thrown/returned. Example:
///   ```
///   let errorMsg = "Failed to decode results"
///   cc.bad1(#line, errorMsg)
///   throw MyError.decodeFailed(errorMsg)
///   ```
///
/// - `bad2(#line, message)`: Reserved for additional diagnostic information
///   during error diagnosis/handling or non-fatal errors. Example:
///   `cc.bad2(#line, "Fallback attempted:", fallbackValue)`
///
public final class ColorConsole: Sendable {
  private let sourceFile: String
  private let sourceMethod: String
  private let verbosity: Int
  private let context: String

  // Thread-safe timestamp tracking
  private static let timestampLock = NSLock()
  private nonisolated(unsafe) static var lastOutputTime: Date = .init()

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

  /// Get elapsed time since last output and update timestamp
  private func getElapsedTimeAndUpdate() -> String {
    ColorConsole.timestampLock.lock()
    defer { ColorConsole.timestampLock.unlock() }

    let now = Date()
    let elapsed = now.timeIntervalSince(ColorConsole.lastOutputTime)
    ColorConsole.lastOutputTime = now

    let elapsedMs = Int(elapsed * 1000)
    let elapsedSecs = Double(elapsedMs) / 1000.0
    return String(format: "+%.3fs", elapsedSecs)
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
    let elapsed = getElapsedTimeAndUpdate()
    let result = "✅" + context + elapsed + " " + messageStr
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
    let elapsed = getElapsedTimeAndUpdate()
    let result = "❌" + context + elapsed + " " + messageStr
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
    let elapsed = getElapsedTimeAndUpdate()
    let result = "↓🍀" + context + elapsed + " " + messageStr
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
    let elapsed = getElapsedTimeAndUpdate()
    let result = "↓🌶️" + context + elapsed + " " + messageStr
    print(result)
    return result
  }
}

/// Global singleton instance
public let cc = ColorConsole()
