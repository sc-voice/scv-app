//
//  SearchResult.swift
//  scv-core
//
//  Created by Claude on 2025-11-23.
//

import Foundation

// MARK: - SearchMethod Enum

/// Search method used to find results
public enum SearchMethod: String, Sendable {
  /// Search by SuttaRef - parse comma-delimited list and lookup each reference
  case suttaref

  /// Phrase search - find exact phrase matches
  case phrase

  /// Keyword search - find documents matching any/all keywords
  case keyword

  /// Regexp search - find using regular expression pattern
  case regexp
}

// MARK: - SearchResultItem

/// Individual search result with sutta reference and relevance score
public struct SearchResultItem: Sendable {
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
public struct SearchMetadata: Sendable {
  /// When search was performed
  public let timestamp: Date

  /// Query string that was searched
  public let query: String

  /// Method used to find results
  public let method: SearchMethod

  /// Time elapsed during search in seconds
  public let elapsedTime: TimeInterval

  /// Document language for search
  public let docLang: String

  /// Document author for search
  public let docAuthor: String

  /// Reference language (e.g., pali for root texts)
  public let refLang: String

  /// Reference author (e.g., "ms" for pali)
  public let refAuthor: String?

  /// Maximum documents limit from Settings at time of search
  public let maxDoc: Int

  public init(
    timestamp: Date,
    query: String,
    method: SearchMethod,
    elapsedTime: TimeInterval,
    docLang: String,
    docAuthor: String,
    refLang: String,
    refAuthor: String?,
    maxDoc: Int,
  ) {
    self.timestamp = timestamp
    self.query = query
    self.method = method
    self.elapsedTime = elapsedTime
    self.docLang = docLang
    self.docAuthor = docAuthor
    self.refLang = refLang
    self.refAuthor = refAuthor
    self.maxDoc = maxDoc
  }
}

// MARK: - SearchResult

/// Complete search result with metadata and matched items
public struct SearchResult: Sendable {
  /// Search metadata including query, method, timing, etc.
  public let metadata: SearchMetadata

  /// Array of matched results
  public let results: [SearchResultItem]

  public init(metadata: SearchMetadata, results: [SearchResultItem]) {
    self.metadata = metadata
    self.results = results
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
