import Foundation

/// ColorConsole produces colored messages to Xcode console
///
/// ## Logging Best Practice
///
/// - `ok1(#line, #function, message)`: Final log before normal method return.
///   Example:
///   ```
///     cc.ok1(#line, #function, card.name)
///   }
///   ```
///
/// - `ok2(#line, #function, message)`: Intermediate logging on normal paths.
///   Example: `cc.ok2(#line, #function, "compare:", compare)`
///
/// - `bad1(#line, #function, message)`: Final log before unexpected method
/// return
///   Example:
///   ```
///     cc.bad1(#line, #function, errorMsg)
///     throw errorMsg
///   ```
///
/// - `bad2(#line, #function, message)`: Intermediate log on unexpected path
///   Example: `cc.bad2(#line, #function, "handle unexpected case")`
///
/// Logging statements should be a single line of <80 characters.
/// If you need more, use intermediate message declarations to reduce line
/// length.
///
public final class ColorConsole: Sendable {
  private let sourceFile: String
  private let sourceMethod: String
  private let verbosity: Int
  private let context: String

  // Thread-safe timestamp tracking
  private static let timestampLock = NSLock()
  /// appLaunchTime: Written once in init(), never modified after. Safe via
  /// NSLock.
  /// See: doc/ColorConsole.md#thread-safety
  private nonisolated(unsafe) static var appLaunchTime: Date = .init()
  /// lastOutputTime: Only updated inside NSLock in getElapsedTimeAndUpdate().
  /// See: doc/ColorConsole.md#thread-safety
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

    // Initialize app launch time on first ColorConsole creation
    ColorConsole.timestampLock.lock()
    if ColorConsole.appLaunchTime.timeIntervalSince1970 == 0 {
      ColorConsole.appLaunchTime = Date()
      ColorConsole.lastOutputTime = ColorConsole.appLaunchTime
    }
    ColorConsole.timestampLock.unlock()
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
    let sinceLaunch = now.timeIntervalSince(ColorConsole.appLaunchTime)
    let sinceLastOutput = now.timeIntervalSince(ColorConsole.lastOutputTime)
    ColorConsole.lastOutputTime = now

    return String(format: "%0.3fs+%0.3f", sinceLaunch, sinceLastOutput)
  }

  /// Log successful completion of method (bright green)
  /// Caller must call with cc.ok1(#line, #function, ...)
  /// Returns testable logged output
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

  /// Log failed completion of method (bright red)
  /// Caller must call with cc.bad1(#line, #function, ...)
  /// Returns testable logged output
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

  /// Secondary logging on normal path prior to method return (green)
  /// Caller must call with cc.ok2(#line, #function, ...)
  /// Returns testable logged output
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

  /// Secondary logging on failure path prior to method return (red)
  /// Caller must call with cc.bad2(#line, #function, ...)
  /// Returns testable logged output
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
