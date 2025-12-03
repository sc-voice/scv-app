//
//  SearchResponse.swift
//  SC-Voice
//
//  Created by Visakha on 22/10/2025.
//

import Foundation

// MARK: - Codable Defaults

private let NIL_STRING_DEFAULT = ""
private let NIL_INT_DEFAULT = 0
private let NIL_DOUBLE_DEFAULT = 0.0
private let NIL_BOOL_DEFAULT = false

// MARK: - Main Search Response

public struct SearchResponse: Codable, Equatable {
  public let author: String
  public let lang: String
  public let searchLang: String
  public let minLang: Int
  public let maxDoc: Int
  public let maxResults: Int
  public let pattern: String
  public let method: String
  public let resultPattern: String
  public let segsMatched: Int
  public let bilaraPaths: [String]
  public let suttaRefs: [String]
  public let mlDocs: [MLDocument]

  // Error handling fields
  public let searchError: SearchErrorInfo?
  public let searchSuggestion: String

  // Computed properties
  var isSuccess: Bool { searchError == nil }

  // Custom initializer with defaults
  init(
    author: String = NIL_STRING_DEFAULT,
    lang: String = NIL_STRING_DEFAULT,
    searchLang: String = NIL_STRING_DEFAULT,
    minLang: Int = NIL_INT_DEFAULT,
    maxDoc: Int = NIL_INT_DEFAULT,
    maxResults: Int = NIL_INT_DEFAULT,
    pattern: String = NIL_STRING_DEFAULT,
    method: String = NIL_STRING_DEFAULT,
    resultPattern: String = NIL_STRING_DEFAULT,
    segsMatched: Int = NIL_INT_DEFAULT,
    bilaraPaths: [String] = [],
    suttaRefs: [String] = [],
    mlDocs: [MLDocument] = [],
    searchError: SearchErrorInfo? = nil,
    searchSuggestion: String = NIL_STRING_DEFAULT,
  ) {
    self.author = author
    self.lang = lang
    self.searchLang = searchLang
    self.minLang = minLang
    self.maxDoc = maxDoc
    self.maxResults = maxResults
    self.pattern = pattern
    self.method = method
    self.resultPattern = resultPattern
    self.segsMatched = segsMatched
    self.bilaraPaths = bilaraPaths
    self.suttaRefs = suttaRefs
    self.mlDocs = mlDocs
    self.searchError = searchError
    self.searchSuggestion = searchSuggestion
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case author, lang, searchLang, minLang, maxDoc, maxResults
    case pattern, method, resultPattern, segsMatched
    case bilaraPaths, suttaRefs, mlDocs
    case searchError, searchSuggestion
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let author = try container
      .decodeIfPresent(String.self, forKey: .author) ?? NIL_STRING_DEFAULT
    let lang = try container
      .decodeIfPresent(String.self, forKey: .lang) ?? NIL_STRING_DEFAULT
    let searchLang = try container.decodeIfPresent(
      String.self,
      forKey: .searchLang,
    ) ?? NIL_STRING_DEFAULT
    let minLang = try container
      .decodeIfPresent(Int.self, forKey: .minLang) ?? NIL_INT_DEFAULT
    let maxDoc = try container
      .decodeIfPresent(Int.self, forKey: .maxDoc) ?? NIL_INT_DEFAULT
    let maxResults = try container.decodeIfPresent(
      Int.self,
      forKey: .maxResults,
    ) ?? NIL_INT_DEFAULT
    let pattern = try container
      .decodeIfPresent(String.self, forKey: .pattern) ?? NIL_STRING_DEFAULT
    let method = try container
      .decodeIfPresent(String.self, forKey: .method) ?? NIL_STRING_DEFAULT
    let resultPattern = try container.decodeIfPresent(
      String.self,
      forKey: .resultPattern,
    ) ?? NIL_STRING_DEFAULT
    let segsMatched = try container.decodeIfPresent(
      Int.self,
      forKey: .segsMatched,
    ) ?? NIL_INT_DEFAULT
    let bilaraPaths = try container.decodeIfPresent(
      [String].self,
      forKey: .bilaraPaths,
    ) ?? []
    let suttaRefs = try container.decodeIfPresent(
      [String].self,
      forKey: .suttaRefs,
    ) ?? []
    let mlDocs = try container.decodeIfPresent(
      [MLDocument].self,
      forKey: .mlDocs,
    ) ?? []
    let searchError = try container.decodeIfPresent(
      SearchErrorInfo.self,
      forKey: .searchError,
    )
    let searchSuggestion = try container.decodeIfPresent(
      String.self,
      forKey: .searchSuggestion,
    ) ?? NIL_STRING_DEFAULT

    self.init(
      author: author,
      lang: lang,
      searchLang: searchLang,
      minLang: minLang,
      maxDoc: maxDoc,
      maxResults: maxResults,
      pattern: pattern,
      method: method,
      resultPattern: resultPattern,
      segsMatched: segsMatched,
      bilaraPaths: bilaraPaths,
      suttaRefs: suttaRefs,
      mlDocs: mlDocs,
      searchError: searchError,
      searchSuggestion: searchSuggestion,
    )
  }

  // MARK: - Equatable

  public static func == (lhs: SearchResponse, rhs: SearchResponse) -> Bool {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      let lhsData = try encoder.encode(lhs)
      let rhsData = try encoder.encode(rhs)
      let lhsString = String(data: lhsData, encoding: .utf8) ?? ""
      let rhsString = String(data: rhsData, encoding: .utf8) ?? ""
      return lhsString == rhsString
    } catch {
      return false
    }
  }

  // MARK: - JSON Serialization

  /// Creates a SearchResponse from a JSON string
  /// - Parameter jsonString: A JSON string representation of SearchResponse
  /// - Returns: A decoded SearchResponse, or nil if decoding fails
  public static func fromJSON(_ jsonString: String) -> SearchResponse? {
    guard let data = jsonString.data(using: .utf8) else {
      return nil
    }
    do {
      return try JSONDecoder().decode(SearchResponse.self, from: data)
    } catch {
      return nil
    }
  }

  /// Converts SearchResponse to a JSON string
  /// - Returns: A JSON string representation of SearchResponse, or nil if
  /// encoding fails
  public func toJSON() -> String? {
    do {
      let data = try JSONEncoder().encode(self)
      return String(data: data, encoding: .utf8)
    } catch {
      return nil
    }
  }
}

// MARK: - Search Error Info

public struct SearchErrorInfo: Codable, Equatable {
  let code: String
  let message: String
}

// MARK: - Document Stats

public struct DocumentStats: Codable, Equatable {
  let text: Int
  let lang: String
  let nSegments: Int
  let nEmptySegments: Int
  let nSections: Int
  let seconds: Double

  init(
    text: Int = NIL_INT_DEFAULT,
    lang: String = NIL_STRING_DEFAULT,
    nSegments: Int = NIL_INT_DEFAULT,
    nEmptySegments: Int = NIL_INT_DEFAULT,
    nSections: Int = NIL_INT_DEFAULT,
    seconds: Double = NIL_DOUBLE_DEFAULT,
  ) {
    self.text = text
    self.lang = lang
    self.nSegments = nSegments
    self.nEmptySegments = nEmptySegments
    self.nSections = nSections
    self.seconds = seconds
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let text = try container
      .decodeIfPresent(Int.self, forKey: .text) ?? NIL_INT_DEFAULT
    let lang = try container
      .decodeIfPresent(String.self, forKey: .lang) ?? NIL_STRING_DEFAULT
    let nSegments = try container
      .decodeIfPresent(Int.self, forKey: .nSegments) ?? NIL_INT_DEFAULT
    let nEmptySegments = try container.decodeIfPresent(
      Int.self,
      forKey: .nEmptySegments,
    ) ?? NIL_INT_DEFAULT
    let nSections = try container
      .decodeIfPresent(Int.self, forKey: .nSections) ?? NIL_INT_DEFAULT
    let seconds = try container
      .decodeIfPresent(Double.self, forKey: .seconds) ?? NIL_DOUBLE_DEFAULT

    self.init(
      text: text,
      lang: lang,
      nSegments: nSegments,
      nEmptySegments: nEmptySegments,
      nSections: nSections,
      seconds: seconds,
    )
  }

  enum CodingKeys: String, CodingKey {
    case text
    case lang
    case nSegments
    case nEmptySegments
    case nSections
    case seconds
  }
}

// MARK: - Search Response Extensions

extension SearchResponse {
  /// Returns all segments that matched the search pattern
  public var matchedSegments: [Segment] {
    mlDocs.flatMap { doc in
      doc.segMap.values.filter { $0.matched == true }
    }
  }

  /// Returns the total number of documents
  var totalDocuments: Int {
    mlDocs.count
  }

  /// Returns all unique sutta references
  var uniqueSuttaRefs: [String] {
    Array(Set(suttaRefs))
  }

  /// Creates a failure SearchResponse with error information
  /// - Parameters:
  ///   - code: Error code (e.g., "file_not_found", "network_error")
  ///   - message: Human-readable error message
  ///   - suggestion: Optional remediation advice
  ///   - pattern: The search pattern that was attempted
  /// - Returns: A SearchResponse representing a failed search
  static func failure(
    code: String,
    message: String,
    suggestion: String? = nil,
    pattern: String,
  ) -> SearchResponse {
    SearchResponse(
      author: "",
      lang: "",
      searchLang: "",
      minLang: 0,
      maxDoc: 0,
      maxResults: 0,
      pattern: pattern,
      method: "",
      resultPattern: "",
      segsMatched: 0,
      bilaraPaths: [],
      suttaRefs: [],
      mlDocs: [],
      searchError: SearchErrorInfo(code: code, message: message),
      searchSuggestion: suggestion ?? NIL_STRING_DEFAULT,
    )
  }

  /// Creates a mock SearchResponse from language-specific mock response file
  /// Loads from language-specific .lproj folder (e.g.,
  /// en.lproj/mock-response-en.json)
  /// Works in both production and test environments
  /// - Parameter language: Language code (e.g., "en", "de"). Defaults to "en"
  /// - Returns: A SearchResponse loaded from the resource, or nil if loading
  /// fails
  public static func createMockResponse(language: String = "en")
    -> SearchResponse?
  {
    // Build language folder name (e.g., "en.lproj", "de.lproj")
    let languageFolder = "\(language).lproj"
    let resourceName = "mock-response-\(language)"

    guard let resourceURL = Bundle.module.url(
      forResource: resourceName,
      withExtension: "json",
      subdirectory: languageFolder,
    ),
      let data = try? Data(contentsOf: resourceURL)
    else {
      // Fall back to English if language-specific file not found
      if language != "en" {
        return createMockResponse(language: "en")
      }
      return nil
    }

    do {
      let decoder = JSONDecoder()
      decoder.userInfo[CodingUserInfoKey(rawValue: "docLang")!] = language
      return try decoder.decode(SearchResponse.self, from: data)
    } catch {
      return nil
    }
  }
}
