import Foundation
import SQLite3

/// Actor providing access to ebt-data.db SQLite database with en/sujato translations
/// Actor ensures thread-safe single-threaded access to SQLite
public actor EbtData {
  public static let shared = EbtData()

  // Safe: OpaquePointer is only accessed within actor-isolated methods and deinit.
  // Actor serialization ensures only one task accesses db at a time.
  private nonisolated(unsafe) var db: OpaquePointer?

  private init() {}

  // MARK: - Database Connection

  /// Lazily opens database connection on first access
  private func ensureDatabase() throws {
    guard db == nil else { return }

    guard let resourceURL = Bundle.module.url(forResource: "ebt-data", withExtension: "db") else {
      throw EbtDataError.databaseNotFound
    }

    var database: OpaquePointer?
    let result = sqlite3_open_v2(
      resourceURL.path,
      &database,
      SQLITE_OPEN_READONLY,
      nil
    )

    guard result == SQLITE_OK else {
      throw EbtDataError.cannotOpenDatabase
    }

    db = database
  }

  deinit {
    // Safe: Actor has no remaining references when deinit runs.
    // db property is nonisolated(unsafe) but only accessed here and in actor methods.
    // sqlite3_close must be called on same thread that opened connection.
    if let database = db {
      sqlite3_close(database)
    }
  }

  // MARK: - Key-based Retrieval

  /// Returns concatenated segments as JSON-like string for given key (e.g., "en/sujato/mn1")
  public func getTranslation(key: String) -> String? {
    do {
      try ensureDatabase()
      guard let db = db else { return nil }

      let query = "SELECT segment_id, segment_text FROM segments WHERE sutta_key = ? ORDER BY segment_id"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return nil
      }

      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)

      var segments: [(String, String)] = []
      while sqlite3_step(stmt) == SQLITE_ROW {
        if let segmentIdC = sqlite3_column_text(stmt, 0),
           let segmentTextC = sqlite3_column_text(stmt, 1) {
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
         let jsonString = String(data: jsonData, encoding: .utf8) {
        return jsonString
      }

      return nil
    } catch {
      return nil
    }
  }

  // MARK: - FTS Keyword Search

  /// Returns sutta keys ranked by relevance percentage (matching_segments / total_segments)
  /// Respects Settings.maxDoc limit
  public func searchKeywords(query: String) -> [String] {
    return searchKeywordsWithScores(query: query).map { $0.key }
  }

  /// Returns sutta keys with match counts and scores for debugging/display
  /// Internal helper that includes scoring details
  func searchKeywordsWithScores(query: String) -> [(key: String, matchCount: Int, totalSegments: Int, relevancePercent: Double, score: Double)] {
    do {
      try ensureDatabase()
      guard let db = db else { return [] }

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

      var results: [(key: String, matchCount: Int, totalSegments: Int, relevancePercent: Double, score: Double)] = []
      while sqlite3_step(stmt) == SQLITE_ROW {
        if let cString = sqlite3_column_text(stmt, 0) {
          let key = String(cString: cString)
          let matchCount = Int(sqlite3_column_int(stmt, 1))
          let totalSegments = Int(sqlite3_column_int(stmt, 2))
          let relevancePercent = sqlite3_column_double(stmt, 3)
          let score = sqlite3_column_double(stmt, 4)
          results.append((key: key, matchCount: matchCount, totalSegments: totalSegments, relevancePercent: relevancePercent, score: score))
        }
      }

      return results
    } catch {
      return []
    }
  }

  // MARK: - Phrase Search

  /// Returns sutta keys ranked by relevance percentage (matching_segments / total_segments)
  /// Filters keyword search results to only those containing exact phrase
  /// Respects Settings.maxDoc limit
  public func searchPhrase(phrase: String) -> [String] {
    do {
      try ensureDatabase()
      guard let db = db else { return [] }

      // Step 1: Get keyword search results (all words present)
      let keywordResults = searchKeywords(query: phrase)

      // Step 2: Filter to only those containing exact phrase
      var phraseMatches: [String] = []

      for suttaKey in keywordResults {
        if containsPhrase(suttaKey: suttaKey, phrase: phrase) {
          phraseMatches.append(suttaKey)
        }
      }

      return phraseMatches
    } catch {
      return []
    }
  }

  /// Helper: Check if sutta contains exact phrase in any segment
  private func containsPhrase(suttaKey: String, phrase: String) -> Bool {
    do {
      try ensureDatabase()
      guard let db = db else { return false }

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

  /// Returns sutta keys ranked by relevance percentage (matching_segments / total_segments)
  /// using regexp pattern matching on segment text
  /// Respects Settings.maxDoc limit
  public func searchRegexp(pattern: String) -> [String] {
    do {
      try ensureDatabase()
      guard let db = db else { return [] }

      // Compile regex
      let regex = try NSRegularExpression(pattern: pattern, options: [])

      // Query all segments
      let query = "SELECT DISTINCT sf.sutta_key, sf.segment_text FROM segments_fts sf"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return []
      }

      defer { sqlite3_finalize(stmt) }

      var matchesBySutta: [String: Int] = [:]  // sutta_key -> match count
      var totalSegmentsBySutta: [String: Int] = [:]  // sutta_key -> total segment count

      while sqlite3_step(stmt) == SQLITE_ROW {
        guard let sutlaKeyC = sqlite3_column_text(stmt, 0),
              let segmentTextC = sqlite3_column_text(stmt, 1) else {
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

      guard sqlite3_prepare_v2(db, totalQuery, -1, &totalStmt, nil) == SQLITE_OK else {
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
        if let totalSegments = totalSegmentsBySutta[suttaKey], totalSegments > 0 {
          let relevancePct = Double(matchCount) / Double(totalSegments)
          let combinedScore = Double(matchCount) + relevancePct
          resultsWithScore.append((key: suttaKey, score: combinedScore))
        }
      }

      return resultsWithScore
        .sorted { $0.score > $1.score }
        .prefix(limit)
        .map { $0.key }
    } catch {
      return []
    }
  }
}

// MARK: - Error Type

enum EbtDataError: Error {
  case databaseNotFound
  case cannotOpenDatabase
}
