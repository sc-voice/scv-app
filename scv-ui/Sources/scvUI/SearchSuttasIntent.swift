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

  public func perform() async throws -> some IntentResult {
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

    // Store search results and metadata for app to display
    let intentResults = SearchIntentResults(
      query: query ?? "",
      language: "en",
      author: "sujato",
      results: strippedResults,
    )
    if let encoded = try? JSONEncoder().encode(intentResults) {
      // Use app groups for inter-process communication between app and App
      // Intent
      if let defaults = UserDefaults(suiteName: "group.sc-voice.scv-app") {
        defaults.set(encoded, forKey: "SearchSuttasIntentResults")
        print(
          "DEBUG SearchSuttasIntent: Stored \(strippedResults.count) results for query '\(query ?? "")'",
        )
      } else {
        // Fallback to standard UserDefaults if app groups not available
        UserDefaults.standard.set(encoded, forKey: "SearchSuttasIntentResults")
        print(
          "DEBUG SearchSuttasIntent: App groups unavailable, using standard UserDefaults",
        )
      }
    } else {
      print("DEBUG SearchSuttasIntent: Failed to encode results")
    }

    DispatchQueue.main.async {
      print("DEBUG \(query ?? "") found in \(results.count) suttas")
    }

    return .result()
  }
}
