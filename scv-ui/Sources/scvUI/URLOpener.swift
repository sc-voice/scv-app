import Foundation

/// Protocol for opening URLs with platform-specific implementations
public protocol URLOpener {
  /// Opens a URL with optional completion handler
  /// - Parameters:
  ///   - url: The URL to open
  ///   - completion: Callback indicating success (true) or failure (false)
  func open(_ url: URL, completion: @escaping @MainActor (Bool) -> Void)
}

#if os(iOS)
  import UIKit

  /// iOS implementation using UIApplication
  public class iOSURLOpener: URLOpener {
    public init() {}

    public func open(
      _ url: URL,
      completion: @escaping @MainActor (Bool) -> Void,
    ) {
      UIApplication.shared.open(url) { success in
        completion(success)
      }
    }
  }
#else
  import AppKit

  /// macOS implementation using NSWorkspace
  public class macOSURLOpener: URLOpener {
    public init() {}

    public func open(
      _ url: URL,
      completion: @escaping @MainActor (Bool) -> Void,
    ) {
      let success = NSWorkspace.shared.open(url)
      Task { @MainActor in
        completion(success)
      }
    }
  }
#endif
