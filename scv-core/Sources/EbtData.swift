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
      // Validate that cached database has FTS table (V2+ format)
      if hasFTSTable(dbURL: dbURL) {
        cc.ok1(#line, "cached:", fileName)
        return dbURL
      } else {
        // Cached database is old format without FTS, delete it
        cc.ok2(#line, "Old cache detected (no FTS), deleting:", fileName)
        try? FileManager.default.removeItem(at: dbURL)
      }
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

    // Check if cached database is stale by comparing timestamps
    checkDatabaseTimestamp(dbURL: dbURL, lang: lang, author: author)

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
  /// "mn1/en/sujato")
  /// Parses suttaId, lang and author from key
  public func getTranslation(suttaKey: String) -> String? {
    let components = suttaKey.split(separator: "/").map(String.init)
    guard components.count >= 3 else { return nil }

    let suttaId = components[0]
    let lang = components[1]
    let author = components[2]

    return getTranslation(lang: lang, author: author, suttaId: suttaId)
  }

  /// Returns concatenated segments as JSON-like string for explicit
  /// suttaId/language/author
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

      // Construct full sutta_key for query: suttaId/lang/author
      let fullSuttaKey = "\(suttaId)/\(lang)/\(author)"
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

  /// Returns MLDocument for a given sutta_key (e.g., "an1.2/en/sujato")
  /// - Parameter suttaKey: Sutta key in format "sutta_uid/lang/author"
  /// - Returns: MLDocument with segments populated, or nil if not found
  public func getMLDocument(suttaKey: String) -> MLDocument? {
    let components = suttaKey.split(separator: "/").map(String.init)
    guard components.count >= 3 else { return nil }

    let suttaId = components[0]
    let lang = components[1]
    let author = components[2]

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

      let fullSuttaKey = "\(suttaId)/\(lang)/\(author)"
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

  /// Keyword search returning SearchResult with metadata and timing
  /// Replacement for searchKeywords() - returns complete search result
  /// - Parameters:
  ///   - lang: Document language (e.g., "en")
  ///   - author: Document author (e.g., "sujato")
  ///   - query: Keyword query string
  /// - Returns: SearchResult with metadata, scored items, and timing
  func searchKeywords2(
    lang: String,
    author: String,
    query: String,
  ) -> SearchResult {
    cc.ok2(
      #line,
      "searchKeywords2 START: query='\(query)' lang=\(lang) author=\(author)",
    )
    let startTime = Date()
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()
    var items: [SearchResultItem] = []
    var searchError: SearchError? = nil

    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { throw NSError() }

      let limit = Settings.shared.maxDoc

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
      let prepareResult = sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil)
      guard prepareResult == SQLITE_OK else {
        let errMsg = String(cString: sqlite3_errmsg(db))
        cc.bad1(#line, "sqlite3_prepare_v2 failed:", errMsg)
        throw NSError()
      }
      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (query as NSString).utf8String, -1, nil)
      sqlite3_bind_int(stmt, 2, Int32(limit))

      // Check if segments_fts table exists and has data
      let tableCheckQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='segments_fts'"
      var tableStmt: OpaquePointer?
      if sqlite3_prepare_v2(db, tableCheckQuery, -1, &tableStmt, nil) ==
        SQLITE_OK
      {
        defer { sqlite3_finalize(tableStmt) }
        let tableExists = sqlite3_step(tableStmt) == SQLITE_ROW
        if tableExists {
          cc.ok1(#line, "segments_fts table exists in cached database")
          // Also check if table has any rows
          let countQuery = "SELECT COUNT(*) FROM segments_fts"
          var countStmt: OpaquePointer?
          if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) ==
            SQLITE_OK
          {
            defer { sqlite3_finalize(countStmt) }
            if sqlite3_step(countStmt) == SQLITE_ROW {
              let rowCount = sqlite3_column_int64(countStmt, 0)
              cc.ok2(#line, "FTS table has \(rowCount) rows")
            }
          }
        } else {
          cc.bad1(#line, "segments_fts table NOT FOUND in cached database")
        }
      } else {
        cc.bad1(#line, "Could not check for segments_fts table in database")
      }

      cc.ok2(#line, "Executing FTS MATCH query: '\(query)' with limit \(limit)")

      var resultCount = 0
      while sqlite3_step(stmt) == SQLITE_ROW {
        if let cString = sqlite3_column_text(stmt, 0) {
          let key = String(cString: cString)
          let score = sqlite3_column_double(stmt, 4)
          if let suttaRef = createSuttaRefFromKey(key) {
            items.append(SearchResultItem(suttaRef: suttaRef, score: score))
            resultCount += 1
          }
        }
      }

      // Diagnostic: if no results, try a simpler query
      if resultCount == 0 {
        cc.ok2(#line, "FTS MATCH returned 0 results, running diagnostics")

        // Check FTS table schema
        let schemaQuery = "PRAGMA table_info(segments_fts)"
        var schemaStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, schemaQuery, -1, &schemaStmt, nil) ==
          SQLITE_OK
        {
          defer { sqlite3_finalize(schemaStmt) }
          var schemaInfo = ""
          while sqlite3_step(schemaStmt) == SQLITE_ROW {
            if let colName = sqlite3_column_text(schemaStmt, 1) {
              let name = String(cString: colName)
              schemaInfo += "\(name);"
            }
          }
          cc.ok2(#line, "FTS schema columns: \(schemaInfo)")
        }

        // Try a simple unqualified MATCH on the FTS table
        let simpleMatch = "SELECT COUNT(*) FROM segments_fts WHERE segments_fts MATCH ?"
        var simpleStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, simpleMatch, -1, &simpleStmt, nil) ==
          SQLITE_OK
        {
          defer { sqlite3_finalize(simpleStmt) }
          sqlite3_bind_text(
            simpleStmt,
            1,
            ("root" as NSString).utf8String,
            -1,
            nil,
          )
          if sqlite3_step(simpleStmt) == SQLITE_ROW {
            let simpleCount = sqlite3_column_int64(simpleStmt, 0)
            cc.ok2(#line, "Simple FTS MATCH count for 'root': \(simpleCount)")
          }
        }

        // Check if any rows can be retrieved without MATCH
        let plainQuery = "SELECT sutta_key FROM segments_fts LIMIT 1"
        var plainStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, plainQuery, -1, &plainStmt, nil) ==
          SQLITE_OK
        {
          defer { sqlite3_finalize(plainStmt) }
          if sqlite3_step(plainStmt) == SQLITE_ROW {
            if let key = sqlite3_column_text(plainStmt, 0) {
              cc.ok2(#line, "Sample FTS row: \(String(cString: key))")
            }
          }
        }

        // Check if suttas table exists
        let suttasCheckQuery =
          "SELECT name FROM sqlite_master WHERE type='table' AND name='suttas'"
        var suttasCheckStmt: OpaquePointer?
        if sqlite3_prepare_v2(
          db,
          suttasCheckQuery,
          -1,
          &suttasCheckStmt,
          nil,
        ) ==
          SQLITE_OK
        {
          defer { sqlite3_finalize(suttasCheckStmt) }
          let suttasExists = sqlite3_step(suttasCheckStmt) == SQLITE_ROW
          if suttasExists {
            cc.ok2(#line, "suttas table EXISTS")

            // Check row count in suttas
            let suttaCountQuery = "SELECT COUNT(*) FROM suttas"
            var suttaCountStmt: OpaquePointer?
            if sqlite3_prepare_v2(
              db,
              suttaCountQuery,
              -1,
              &suttaCountStmt,
              nil,
            ) ==
              SQLITE_OK
            {
              defer { sqlite3_finalize(suttaCountStmt) }
              if sqlite3_step(suttaCountStmt) == SQLITE_ROW {
                let suttaCount = sqlite3_column_int64(suttaCountStmt, 0)
                cc.ok2(#line, "suttas table has \(suttaCount) rows")
              }
            }

            // Check schema
            let suttaSchemaQuery = "PRAGMA table_info(suttas)"
            var suttaSchemaStmt: OpaquePointer?
            if sqlite3_prepare_v2(
              db,
              suttaSchemaQuery,
              -1,
              &suttaSchemaStmt,
              nil,
            ) ==
              SQLITE_OK
            {
              defer { sqlite3_finalize(suttaSchemaStmt) }
              var suttaSchemaInfo = ""
              while sqlite3_step(suttaSchemaStmt) == SQLITE_ROW {
                if let colName = sqlite3_column_text(suttaSchemaStmt, 1) {
                  let name = String(cString: colName)
                  suttaSchemaInfo += "\(name);"
                }
              }
              cc.ok2(#line, "suttas schema: \(suttaSchemaInfo)")
            }

            // Try the join
            let joinQuery =
              "SELECT COUNT(*) FROM segments_fts sf JOIN suttas s ON sf.sutta_key = s.sutta_key WHERE sf.segment_text MATCH ? LIMIT 1"
            var joinStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, joinQuery, -1, &joinStmt, nil) ==
              SQLITE_OK
            {
              defer { sqlite3_finalize(joinStmt) }
              sqlite3_bind_text(
                joinStmt,
                1,
                ("root" as NSString).utf8String,
                -1,
                nil,
              )
              if sqlite3_step(joinStmt) == SQLITE_ROW {
                let joinCount = sqlite3_column_int64(joinStmt, 0)
                cc.ok2(#line, "JOIN result count for 'root': \(joinCount)")
              }
            }
          } else {
            cc.bad1(
              #line,
              "suttas table DOES NOT EXIST - database is missing critical table!",
            )
          }
        }
      }
    } catch {
      searchError = SearchError(
        message: "search.error.failed".localized,
        detail: error.localizedDescription,
      )
      cc.bad1(#line, "Search failed:", error.localizedDescription)
    }

    let elapsedTime = CFAbsoluteTimeGetCurrent() - elapsedAtStart
    cc.ok1(
      #line,
      "Found \(items.count) results in \(String(format: "%.3f", elapsedTime))s",
    )

    let metadata = SearchMetadata(
      query: query,
      method: .keyword,
      elapsedTime: elapsedTime,
      docLang: lang,
      docAuthor: author,
    )

    return SearchResult(metadata: metadata, results: items, error: searchError)
  }

  // MARK: - Phrase Search

  /// Returns complete search result for exact phrase matches
  /// Filters keyword search results to only those containing exact phrase
  /// Preserves scores from keyword search
  /// - Parameters:
  ///   - lang: Document language (e.g., "en")
  ///   - author: Document author (e.g., "sujato")
  ///   - phrase: Phrase query string
  /// - Returns: SearchResult with metadata and scored items
  func searchPhrase2(lang: String, author: String,
                     phrase: String) -> SearchResult
  {
    let startTime = Date()
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()

    do {
      try ensureDatabase(lang: lang, author: author)
    } catch {
      let elapsedTime = CFAbsoluteTimeGetCurrent() - elapsedAtStart
      return SearchResult(
        metadata: SearchMetadata(
          query: phrase,
          method: .phrase,
          elapsedTime: elapsedTime,
          docLang: lang,
          docAuthor: author,
        ),
        results: [],
        error: SearchError(
          message: "search.error.failed".localized,
          detail: "Failed to initialize database",
        ),
      )
    }

    // Get keyword search results as starting point
    var result = searchKeywords2(
      lang: lang,
      author: author,
      query: phrase,
    )

    // Filter to only those containing exact phrase
    result.results = result.results.filter { item in
      let suttaRef = item.suttaRef
      let suttaKey = "\(suttaRef.suttaUid)/\(suttaRef.lang)/\(suttaRef.author ?? "")"
      return containsPhrase(
        lang: lang,
        author: author,
        suttaKey: suttaKey,
        phrase: phrase,
      )
    }

    // Update metadata to reflect phrase search with actual elapsed time
    let elapsedTime = CFAbsoluteTimeGetCurrent() - elapsedAtStart
    result.metadata.timestamp = startTime
    result.metadata.method = .phrase
    result.metadata.elapsedTime = elapsedTime

    return result
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
  func searchRegexp(lang: String, author: String,
                    pattern: String) -> [SuttaRef]
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
        .compactMap { createSuttaRefFromKey($0.key) }
    } catch {
      return []
    }
  }

  // MARK: - Unified Search

  /// Auto-detects search method based on query string content
  /// Attempts to parse as comma-delimited SuttaRef list first
  /// Falls back to regexp if metacharacters detected
  /// Defaults to phrase search for natural text
  /// - Parameters:
  ///   - query: Search query string
  ///   - docLang: Document language for SuttaRef parsing
  ///   - docAuthor: Document author for SuttaRef parsing
  /// - Returns: SearchMethodDetection with method and pre-parsed items
  public nonisolated func autoSearchMethod(
    _ query: String,
    docLang: String,
    docAuthor: String,
  ) -> SearchMethodDetection {
    let trimmed = query.trimmingCharacters(in: .whitespaces)

    let entries = trimmed.split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }

    // Case: Empty query → default to phrase search
    if entries.isEmpty {
      return SearchMethodDetection(method: .phrase, items: [])
    }

    // Try to parse all entries as SuttaRef
    var items: [SearchResultItem] = []
    for entry in entries {
      if let suttaRef = SuttaRef.create(
        entry,
        defaultLang: docLang,
        defaultAuthor: docAuthor,
      ) {
        items.append(SearchResultItem(suttaRef: suttaRef, score: 1.0))
      }
    }

    let suttaRefCount = items.count

    // Case 2: All entries parsed successfully → use .suttaref
    if suttaRefCount == entries.count, suttaRefCount > 0 {
      return SearchMethodDetection(method: .suttaref, items: items)
    }

    // Case 1 or 3: No entries parsed or partial parse failure
    // Check for regexp in original query first
    if containsRegexpMetacharacters(trimmed) {
      return SearchMethodDetection(method: .regexp, items: [])
    }

    // Default to phrase search
    return SearchMethodDetection(method: .phrase, items: [])
  }

  /// Checks if string contains basic regexp metacharacters (. + * ^ $)
  private nonisolated func containsRegexpMetacharacters(_ str: String)
    -> Bool
  {
    let regexpChars = CharacterSet(
      charactersIn: ".*+^$",
    )
    return str.unicodeScalars.contains { regexpChars.contains($0) }
  }

  // MARK: - Unified Search

  /// Performs unified search with auto-detection or explicit method
  /// - Parameters:
  ///   - query: Search query string
  ///   - docLang: Document language (default from Settings)
  ///   - docAuthor: Document author (default from Settings)
  ///   - method: Optional explicit search method (auto-detect if nil)
  ///   - maxResults: Maximum results limit (default from Settings.maxDoc)
  /// - Returns: SearchResult with metadata and items
  public func search(
    query: String,
    docLang: String = Settings.shared.docLang.code,
    docAuthor: String = Settings.shared.docAuthor,
    refLang: String = Settings.shared.refLang.code,
    refAuthor: String? = Settings.shared.refAuthor,
    method: SearchMethod? = nil,
    maxResults: Int = Settings.shared.maxDoc,
  ) -> SearchResult {
    cc.ok2(
      #line,
      "search: query=\(query) docLang=\(docLang) docAuthor='\(docAuthor)' refLang=\(refLang) refAuthor=\(refAuthor ?? "nil")",
    )

    // Auto-detect method if not provided
    let detection = autoSearchMethod(
      query,
      docLang: docLang,
      docAuthor: docAuthor,
    )
    let searchMethod = method ?? detection.method

    // Handle phrase and keyword searches directly
    switch searchMethod {
    case .phrase:
      return searchPhrase2(lang: docLang, author: docAuthor, phrase: query)
    case .keyword:
      return searchKeywords2(lang: docLang, author: docAuthor, query: query)
    case .suttaref, .regexp:
      // Delegate other searches to searchOld
      return searchOld(
        query: query,
        docLang: docLang,
        docAuthor: docAuthor,
        refLang: refLang,
        refAuthor: refAuthor,
        method: searchMethod,
        items: detection.items,
        maxResults: maxResults,
      )
    }
  }

  private func searchOld(
    query: String,
    docLang: String,
    docAuthor: String,
    refLang: String,
    refAuthor: String?,
    method: SearchMethod,
    items: [SearchResultItem],
    maxResults: Int,
  ) -> SearchResult {
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()

    // Execute search based on method
    let resultItems: [SearchResultItem] = switch method {
    case .suttaref:
      performSuttarefSearch(items, maxResults: maxResults)
    case .regexp:
      performRegexpSearch(
        query,
        docLang: docLang,
        docAuthor: docAuthor,
        maxResults: maxResults,
      )
    case .phrase, .keyword:
      // Should not reach here - handled directly in search()
      []
    }

    let elapsedTime = CFAbsoluteTimeGetCurrent() - elapsedAtStart

    let metadata = SearchMetadata(
      query: query,
      method: method,
      elapsedTime: elapsedTime,
      docLang: docLang,
      docAuthor: docAuthor,
      refLang: refLang,
      refAuthor: refAuthor,
      maxDoc: maxResults,
    )

    return SearchResult(metadata: metadata, results: resultItems)
  }

  // MARK: - Search Handlers

  /// Handles .suttaref search using pre-parsed items
  private func performSuttarefSearch(
    _ items: [SearchResultItem],
    maxResults: Int,
  ) -> [SearchResultItem] {
    Array(items.prefix(maxResults))
  }

  /// Handles .regexp search
  private func performRegexpSearch(
    _ pattern: String,
    docLang: String,
    docAuthor: String,
    maxResults: Int,
  ) -> [SearchResultItem] {
    let regexpKeys = searchRegexp(
      lang: docLang,
      author: docAuthor,
      pattern: pattern,
    )

    return regexpKeys
      .prefix(maxResults)
      .map { key in
        SearchResultItem(suttaRef: key, score: 1.0)
      }
  }

  /// Creates SuttaRef from sutta key format (e.g., "mn1/en/sujato")
  private func createSuttaRefFromKey(_ key: String) -> SuttaRef? {
    SuttaRef.create(key)
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

  /// Fetches first matching segment for a search result item and populates the
  /// quote
  /// - Parameters:
  ///   - item: SearchResultItem to populate with quote
  ///   - query: Search query string
  ///   - method: Search method used (keyword, phrase, regexp, suttaref)
  ///   - lang: Document language
  ///   - author: Document author
  /// - Returns: Updated SearchResultItem with quote populated (or nil if
  /// segment not found)
  public func populateQuote(
    item: inout SearchResultItem,
    query: String,
    method: SearchMethod,
    lang: String,
    author: String,
  ) -> Bool {
    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { return false }

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
    } catch {
      return false
    }
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

    // Extract parts
    let beforeMatch = String(fullText[contextStart ..< matchRange.lowerBound])
    let matchedText = String(fullText[matchRange])
    let afterMatch = String(fullText[matchRange.upperBound ..< contextEnd])

    // HTML escape function
    func htmlEscape(_ str: String) -> String {
      str
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // Build HTML
    let html = "\(prefixEllipsis)\(htmlEscape(beforeMatch))<span>\(htmlEscape(matchedText))</span>\(htmlEscape(afterMatch))\(suffixEllipsis)"
    return html
  }

  /// Clears cached database connections (for testing after database files are
  /// rebuilt)
  public func clearDatabaseCache() {
    for (_, dbPointer) in databases {
      if let db = dbPointer {
        sqlite3_close(db)
      }
    }
    databases.removeAll()
  }

  /// Checks if a database file is valid V2+ format (has FTS and correct
  /// sutta_key format)
  /// Returns false for old V1 format or databases with malformed sutta_key
  private func hasFTSTable(dbURL: URL) -> Bool {
    var db: OpaquePointer?
    let openResult = sqlite3_open_v2(
      dbURL.path,
      &db,
      SQLITE_OPEN_READONLY,
      nil,
    )

    guard openResult == SQLITE_OK, let database = db else {
      cc.ok2(#line, "Could not open database to check FTS table")
      return false
    }

    defer { sqlite3_close(database) }

    let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='segments_fts'"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK
    else {
      cc.ok2(#line, "Could not prepare FTS table check query")
      return false
    }

    defer { sqlite3_finalize(stmt) }

    let tableExists = sqlite3_step(stmt) == SQLITE_ROW
    if !tableExists {
      cc.ok2(#line, "Database missing FTS table - old V1 format detected")
      return false
    }

    // Check that sutta_key format is correct (should start with sutta_uid, not
    // lang)
    let sampleQuery = "SELECT sutta_key FROM segments_fts LIMIT 1"
    var sampleStmt: OpaquePointer?
    if sqlite3_prepare_v2(database, sampleQuery, -1, &sampleStmt, nil) ==
      SQLITE_OK
    {
      defer { sqlite3_finalize(sampleStmt) }
      if sqlite3_step(sampleStmt) == SQLITE_ROW {
        if let keyText = sqlite3_column_text(sampleStmt, 0) {
          let key = String(cString: keyText)
          // Malformed: "en/sujato/an1.1-10", Correct: "an1.1-10/en/sujato"
          let keyParts = key.split(separator: "/")
          if keyParts.count >= 2 {
            let firstPart = String(keyParts[0])
            // If first part is exactly 2 lowercase letters, it's a lang code
            // (malformed)
            if firstPart.count == 2, firstPart.allSatisfy(\.isLowercase) {
              cc.ok2(
                #line,
                "Database has malformed sutta_key: '\(key)' - lang before sutta_uid",
              )
              return false
            }
          }
        }
      }
    }

    return tableExists
  }

  private func checkDatabaseTimestamp(dbURL: URL, lang: String,
                                      author: String)
  {
    do {
      let fileAttributes = try FileManager.default
        .attributesOfItem(atPath: dbURL.path)
      guard let fileModDate = fileAttributes[.modificationDate] as? Date else {
        cc.bad1(#line, "Could not get file modification date")
        return
      }

      // Get expected build timestamp from manifest
      guard let manifest = DatabaseManifest.load() else {
        cc.bad1(#line, "Could not load manifest")
        return
      }

      guard let dbInfo = manifest.info(language: lang, author: author) else {
        cc.bad1(#line, "No manifest entry for \(lang)/\(author)")
        return
      }

      // Parse ISO 8601 timestamp from manifest (e.g., "2025-11-15T15:51:01Z")
      let formatter = ISO8601DateFormatter()
      guard let expectedDate = formatter.date(from: dbInfo.buildTimestamp)
      else {
        cc.bad1(
          #line,
          "Could not parse manifest timestamp: \(dbInfo.buildTimestamp)",
        )
        return
      }

      // Compare timestamps
      let isStale = fileModDate < expectedDate
      cc.ok1(
        #line,
        "Database timestamp: cached=\(fileModDate.description) expected=\(expectedDate.description) stale=\(isStale)",
      )
    } catch {
      cc.bad1(
        #line,
        "Error checking database timestamp:",
        error.localizedDescription,
      )
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
