import Foundation

/// A codable request object for passing search parameters between app intents and UI
public struct SearchIntentRequest: Codable {
  public let query: String
  public let language: String
  public let author: String

  public init(query: String, language: String, author: String) {
    self.query = query ?? "WHATQUERY"
    self.language = language ?? "WHATLANG"
    self.author = author ?? "WHATAUTHOR"
  }
}
