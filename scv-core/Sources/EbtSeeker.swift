//
//  EbtSeeker.swift
//  scv-core
//
//  Created by Claude on 2025-11-23.
//

import Foundation
import NaturalLanguage
import SQLite3

// MARK: - EbtSeeker Actor

/// Actor providing thread-safe database access for a specific language/author
/// combination
public actor EbtSeeker {
  private let cc = ColorConsole(#file, #function, dbg.EbtSeeker.other)
  private let lang: String
  private let author: String
  private let db: OpaquePointer
  private lazy var lemmatizer = NLTagger(tagSchemes: [.lemma])

  public static func searchAny(
    query: String,
    settings: Settings = Settings.shared,
  ) async -> SeekerResult {
    let (suttaRefs, method) = parseQuery(query: query, settings: settings)

    if method == .suttaref {
      // Create separate seeker for each suttaRef since they may have different
      // lang/author combinations
      var allItems: [SeekerResultItem] = []
      var lastError: SearchError?
      var elapsedTime: TimeInterval = 0

      for suttaRef in suttaRefs {
        do {
          let seeker = try await EbtData.shared.getSeeker(
            lang: suttaRef.lang,
            author: suttaRef.author ?? settings.docAuthor,
          )
          let result = await seeker.search(
            query: suttaRef.toString(),
            method: .suttaref,
          )
          allItems.append(contentsOf: result.items)
          elapsedTime += result.metadata.elapsedTime
          if result.error != nil {
            lastError = result.error
          }
        } catch {
          lastError = SearchError(
            message: "Failed to get seeker for \(suttaRef)",
            detail: error.localizedDescription,
          )
        }
      }

      return SeekerResult(
        metadata: SearchMetadata(
          query: query,
          method: method,
          elapsedTime: elapsedTime,
          docLang: settings.docLang.code,
          docAuthor: settings.docAuthor,
        ),
        items: allItems,
        error: lastError,
      )
    } else {
      // Lemma search uses single seeker with settings defaults
      do {
        let seeker = try await EbtData.shared.getSeeker(
          lang: settings.docLang.code,
          author: settings.docAuthor,
        )
        return await seeker.searchLemma(query)
      } catch {
        return SeekerResult(
          metadata: SearchMetadata(
            query: query,
            method: method,
            elapsedTime: 0,
            docLang: settings.docLang.code,
            docAuthor: settings.docAuthor,
          ),
          items: [],
          error: SearchError(
            message: "Failed to get seeker",
            detail: error.localizedDescription,
          ),
        )
      }
    }
  }

  public static func parseQuery(
    query: String,
    method: SearchMethod? = nil,
    settings: Settings = Settings.shared,
  ) -> (suttaRefs: [SuttaRef], method: SearchMethod) {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    let entries = trimmed.split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }

    // Try to parse each entry as a SuttaRef with language-specific defaults
    var suttaRefs: [SuttaRef] = []
    for entry in entries {
      // Try parsing with docLang/docAuthor as defaults
      if let ref = SuttaRef.create(
        entry,
        defaultLang: settings.docLang.code,
        defaultAuthor: settings.docAuthor,
      ) {
        suttaRefs.append(ref)
      }
    }

    // Determine method based on whether all entries were valid scids
    let resultMethod: SearchMethod = if !suttaRefs.isEmpty {
      .suttaref
    } else {
      method ?? .lemma
    }

    return (suttaRefs: suttaRefs, method: resultMethod)
  }

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

  /// Populates quote field for search result items based on query and search
  /// method
  func populateQuotes(for searchResult: inout SeekerResult) throws -> Bool {
    for i in 0 ..< searchResult.items.count {
      let success = populateQuote(
        item: &searchResult.items[i],
        query: searchResult.metadata.query,
        method: searchResult.metadata.method,
      )
      if success {
        cc.ok2(
          #line,
          "Populated quote for \(searchResult.items[i].suttaRef.suttaUid)",
        )
      }
    }
    return true
  }

  /// Populates quote field for a single search result item
  private func populateQuote(
    item: inout SeekerResultItem,
    query: String,
    method: SearchMethod,
  ) -> Bool {
    // Query segments for this sutta
    let suttaKey = "\(item.suttaRef.suttaUid)/\(item.suttaRef.lang)/\(item.suttaRef.author ?? "")"
    let sqlQuery = "SELECT segment_text FROM segments WHERE sutta_key = ? ORDER BY segment_id"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK else {
      return false
    }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, (suttaKey as NSString).utf8String, -1, nil)

    // Find first matching segment
    while sqlite3_step(stmt) == SQLITE_ROW {
      guard let segmentTextC = sqlite3_column_text(stmt, 0) else { continue }
      let segmentText = String(cString: segmentTextC)

      // Check if segment matches based on search method
      let matchRange = findMatch(
        in: segmentText,
        query: query,
        method: method,
      )
      if let matchRange {
        // Build HTML with span around matched text
        item.quote = buildQuoteHTML(
          segmentText: segmentText,
          matchRange: matchRange,
        )
        return true
      }
    }

    return false
  }

  /// Finds the range of matched text in a segment based on search method
  private func findMatch(
    in text: String,
    query: String,
    method: SearchMethod,
  ) -> Range<String.Index>? {
    switch method {
    case .keyword, .phrase:
      // Case-insensitive substring search
      let lowercased = text.lowercased()
      let lowerQuery = query.lowercased()
      if let range = lowercased.range(of: lowerQuery) {
        // Convert lowercased range to original text range
        let startDistance = lowercased.distance(
          from: lowercased.startIndex,
          to: range.lowerBound,
        )
        let start = text.index(text.startIndex, offsetBy: startDistance)
        let end = text.index(start, offsetBy: lowerQuery.count)
        return start ..< end
      }
      return nil

    case .regexp:
      // Regex search
      do {
        let regex = try NSRegularExpression(
          pattern: query,
          options: [.caseInsensitive],
        )
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
      } catch {
        // Invalid regex, return nil
        return nil
      }
      return nil

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
  /// - Parameter query: Text to lemmatize
  /// - Returns: Array of lemmatized words
  public func lemmatize(_ query: String) -> [String] {
    var lemmas: [String] = []

    // Normalize input for language-specific character mappings
    var normalizedQuery = query
    switch lang {
    case "de":
      normalizedQuery = query
        .replacingOccurrences(of: "ae", with: "ä")
        .replacingOccurrences(of: "oe", with: "ö")
        .replacingOccurrences(of: "ue", with: "ü")
    default:
      normalizedQuery = query
    }

    lemmatizer.string = normalizedQuery
    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

    lemmatizer.enumerateTags(
      in: normalizedQuery.startIndex ..< normalizedQuery.endIndex,
      unit: .word,
      scheme: .lemma,
      options: options,
    ) { tag, tokenRange in
      let lemma = tag?.rawValue ?? String(normalizedQuery[tokenRange])
      lemmas.append(lemma)
      return true
    }

    return lemmas
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
  /// - Parameter query: Phrase to search (e.g., "abhängige entstehen")
  /// - Returns: SeekerResult with matching suttas ranked by relevance score
  public func searchLemma(_ query: String) -> SeekerResult {
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()

    // Lemmatize query
    let lemmaWords = lemmatize(query)

    // Build LIKE patterns: ["%abhäng%", "%entste%"]
    let likePatterns = lemmaWords.map { "%\($0)%" }

    // Build WHERE clause: segment_text LIKE '%abhäng%' AND segment_text LIKE
    // '%entste%'
    let whereConditions = likePatterns.map { "segment_text LIKE '\($0)'" }
      .joined(separator: " AND ")

    // Query with scoring: count matching segments and calculate combined score
    let sqlQuery = """
    SELECT s.sutta_key, COUNT(seg.rowid) as match_count, s.total_segments,
           COUNT(seg.rowid) + (CAST(COUNT(seg.rowid) AS FLOAT) / s.total_segments) as combined_score
    FROM segments seg
    JOIN suttas s ON seg.sutta_key = s.sutta_key
    WHERE \(whereConditions)
    GROUP BY seg.sutta_key, s.total_segments
    ORDER BY combined_score DESC
    """

    var itemsWithScores: [(key: String, score: Double)] = []

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK else {
      let metadata = SearchMetadata(
        query: query,
        method: .lemma,
        elapsedTime: CFAbsoluteTimeGetCurrent() - elapsedAtStart,
        docLang: lang,
        docAuthor: author,
      )
      return SeekerResult(metadata: metadata, items: [])
    }
    defer { sqlite3_finalize(stmt) }

    while sqlite3_step(stmt) == SQLITE_ROW {
      guard let keyC = sqlite3_column_text(stmt, 0) else { continue }
      let suttaKey = String(cString: keyC)
      let score = sqlite3_column_double(stmt, 3)
      itemsWithScores.append((key: suttaKey, score: score))
    }

    // Convert to SeekerResultItems (already sorted by SQL ORDER BY)
    var items: [SeekerResultItem] = []
    for (suttaKey, score) in itemsWithScores {
      if let ref = SuttaRef.create(suttaKey) {
        items.append(SeekerResultItem(suttaRef: ref, score: score))
      }
    }

    let metadata = SearchMetadata(
      query: query,
      method: .lemma,
      elapsedTime: CFAbsoluteTimeGetCurrent() - elapsedAtStart,
      docLang: lang,
      docAuthor: author,
    )

    return SeekerResult(metadata: metadata, items: items)
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

  /// Populates segmentCount, headerSegments, and quotes for each item from
  /// database
  /// Called on-demand by clients (e.g., SearchCardView) in background thread
  @discardableResult
  public mutating func addSuttaInfo() async -> Bool {
    do {
      let seeker = try await EbtData.shared.getSeeker(
        lang: metadata.docLang,
        author: metadata.docAuthor,
      )

      // Populate sutta info (segment count and headers)
      let infoSuccess = try await seeker.populateSuttaInfo(for: &self)
      if !infoSuccess {
        cc.bad1(#line, "Failed to populate sutta info")
        return false
      }

      // Populate quotes
      let quotesSuccess = try await seeker.populateQuotes(for: &self)
      if !quotesSuccess {
        cc.bad1(#line, "Failed to populate quotes")
        return false
      }

      cc.ok1(
        #line,
        "addSuttaInfo: populated sutta info and quotes for \(items.count) items",
      )
      return true
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
