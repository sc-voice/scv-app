import Foundation

/// A codable request object for passing search parameters between app intents
/// and UI
public struct SearchIntentRequest: Codable {
  public let query: String
  public let language: String
  public let author: String

  public init(query: String, language: String, author: String) {
    self.query = query
    self.language = language
    self.author = author
  }
}

/// Results from SearchSuttasIntent to be displayed in the app
public struct SearchIntentResults: Codable {
  public let query: String
  public let language: String
  public let author: String
  public let results: [String]

  public init(
    query: String,
    language: String,
    author: String,
    results: [String],
  ) {
    self.query = query
    self.language = language
    self.author = author
    self.results = results
  }
}
