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

  public func perform() async throws -> some IntentResult & ProvidesDialog {
    let settings = Settings.shared
    let language = settings.docLang.code
    if query == nil {
      query = try await $query.requestValue(
        .init(stringLiteral: "What are you searching for?"),
      )
    }

    normalizeQuery()
    let results = await EbtData.shared.searchPhrase(
      lang: "en",
      author: "sujato",
      phrase: query ?? "",
    )

    let strippedResults = results.map { result in
      result.replacingOccurrences(of: "en/sujato/", with: "")
    }
    let resultsList = strippedResults.joined(separator: ", ")

    // Store sutta keys in UserDefaults for UIApp to retrieve
    if let encoded = try? JSONEncoder().encode(results) {
      UserDefaults.standard.set(encoded, forKey: "SearchSuttasIntentResults")
    }

    return .result(
      dialog: .init(
        "\(query ?? "") found in \(results.count) suttas: \(resultsList)",
      ),
    )
  }
}
