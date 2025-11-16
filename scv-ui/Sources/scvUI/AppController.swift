import Foundation

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Current app build version from Info.plist CFBundleVersion
public let appVersion = Bundle.main
  .infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

/// Singleton controller for app-level operations including URL invocation
@MainActor
public class AppController {
  let cc = ColorConsole(#file, #function, dbg.AppController.other)
  public static let shared = AppController()

  private let urlOpener: URLOpener

  /// Initialize AppController for platform
  public init(urlOpener: URLOpener? = nil) {
    if let urlOpener {
      self.urlOpener = urlOpener
    } else {
      #if os(iOS)
        self.urlOpener = iOSURLOpener()
      #else
        self.urlOpener = macOSURLOpener()
      #endif
    }
  }

  /// Perform common app launch initialization
  public func initialize() {
    cc.ok1(#line, "build:", appVersion)
  }

  /// Extract search query from incoming sc-voice:// URL
  /// - Parameter url: The URL to extract query from
  /// - Returns: The search query from the 'q' parameter, or nil if not found
  public func extractSearchQuery(from url: URL) -> String? {
    guard let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: true,
    ),
      let queryItems = components.queryItems
    else { return nil }
    return queryItems.first(where: { $0.name == "q" })?.value
  }

  /// Handle incoming sc-voice:// URL and perform search
  /// - Parameter url: The incoming URL to handle
  public func handleSearchUrl(url: URL) {
    guard let query = extractSearchQuery(from: url) else {
      showError("Invalid URL or missing q parameter")
      return
    }
    performSearch(query: query)
  }

  /// Search by invoking SC-Voice URL scheme with query parameter
  /// - Parameter query: The search query to pass to SC-Voice
  public func searchByUrl(query: String) {
    guard var components = URLComponents(string: "sc-voice://search") else {
      showError("Failed to construct SC-Voice URL")
      return
    }

    components.queryItems = [URLQueryItem(name: "q", value: query)]

    guard let url = components.url else {
      showError("Failed to create valid SC-Voice URL")
      return
    }

    urlOpener.open(url) { [weak self] success in
      if !success {
        self?
          .showError(
            "Failed to open SC-Voice. Make sure SC-Voice is installed.",
          )
      }
    }
  }

  /// Perform search with given query
  /// - Parameter query: The search query to execute
  private func performSearch(query _: String) {
    // TODO: Implement actual search functionality
    // This will integrate with SearchSuttasIntent or EbtData
  }

  private func showError(_ message: String) {
    #if os(iOS)
      let alert = UIAlertController(
        title: "Error",
        message: message,
        preferredStyle: .alert,
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))

      if let windowScene = UIApplication.shared.connectedScenes
        .first as? UIWindowScene,
        let window = windowScene.windows.first,
        let rootViewController = window.rootViewController
      {
        rootViewController.present(alert, animated: true)
      }
    #else
      let alert = NSAlert()
      alert.messageText = "Error"
      alert.informativeText = message
      alert.alertStyle = .warning
      alert.addButton(withTitle: "OK")
      alert.runModal()
    #endif
  }
}
