//
//  EbtSeeker.swift
//  scv-core
//
//  Created by Claude on 2025-11-23.
//

import Foundation
import SQLite3

// MARK: - EbtSeeker Actor

/// Actor providing thread-safe database access for a specific language/author
/// combination
public actor EbtSeeker {
  private let cc = ColorConsole(#file, #function, dbg.EbtSeeker.other)
  private let lang: String
  private let author: String
  private let db: OpaquePointer

  /// Initialize EbtSeeker with database pointer
  /// - Parameters:
  ///   - lang: Document language (e.g., "en")
  ///   - author: Document author (e.g., "sujato")
  ///   - db: Open SQLite database pointer
  init(lang: String, author: String, db: OpaquePointer) {
    self.lang = lang
    self.author = author
    self.db = db
  }

  /// Performs unified search with auto-detection or explicit method
  /// Validates that search results match this seeker's lang/author database
  /// - Parameters:
  ///   - query: Search query string
  ///   - method: Optional explicit search method (auto-detect if nil)
  ///   - maxResults: Maximum results limit (default from Settings.maxDoc)
  /// - Returns: SeekerResult with metadata and items, or error if results
  /// target different lang/author
  public func search(
    query: String,
    method: SearchMethod? = nil,
    maxResults: Int = Settings.shared.maxDoc,
  ) async -> SeekerResult {
    var result = await EbtData.shared.search(
      query: query,
      docLang: lang,
      docAuthor: author,
      method: method,
      maxResults: maxResults,
    )

    // Validate that all items match this seeker's lang/author
    for item in result.items {
      if item.suttaRef.lang != lang || item.suttaRef.author != author {
        let detail = "Expected \(lang)/\(author) but got \(item.suttaRef.lang)/\(item.suttaRef.author)"
        result.error = SearchError(
          message: "Search items target wrong database",
          detail: detail,
        )
        result.items = []
        cc.bad1(#line, #function, detail)
        return result
      }
    }

    cc.ok1(#line, #function, result.items.count, "items")
    return result
  }

  /// Populates segmentCount and headerSegments for search result items
  func populateSuttaInfo(for searchResult: inout SeekerResult) throws -> Bool {
    for i in 0 ..< searchResult.items.count {
      let suttaKey = searchResult.items[i].suttaRef.toString()

      // Query total segment count
      let countQuery = "SELECT total_segments FROM suttas WHERE sutta_key = ?"
      var countStmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) ==
        SQLITE_OK
      else {
        sqlite3_finalize(countStmt)
        continue
      }

      defer { sqlite3_finalize(countStmt) }

      sqlite3_bind_text(
        countStmt,
        1,
        (suttaKey as NSString).utf8String,
        -1,
        nil,
      )

      if sqlite3_step(countStmt) == SQLITE_ROW {
        let segmentCount = Int(sqlite3_column_int(countStmt, 0))
        searchResult.items[i].segmentCount = segmentCount
      }

      // Query header segments (segment_id LIKE "%:0%")
      let headerQuery = "SELECT segment_id, segment_text FROM segments WHERE sutta_key = ? AND segment_id LIKE ? ORDER BY segment_id"
      var headerStmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, headerQuery, -1, &headerStmt, nil) ==
        SQLITE_OK
      else {
        sqlite3_finalize(headerStmt)
        continue
      }

      defer { sqlite3_finalize(headerStmt) }

      sqlite3_bind_text(
        headerStmt,
        1,
        (suttaKey as NSString).utf8String,
        -1,
        nil,
      )
      sqlite3_bind_text(headerStmt, 2, ("%:0%" as NSString).utf8String, -1, nil)

      var headerSegments: [Segment] = []
      while sqlite3_step(headerStmt) == SQLITE_ROW {
        guard let segIdC = sqlite3_column_text(headerStmt, 0),
              let segTextC = sqlite3_column_text(headerStmt, 1)
        else {
          continue
        }

        let segId = String(cString: segIdC)
        let segText = String(cString: segTextC)

        let segment = Segment(scid: segId, doc: segText)
        headerSegments.append(segment)
      }

      searchResult.items[i].headerSegments = headerSegments
    }

    return true
  }
}

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

// MARK: - EbtSeekerError

/// Errors specific to EbtSeeker operations
public enum EbtSeekerError: Error, Sendable {
  /// Query targets wrong database lang/author
  case wrongDatabase(
    expectedLang: String,
    expectedAuthor: String,
    requestedLang: String,
    requestedAuthor: String,
  )
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

// MARK: - SeekerResultItem

/// Individual search result with sutta reference and relevance score
public struct SeekerResultItem: Sendable, Codable {
  /// The sutta reference (e.g., mn1/en/sujato)
  public let suttaRef: SuttaRef

  /// Relevance score (0.0 to 1.0+)
  public let score: Double

  /// Total number of segments in the sutta
  public var segmentCount: Int?

  /// Header segments (segment_id like "%:0%") for this sutta
  public var headerSegments: [Segment]

  /// First matching segment as HTML with matched text wrapped in <span> and
  /// ellipsis before/after (populated by background thread)
  public var quote: String?

  public init(
    suttaRef: SuttaRef,
    score: Double,
    segmentCount: Int? = nil,
    headerSegments: [Segment] = [],
    quote: String? = nil,
  ) {
    self.suttaRef = suttaRef
    self.score = score
    self.segmentCount = segmentCount
    self.headerSegments = headerSegments
    self.quote = quote
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

// MARK: - SeekerResult

/// Complete search result with metadata and matched items
public struct SeekerResult: Sendable, Codable {
  /// Search metadata including query, method, timing, etc.
  public var metadata: SearchMetadata

  /// Array of matched items
  public var items: [SeekerResultItem]

  /// Error if search failed (nil if successful)
  public var error: SearchError?

  /// Logging for SeekerResult operations (not encoded)
  private nonisolated(unsafe) let cc = ColorConsole(
    #file,
    #function,
    dbg.EbtData.other,
  )

  public init(
    metadata: SearchMetadata,
    items: [SeekerResultItem],
    error: SearchError? = nil,
  ) {
    self.metadata = metadata
    self.items = items
    self.error = error
  }

  /// Populates segmentCount and headerSegments for each item from
  /// database
  /// Called on-demand by clients (e.g., SearchCardView) in background thread
  @discardableResult
  public mutating func addSuttaInfo() async -> Bool {
    do {
      let seeker = try await EbtData.shared.getSeeker(
        lang: metadata.docLang,
        author: metadata.docAuthor,
      )
      let success = try await seeker.populateSuttaInfo(for: &self)
      if success {
        cc.ok1(
          #line,
          "addSuttaInfo: populated sutta info for \(items.count) items",
        )
      }
      return success
    } catch {
      cc.bad1(#line, "addSuttaInfo failed: \(error)")
      return false
    }
  }

  // MARK: - Codable Conformance (excluding cc)

  enum CodingKeys: String, CodingKey {
    case metadata
    case items
    case error
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    metadata = try container.decode(SearchMetadata.self, forKey: .metadata)
    items = try container.decode([SeekerResultItem].self, forKey: .items)
    error = try container.decodeIfPresent(SearchError.self, forKey: .error)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(metadata, forKey: .metadata)
    try container.encode(items, forKey: .items)
    try container.encodeIfPresent(error, forKey: .error)
  }
}
