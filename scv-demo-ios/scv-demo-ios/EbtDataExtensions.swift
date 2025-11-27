//
//  EbtDataExtensions.swift
//  scv-demo-ios
//
//  Extension providing searchKeywordsWithScores for demo app
//

import scvCore
import SQLite3

public extension EbtData {
  /// Returns sutta keys with match counts and scores for debugging/display
  /// Includes scoring details for display purposes
  func searchKeywordsWithScores(
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
}
