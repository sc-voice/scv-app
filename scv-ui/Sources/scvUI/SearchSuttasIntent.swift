import AppIntents
import Foundation
import scvCore

/// AppIntent that accepts a search query and performs a search in SC-Voice
/// Uses Settings for language and author configuration
/// Displays a confirmation dialog before executing the search
@available(iOS 16.0, macOS 13.0, *)
public struct SearchSuttasIntent: AppIntent {
  public nonisolated(unsafe) static var title: LocalizedStringResource = "Search Voice Suttas"
  public nonisolated(unsafe) static var description: LocalizedStringResource = "Search Early Buddhist Texts"
  public nonisolated(unsafe) static var openAppWhenRun: Bool = true
  @Parameter(title: "Search for", description: "What to search for")
  public var query: String?

  let cc = ColorConsole(#file, #function, dbg.Shortcut.search)

  public init() {}

  public init(query: String) {
    self.query = query
  }

  func normalizeQuery() {
    query = query?.lowercased()
    if query == "route of suffering" {
      query = "root of suffering"
    }
  }

  public func perform() async throws -> some IntentResult {
    if query == nil {
      query = try await $query.requestValue(
        .init(stringLiteral: "What are you searching for?"),
      )
      cc.ok2(#line, "query:", query ?? "")
    }

    normalizeQuery()
    cc.ok2(#line, "normalized:", query ?? "")

    // Invoke app via URL scheme to display search results
    await MainActor.run {
      AppController.shared.searchByUrl(query: query ?? "")
    }
    cc.ok1(#line, #function, query ?? "")

    return .result()
  }
}
