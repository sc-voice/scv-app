//
//  SearchResult.swift
//  scv-core
//
//  Created by Claude on 2025-11-23.
//

import Foundation

// MARK: - SearchMethod Enum

/// Search method used to find results
public enum SearchMethod: String, Sendable, Codable {
  /// Search by SuttaRef - parse comma-delimited list and lookup each reference
  case suttaref

  /// Phrase search - find exact phrase matches
  case phrase

  /// Keyword search - find documents matching any/all keywords
  case keyword

  /// Regexp search - find using regular expression pattern
  case regexp
}

// MARK: - SearchError

/// Structured search error with localized message and technical details
public struct SearchError: Sendable, Codable {
  /// Localized error message for user display
  public let message: String

  /// English technical details for debugging
  public let detail: String

  public init(message: String, detail: String) {
    self.message = message
    self.detail = detail
  }
}

// MARK: - SearchResultItem

/// Individual search result with sutta reference and relevance score
public struct SearchResultItem: Sendable, Codable {
  /// The sutta reference (e.g., mn1/en/sujato)
  public let suttaRef: SuttaRef

  /// Relevance score (0.0 to 1.0+)
  public let score: Double

  public init(suttaRef: SuttaRef, score: Double) {
    self.suttaRef = suttaRef
    self.score = score
  }
}

// MARK: - SearchMetadata

/// Metadata about a search operation
public struct SearchMetadata: Sendable, Codable {
  /// When search was performed
  public var timestamp: Date

  /// Query string that was searched
  public var query: String

  /// Method used to find results
  public var method: SearchMethod

  /// Time elapsed during search in seconds
  public var elapsedTime: TimeInterval

  /// Document language for search
  public var docLang: String

  /// Document author for search
  public var docAuthor: String

  /// Reference language (e.g., pali for root texts)
  public var refLang: String

  /// Reference author (e.g., "ms" for pali)
  public var refAuthor: String?

  /// Maximum documents limit from Settings at time of search
  public var maxDoc: Int

  public init(
    timestamp: Date = Date(),
    query: String,
    method: SearchMethod,
    elapsedTime: TimeInterval,
    docLang: String,
    docAuthor: String,
    refLang: String? = nil,
    refAuthor: String? = nil,
    maxDoc: Int? = nil,
  ) {
    self.timestamp = timestamp
    self.query = query
    self.method = method
    self.elapsedTime = elapsedTime
    self.docLang = docLang
    self.docAuthor = docAuthor
    self.refLang = refLang ?? Settings.shared.refLang.code
    self.refAuthor = refAuthor ?? Settings.shared.refAuthor
    self.maxDoc = maxDoc ?? Settings.shared.maxDoc
  }
}

// MARK: - SearchResult

/// Complete search result with metadata and matched items
public struct SearchResult: Sendable, Codable {
  /// Search metadata including query, method, timing, etc.
  public var metadata: SearchMetadata

  /// Array of matched results
  public var results: [SearchResultItem]

  /// Error if search failed (nil if successful)
  public var error: SearchError?

  public init(
    metadata: SearchMetadata,
    results: [SearchResultItem],
    error: SearchError? = nil,
  ) {
    self.metadata = metadata
    self.results = results
    self.error = error
  }
}

// MARK: - SearchMethodDetection

/// Result of auto-detecting search method from query string
public struct SearchMethodDetection: Sendable {
  /// Detected search method
  public let method: SearchMethod

  /// Pre-parsed SearchResultItems (populated for .suttaref, empty for others)
  public let items: [SearchResultItem]

  public init(method: SearchMethod, items: [SearchResultItem] = []) {
    self.method = method
    self.items = items
  }
}
