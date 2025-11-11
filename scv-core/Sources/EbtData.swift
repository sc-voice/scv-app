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

  /// Returns raw JSON translation for given key (e.g., "en/sujato/mn1")
  public func getTranslation(key: String) -> String? {
    do {
      try ensureDatabase()
      guard let db = db else { return nil }

      let query = "SELECT json FROM translations WHERE key = ?"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return nil
      }

      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)

      if sqlite3_step(stmt) == SQLITE_ROW {
        if let cString = sqlite3_column_text(stmt, 0) {
          return String(cString: cString)
        }
      }

      return nil
    } catch {
      return nil
    }
  }

  // MARK: - FTS Keyword Search

  /// Returns keys of translations matching FTS keyword search
  /// Respects Settings.maxDoc limit
  public func searchKeywords(query: String) -> [String] {
    do {
      try ensureDatabase()
      guard let db = db else { return [] }

      let limit = Settings.shared.maxDoc
      let ftQuery = "SELECT key FROM translations_fts WHERE json MATCH ? LIMIT ?"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, ftQuery, -1, &stmt, nil) == SQLITE_OK else {
        return []
      }

      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (query as NSString).utf8String, -1, nil)
      sqlite3_bind_int(stmt, 2, Int32(limit))

      var results: [String] = []
      while sqlite3_step(stmt) == SQLITE_ROW {
        if let cString = sqlite3_column_text(stmt, 0) {
          results.append(String(cString: cString))
        }
      }

      return results
    } catch {
      return []
    }
  }

  // MARK: - Regexp Search

  /// Returns keys of translations matching regexp pattern
  /// Respects Settings.maxDoc limit
  public func searchRegexp(pattern: String) -> [String] {
    do {
      try ensureDatabase()
      guard let db = db else { return [] }

      let query = "SELECT key, json FROM translations"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return []
      }

      defer { sqlite3_finalize(stmt) }

      // Compile regex
      let regex = try NSRegularExpression(pattern: pattern, options: [])

      var results: [String] = []
      let limit = Settings.shared.maxDoc

      while sqlite3_step(stmt) == SQLITE_ROW && results.count < limit {
        guard let keyC = sqlite3_column_text(stmt, 0),
              let jsonC = sqlite3_column_text(stmt, 1) else {
          continue
        }

        let key = String(cString: keyC)
        let json = String(cString: jsonC)

        let range = NSRange(json.startIndex..., in: json)
        if regex.firstMatch(in: json, options: [], range: range) != nil {
          results.append(key)
        }
      }

      return results
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
