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
  private let lemmatizer: Lemmatizer
  private let dbgSearch = dbg.EbtSeeker.search

  /// Initialize EbtSeeker with language, author, and lemmatizer
  /// - Parameters:
  ///   - lang: Document language (e.g., "en")
  ///   - author: Document author (e.g., "sujato")
  ///   - lemmatizer: Lemmatizer instance for the language
  init(lang: String, author: String, lemmatizer: Lemmatizer) {
    self.lang = lang
    self.author = author
    self.lemmatizer = lemmatizer
  }

  /// Finds the range of matched text in a segment based on search method
  private func findMatch(
    in text: String,
    query: String,
    method: SearchMethod,
  ) -> Range<String.Index>? {
    switch method {
    case .suttaref:
      // No quote for suttaref search (it's just a reference lookup)
      return nil

    case .lemma:
      guard let regex = lemmaRegexp(query) else { return nil }
      let nsText = text as NSString
      if let match = regex.firstMatch(
        in: text,
        range: NSRange(location: 0, length: nsText.length),
      ) {
        let matchRange = match.range
        let start = text.index(text.startIndex, offsetBy: matchRange.location)
        let end = text.index(start, offsetBy: matchRange.length)
        return start ..< end
      }
      return nil
    }
  }

  /// Builds HTML string with matched text in span and ellipsis for context
  private func buildQuoteHTML(
    segmentText: String,
    matchRange: Range<String.Index>,
  ) -> String {
    let contextLength = 50 // characters before/after
    let fullText = segmentText

    // Get start of context (with ellipsis if needed)
    let contextStart: String.Index
    let prefixEllipsis: String
    let startDistance = fullText.distance(
      from: fullText.startIndex,
      to: matchRange.lowerBound,
    )
    if startDistance <= contextLength {
      contextStart = fullText.startIndex
      prefixEllipsis = ""
    } else {
      contextStart = fullText.index(
        matchRange.lowerBound,
        offsetBy: -contextLength,
      )
      prefixEllipsis = "..."
    }

    // Get end of context (with ellipsis if needed)
    let contextEnd: String.Index
    let suffixEllipsis: String
    let endDistance = fullText.distance(
      from: matchRange.upperBound,
      to: fullText.endIndex,
    )
    if endDistance <= contextLength {
      contextEnd = fullText.endIndex
      suffixEllipsis = ""
    } else {
      contextEnd = fullText.index(
        matchRange.upperBound,
        offsetBy: contextLength,
      )
      suffixEllipsis = "..."
    }

    // Extract context and matched text
    let beforeMatch = String(fullText[contextStart ..< matchRange.lowerBound])
    let matchedText = String(fullText[matchRange])
    let afterMatch = String(fullText[matchRange.upperBound ..< contextEnd])

    return "\(prefixEllipsis)\(beforeMatch)<span>\(matchedText)</span>\(afterMatch)\(suffixEllipsis)"
  }

  /// Lemmatizes query text using NaturalLanguage framework
  /// Maps inflected word forms to lemma roots for morphologically-rich
  /// languages
  /// Returns lowercase lemmas to match database storage format
  /// Uses cached Lemmatizer instance for the language
  /// - Parameter query: Text to lemmatize
  /// - Returns: Array of lowercase lemmatized words
  public func lemmatize(_ query: String) -> [String] {
    var mutableLemmatizer = lemmatizer
    return mutableLemmatizer.lemmatize(query)
  }

  /// Creates NSRegularExpression from lemmatized query
  /// Lemmatizes query words and joins with ".*" for flexible matching
  /// Example: "abhängige entstehen" → regex: /abhängig.*entstehen/i
  /// - Parameter query: Text to lemmatize and convert to regex
  /// - Returns: Compiled NSRegularExpression or nil if lemmatization fails
  private func lemmaRegexp(_ query: String) -> NSRegularExpression? {
    let lemmaWords = lemmatize(query)
    guard !lemmaWords.isEmpty else { return nil }

    let pattern = lemmaWords.joined(separator: ".*")
    do {
      return try NSRegularExpression(
        pattern: pattern,
        options: [.caseInsensitive],
      )
    } catch {
      return nil
    }
  }

  /// Searches for lemmatized phrase using substring LIKE patterns
  /// Lemmatizes query words and finds segments containing all lemma forms
  /// Calculates relevance scores using same formula as keyword search:
  /// score = match_count + (match_count / total_segments)
  /// - Parameters:
  ///   - query: Phrase to search (e.g., "abhängige entstehen")
  ///   - maxDoc: Maximum results limit (defaults to MAX_DOC_DEFAULT)
  /// - Returns: SeekerResult with matching suttas ranked by relevance score
  public func searchLemma(
    _ query: String,
    maxDoc: Int = Settings.shared.maxDoc,
  ) async -> SeekerResult {
    // Lemmatize query
    if dbgSearch > 1 {
      cc.ok2(#line, #function, "lemmatize", query)
    }
    let lemmaWords = lemmatize(query)
    if dbgSearch > 1 {
      cc.ok2(#line, #function, lemmaWords.joined(separator: ", "))
    }

    guard !lemmaWords.isEmpty else {
      if dbgSearch > 1 {
        cc.ok2(#line, #function, "lemmaWords[]?")
      }
      return SeekerResult(
        metadata: SearchMetadata(
          query: query,
          method: .lemma,
          elapsedTime: 0,
          docLang: lang,
          docAuthor: author,
        ),
        items: [],
      )
    }

    // Delegate SQL execution to EbtData (includes LIKE pattern building)
    let result = await EbtData.searchLemma(
      lang: lang,
      author: author,
      lemmaWords: lemmaWords,
      query: query,
      maxDoc: maxDoc,
    )

    if dbgSearch != 0 {
      cc.ok1(#line, #function, result.items.count)
    }
    return result
  }

  /// Query quote (first matching segment) for a sutta based on search query and
  /// method
  /// - Parameters:
  ///   - suttaRef: The sutta reference
  ///   - query: Search query string
  ///   - method: Search method to determine how to find matching text
  /// - Returns: HTML string with matched text wrapped in span, or nil if no
  /// match found
  func queryQuote(
    suttaRef: SuttaRef,
    query: String,
    method: SearchMethod,
  ) async throws -> String? {
    // Get all segments for this sutta from data layer
    let segments = await EbtData.segmentsOfSuttaRef(suttaRef)

    // Find first matching segment
    for segment in segments {
      guard let segmentText = segment.doc else { continue }

      // Check if segment matches based on search method
      let matchRange = findMatch(
        in: segmentText,
        query: query,
        method: method,
      )
      if let matchRange {
        // Build HTML with span around matched text
        return buildQuoteHTML(
          segmentText: segmentText,
          matchRange: matchRange,
        )
      }
    }

    return nil
  }

  /// Query total segment count for this sutta
  func querySegmentCount(suttaRef: SuttaRef) async throws -> Int? {
    // Get all segments and count them
    let segments = await EbtData.segmentsOfSuttaRef(suttaRef)
    return segments.isEmpty ? nil : segments.count
  }

  func queryHeader(suttaRef: SuttaRef) async throws -> [Segment] {
    // Get all segments for this sutta
    let segments = await EbtData.segmentsOfSuttaRef(suttaRef)

    // Filter for header segments (scid LIKE "%:0%")
    return segments.filter { segment in
      segment.scid.contains(":0")
    }
  }
}

// MARK: - SearchMethod Enum

/// Search method used to find results
public enum SearchMethod: String, Sendable, Codable {
  /// Search by SuttaRef - parse comma-delimited list and lookup each reference
  case suttaref

  /// Lemma search - find lemmatized phrase matches
  case lemma
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

  /// Populate result item with segment info and quote
  /// - Parameters:
  ///   - seeker: The EbtSeeker to use for queries
  ///   - query: Search query string for quote matching
  ///   - method: Search method for quote matching
  mutating func populate(
    seeker: EbtSeeker,
    query: String,
    method: SearchMethod,
  ) async throws -> Bool {
    segmentCount = try await seeker.querySegmentCount(suttaRef: suttaRef)
    headerSegments = try await seeker.queryHeader(suttaRef: suttaRef)

    // For suttaref searches, use last header segment as quote (no text
    // matching)
    // For other methods, query for matching text
    if method == .suttaref {
      quote = headerSegments.last?.doc
    } else {
      quote = try await seeker.queryQuote(
        suttaRef: suttaRef,
        query: query,
        method: method,
      )
    }

    return true
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

  /// Populate segment count, header segments, and quotes for each result item
  /// Gets the correct seeker for each item based on its suttaRef
  public mutating func populateItems() async -> Bool {
    for i in items.indices {
      do {
        let seeker = try await EbtData.getSeeker(
          suttaRef: items[i].suttaRef,
        )
        _ = try await items[i].populate(
          seeker: seeker,
          query: metadata.query,
          method: metadata.method,
        )
      } catch {
        cc.bad1(
          #line,
          "populateItems failed for \(items[i].suttaRef): \(error)",
        )
        return false
      }
    }

    cc.ok1(
      #line,
      "populateItems: populated segment info and quotes for \(items.count) items",
    )
    return true
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
