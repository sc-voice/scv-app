import Foundation
import SQLite3

/// Actor providing access to per-author SQLite databases
/// (ebt-{lang}-{author}.db)
/// Each author has separate database containing segments and metadata
/// Actor ensures thread-safe single-threaded access to SQLite
public actor EbtData {
  public let cc = ColorConsole(#file, #function, dbg.EbtData.other)
  public static let shared = EbtData()

  // Safe: Dictionary is only accessed within actor-isolated methods and deinit.
  // Actor serialization ensures only one task accesses databases at a time.
  // Key format: "lang/author" (e.g., "en/sujato", "de/sabbamitta")
  private nonisolated(unsafe) var databases: [String: OpaquePointer?] = [:]

  // Manifest loaded once at app startup
  private nonisolated(unsafe) static let manifestCache: DatabaseManifest? =
    DatabaseManifest.load()

  private init() {}

  // MARK: - Manifest Access

  /// Returns loaded database manifest
  /// Fast lookup without decompressing databases
  public nonisolated static func manifest() -> DatabaseManifest? {
    manifestCache
  }

  /// Returns all available database info from manifest
  public nonisolated static func availableDatabasesFromManifest()
    -> [DatabaseInfo]
  {
    manifestCache?.databases ?? []
  }

  /// Returns authors available for specific language from manifest
  public nonisolated static func authorsForLanguageFromManifest(
    _ language: String,
  )
    -> [DatabaseInfo]
  {
    manifestCache?.authorsForLanguage(language) ?? []
  }

  // MARK: - Decompression

  /// Checks if database needs decompression from bundle
  public func needsDecompression(lang: String, author: String) -> Bool {
    let fileName = "ebt-\(lang)-\(author).db"
    let cacheURL = FileManager.default.urls(
      for: .cachesDirectory,
      in: .userDomainMask,
    )[0]
    let dbURL = cacheURL.appendingPathComponent(fileName)
    let exists = FileManager.default.fileExists(atPath: dbURL.path)
    cc.ok1(#line, fileName, "exists:", exists)
    return !exists
  }

  /// Public method to pre-decompress database (UI should call when docLang
  /// changes if needed)
  /// Allows UI to show progress indicator while decompression occurs
  public func decompressDatabase(lang: String, author: String) throws {
    _ = try ensureDecompressed(lang: lang, author: author)
  }

  /// Returns path to decompressed database in Caches, decompressing if needed
  private func ensureDecompressed(lang: String, author: String) throws -> URL {
    let fileName = "ebt-\(lang)-\(author).db"
    let cacheURL = FileManager.default.urls(
      for: .cachesDirectory,
      in: .userDomainMask,
    )[0]
    let dbURL = cacheURL.appendingPathComponent(fileName)

    // Check if already decompressed in Caches
    if FileManager.default.fileExists(atPath: dbURL.path) {
      cc.ok1(#line, "cached:", fileName)
      return dbURL
    }

    // Find and decompress .zst from bundle
    guard let zstURL = Bundle.module.url(
      forResource: "ebt-\(lang)-\(author)",
      withExtension: "db.zst",
    ) else {
      cc.bad1(#line, fileName + ".zst not found:")
      throw EbtDataError.databaseNotFound(lang: lang, author: author)
    }

    // Read compressed data from bundle
    let compressedData = try Data(contentsOf: zstURL)

    // Decompress using libzstd
    let decompressedData = try ZstdDecompression.decompress(compressedData)

    // Write decompressed database to Caches
    try decompressedData.write(to: dbURL)
    cc.ok1(#line, fileName, "OK")

    return dbURL
  }

  // MARK: - Database Connection

  /// Lazily opens database connection for specific author on first access
  /// Decompresses from bundle .zst to Caches if needed
  private func ensureDatabase(lang: String, author: String) throws {
    let key = "\(lang)/\(author)"
    guard databases[key] == nil else { return }

    // Ensure decompressed database exists in Caches
    let dbURL = try ensureDecompressed(lang: lang, author: author)

    var database: OpaquePointer?
    let result = sqlite3_open_v2(
      dbURL.path,
      &database,
      SQLITE_OPEN_READONLY,
      nil,
    )

    guard result == SQLITE_OK else {
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }

    databases[key] = database

    // Log database metadata
    logDatabaseMetadata(lang: lang, author: author)
  }

  deinit {
    // Safe: Actor has no remaining references when deinit runs.
    // databases dictionary is nonisolated(unsafe) but only accessed here and in
    // actor methods.
    // sqlite3_close must be called on same thread that opened connection.
    for (_, database) in databases {
      if let db = database {
        sqlite3_close(db)
      }
    }
  }

  // MARK: - Key-based Retrieval

  /// Returns concatenated segments as JSON-like string for given key (e.g.,
  /// "en/sujato/mn1")
  /// Backwards compatible: parses lang and author from key
  public func getTranslation(suttaKey: String) -> String? {
    let components = suttaKey.split(separator: "/").map(String.init)
    guard components.count >= 3 else { return nil }

    let lang = components[0]
    let author = components[1]
    let suttaId = components.dropFirst(2).joined(separator: "/")

    return getTranslation(lang: lang, author: author, suttaId: suttaId)
  }

  /// Returns concatenated segments as JSON-like string for explicit
  /// language/author/suttaId
  public func getTranslation(lang: String, author: String,
                             suttaId: String) -> String?
  {
    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { return nil }

      let query = "SELECT segment_id, segment_text FROM segments WHERE sutta_key = ? ORDER BY segment_id"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return nil
      }

      defer { sqlite3_finalize(stmt) }

      // Construct full sutta_key for query: lang/author/suttaId
      let fullSuttaKey = "\(lang)/\(author)/\(suttaId)"
      sqlite3_bind_text(stmt, 1, (fullSuttaKey as NSString).utf8String, -1, nil)

      var segments: [(String, String)] = []
      while sqlite3_step(stmt) == SQLITE_ROW {
        if let segmentIdC = sqlite3_column_text(stmt, 0),
           let segmentTextC = sqlite3_column_text(stmt, 1)
        {
          let segmentId = String(cString: segmentIdC)
          let segmentText = String(cString: segmentTextC)
          segments.append((segmentId, segmentText))
        }
      }

      guard !segments.isEmpty else { return nil }

      // Reconstruct as JSON
      var jsonDict: [String: String] = [:]
      for (id, text) in segments {
        jsonDict[id] = text
      }

      if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict),
         let jsonString = String(data: jsonData, encoding: .utf8)
      {
        return jsonString
      }

      return nil
    } catch {
      return nil
    }
  }

  // MARK: - MLDocument Retrieval

  /// Returns MLDocument for a given sutta_key (e.g., "en/sujato/an1.2")
  /// - Parameter suttaKey: Sutta key in format "lang/author/sutta_uid"
  /// - Returns: MLDocument with segments populated, or nil if not found
  public func getMLDocument(suttaKey: String) -> MLDocument? {
    let components = suttaKey.split(separator: "/").map(String.init)
    guard components.count >= 3 else { return nil }

    let lang = components[0]
    let author = components[1]
    let suttaId = components.dropFirst(2).joined(separator: "/")

    return getMLDocument(lang: lang, author: author, suttaId: suttaId)
  }

  /// Returns MLDocument for explicit language/author/suttaId
  /// - Parameters:
  ///   - lang: Language code (e.g., "en")
  ///   - author: Author identifier (e.g., "sujato")
  ///   - suttaId: Sutta identifier (e.g., "an1.2")
  /// - Returns: MLDocument with segments populated, or nil if not found
  public func getMLDocument(lang: String, author: String, suttaId: String)
    -> MLDocument?
  {
    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { return nil }

      // Get author name from metadata
      let authorName = metadata(lang: lang, author: author)?
        .authorName ?? author

      // Query segments for this sutta
      let query = "SELECT segment_id, segment_text FROM segments WHERE sutta_key = ? ORDER BY segment_id"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return nil
      }

      defer { sqlite3_finalize(stmt) }

      let fullSuttaKey = "\(lang)/\(author)/\(suttaId)"
      sqlite3_bind_text(stmt, 1, (fullSuttaKey as NSString).utf8String, -1, nil)

      var segMap: [String: Segment] = [:]
      while sqlite3_step(stmt) == SQLITE_ROW {
        guard let segmentIdC = sqlite3_column_text(stmt, 0),
              let segmentTextC = sqlite3_column_text(stmt, 1)
        else {
          continue
        }

        let segmentId = String(cString: segmentIdC)
        let segmentText = String(cString: segmentTextC)

        // Create Segment with scid = segmentId
        let segment = Segment(scid: segmentId, doc: segmentText, matched: false)
        segMap[segmentId] = segment
      }

      guard !segMap.isEmpty else { return nil }

      // Construct MLDocument
      let mlDoc = MLDocument(
        author: author,
        segMap: segMap,
        sutta_uid: suttaId,
        docLang: lang,
        docAuthor: author,
        docAuthorName: authorName,
      )

      return mlDoc
    } catch {
      return nil
    }
  }

  // MARK: - FTS Keyword Search

  /// Returns sutta keys ranked by relevance percentage (matching_segments /
  /// total_segments)
  /// Respects Settings.maxDoc limit
  public func searchKeywords(lang: String, author: String,
                             query: String) -> [String]
  {
    searchKeywordsWithScores(lang: lang, author: author, query: query)
      .map(\.key)
  }

  /// Returns sutta keys with match counts and scores for debugging/display
  /// Includes scoring details for display purposes
  public func searchKeywordsWithScores(
    lang: String,
    author: String,
    query: String,
  ) -> [(
    key: String,
    matchCount: Int,
    totalSegments: Int,
    relevancePercent: Double,
    score: Double,
  )] {
    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { return [] }

      let limit = Settings.shared.maxDoc

      // Query: find matching segments, count per sutta, calculate combined score
      // score = match_count + relevance_percentage
      let sqlQuery = """
      SELECT s.sutta_key, COUNT(sf.rowid) as match_count, s.total_segments,
             CAST(COUNT(sf.rowid) AS FLOAT) / s.total_segments as relevance_pct,
             COUNT(sf.rowid) + (CAST(COUNT(sf.rowid) AS FLOAT) / s.total_segments) as combined_score
      FROM segments_fts sf
      JOIN suttas s ON sf.sutta_key = s.sutta_key
      WHERE sf.segment_text MATCH ?
      GROUP BY sf.sutta_key
      ORDER BY combined_score DESC
      LIMIT ?
      """

      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK else {
        return []
      }

      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (query as NSString).utf8String, -1, nil)
      sqlite3_bind_int(stmt, 2, Int32(limit))

      var results: [(
        key: String,
        matchCount: Int,
        totalSegments: Int,
        relevancePercent: Double,
        score: Double,
      )] = []
      while sqlite3_step(stmt) == SQLITE_ROW {
        if let cString = sqlite3_column_text(stmt, 0) {
          let key = String(cString: cString)
          let matchCount = Int(sqlite3_column_int(stmt, 1))
          let totalSegments = Int(sqlite3_column_int(stmt, 2))
          let relevancePercent = sqlite3_column_double(stmt, 3)
          let score = sqlite3_column_double(stmt, 4)
          results.append((
            key: key,
            matchCount: matchCount,
            totalSegments: totalSegments,
            relevancePercent: relevancePercent,
            score: score,
          ))
        }
      }

      return results
    } catch {
      return []
    }
  }

  // MARK: - Phrase Search

  /// Returns sutta keys ranked by relevance percentage (matching_segments /
  /// total_segments)
  /// Filters keyword search results to only those containing exact phrase
  /// Respects Settings.maxDoc limit
  public func searchPhrase(lang: String, author: String,
                           phrase: String) -> [String]
  {
    do {
      try ensureDatabase(lang: lang, author: author)

      // Step 1: Get keyword search results (all words present)
      let keywordResults = searchKeywords(
        lang: lang,
        author: author,
        query: phrase,
      )

      // Step 2: Filter to only those containing exact phrase
      var phraseMatches: [String] = []

      for suttaKey in keywordResults {
        if containsPhrase(
          lang: lang,
          author: author,
          suttaKey: suttaKey,
          phrase: phrase,
        ) {
          phraseMatches.append(suttaKey)
        }
      }

      return phraseMatches
    } catch {
      return []
    }
  }

  /// Helper: Check if sutta contains exact phrase in any segment
  private func containsPhrase(
    lang: String,
    author: String,
    suttaKey: String,
    phrase: String,
  ) -> Bool {
    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { return false }

      // Query all segments for this sutta
      let query = "SELECT segment_text FROM segments WHERE sutta_key = ?"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return false
      }

      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (suttaKey as NSString).utf8String, -1, nil)

      while sqlite3_step(stmt) == SQLITE_ROW {
        guard let segmentTextC = sqlite3_column_text(stmt, 0) else { continue }
        let segmentText = String(cString: segmentTextC)

        // Case-insensitive phrase search
        if segmentText.lowercased().contains(phrase.lowercased()) {
          return true
        }
      }

      return false
    } catch {
      return false
    }
  }

  // MARK: - Regexp Search

  /// Returns sutta keys ranked by relevance percentage (matching_segments /
  /// total_segments)
  /// using regexp pattern matching on segment text
  /// Respects Settings.maxDoc limit
  public func searchRegexp(lang: String, author: String,
                           pattern: String) -> [String]
  {
    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { return [] }

      // Compile regex
      let regex = try NSRegularExpression(pattern: pattern, options: [])

      // Query all segments
      let query = "SELECT DISTINCT sf.sutta_key, sf.segment_text FROM segments_fts sf"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return []
      }

      defer { sqlite3_finalize(stmt) }

      var matchesBySutta: [String: Int] = [:] // sutta_key -> match count
      var totalSegmentsBySutta: [String: Int] =
        [:] // sutta_key -> total segment count

      while sqlite3_step(stmt) == SQLITE_ROW {
        guard let sutlaKeyC = sqlite3_column_text(stmt, 0),
              let segmentTextC = sqlite3_column_text(stmt, 1)
        else {
          continue
        }

        let suttaKey = String(cString: sutlaKeyC)
        let segmentText = String(cString: segmentTextC)

        let range = NSRange(segmentText.startIndex..., in: segmentText)
        if regex.firstMatch(in: segmentText, options: [], range: range) != nil {
          matchesBySutta[suttaKey, default: 0] += 1
        }
      }

      // Query total segments per sutta
      let totalQuery = "SELECT sutta_key, total_segments FROM suttas"
      var totalStmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, totalQuery, -1, &totalStmt, nil) ==
        SQLITE_OK
      else {
        return []
      }

      defer { sqlite3_finalize(totalStmt) }

      while sqlite3_step(totalStmt) == SQLITE_ROW {
        guard let keyC = sqlite3_column_text(totalStmt, 0) else { continue }
        let suttaKey = String(cString: keyC)
        let totalSegments = Int(sqlite3_column_int(totalStmt, 1))
        totalSegmentsBySutta[suttaKey] = totalSegments
      }

      // Calculate combined score = match_count + relevance_percentage
      var resultsWithScore: [(key: String, score: Double)] = []
      let limit = Settings.shared.maxDoc

      for (suttaKey, matchCount) in matchesBySutta {
        if let totalSegments = totalSegmentsBySutta[suttaKey],
           totalSegments > 0
        {
          let relevancePct = Double(matchCount) / Double(totalSegments)
          let combinedScore = Double(matchCount) + relevancePct
          resultsWithScore.append((key: suttaKey, score: combinedScore))
        }
      }

      return resultsWithScore
        .sorted { $0.score > $1.score }
        .prefix(limit)
        .map(\.key)
    } catch {
      return []
    }
  }

  // MARK: - Discovery Methods

  /// Returns list of available (language, author) pairs
  public func availableAuthors() -> [(lang: String, author: String)] {
    // Discover from bundle resources by scanning for ebt-*.db.zst files
    var authors: [(lang: String, author: String)] = []

    guard let resourceURLs = try? FileManager.default.contentsOfDirectory(
      at: Bundle.module.resourceURL ?? URL(fileURLWithPath: "."),
      includingPropertiesForKeys: nil,
    ) else {
      return []
    }

    for url in resourceURLs {
      let filename = url.lastPathComponent
      if filename.hasPrefix("ebt-"), filename.hasSuffix(".db.zst") {
        // Format: ebt-{lang}-{author}.db.zst
        let parts = filename.dropFirst(4).dropLast(7).split(separator: "-")
        if parts.count >= 2 {
          let lang = String(parts[0])
          let author = parts.dropFirst().joined(separator: "-")
          authors.append((lang: lang, author: author))
        }
      }
    }

    return authors.sorted { ($0.lang, $0.author) < ($1.lang, $1.author) }
  }

  /// Returns metadata for specific author if available
  public func metadata(lang: String, author: String) -> AuthorMetadata? {
    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { return nil }

      let query = "SELECT language, author, author_name, git_hash, build_timestamp, json FROM metadata LIMIT 1"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return nil
      }

      defer { sqlite3_finalize(stmt) }

      if sqlite3_step(stmt) == SQLITE_ROW {
        if let langC = sqlite3_column_text(stmt, 0),
           let authorC = sqlite3_column_text(stmt, 1),
           let authorNameC = sqlite3_column_text(stmt, 2),
           let buildTimestampC = sqlite3_column_text(stmt, 4)
        {
          let metaLang = String(cString: langC)
          let metaAuthor = String(cString: authorC)
          let metaAuthorName = String(cString: authorNameC)
          let metaBuildTimestamp = String(cString: buildTimestampC)

          // git_hash can be NULL
          var metaGitHash: String? = nil
          if sqlite3_column_type(stmt, 3) != SQLITE_NULL,
             let gitHashC = sqlite3_column_text(stmt, 3)
          {
            metaGitHash = String(cString: gitHashC)
          }

          // json can be NULL
          var metaJson: String? = nil
          if sqlite3_column_type(stmt, 5) != SQLITE_NULL,
             let jsonC = sqlite3_column_text(stmt, 5)
          {
            metaJson = String(cString: jsonC)
          }

          return AuthorMetadata(
            language: metaLang,
            author: metaAuthor,
            authorName: metaAuthorName,
            gitHash: metaGitHash,
            buildTimestamp: metaBuildTimestamp,
            json: metaJson,
          )
        }
      }

      return nil
    } catch {
      return nil
    }
  }

  private func logDatabaseMetadata(lang: String, author: String) {
    guard let meta = metadata(lang: lang, author: author) else {
      cc.ok1(#line, "Database loaded: \(lang):\(author)")
      return
    }

    cc.ok1(
      #line,
      "Database loaded: \(meta.language):\(meta.author) (\(meta.authorName))",
    )
    if let gitHash = meta.gitHash {
      cc.ok2(#line, "  Git: \(gitHash), Built: \(meta.buildTimestamp)")
    }
  }
}

// MARK: - Metadata Type

public struct AuthorMetadata {
  public let language: String
  public let author: String
  public let authorName: String
  public let gitHash: String?
  public let buildTimestamp: String
  public let json: String?
}

// MARK: - Error Type

enum EbtDataError: Error {
  case databaseNotFound(lang: String, author: String)
  case cannotOpenDatabase(lang: String, author: String)
  case decompressionFailed(lang: String, author: String)
}
