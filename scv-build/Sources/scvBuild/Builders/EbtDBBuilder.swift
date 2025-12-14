import Foundation
import scvCore
import SQLite3

class EbtDBBuilder {
  let language: String
  let author: String
  let buildDir: String
  let resourcesDir: String
  let translationDir: String
  let authorInfoImporter: AuthorInfoImporter
  let gitHash: String?
  private let cc = ColorConsole(#file, #function, dbg.EbtData.other)
  private var lemmatizer: Lemmatizer?

  init(
    language: String,
    author: String,
    buildDir: String,
    resourcesDir: String,
    translationDir: String,
    authorInfoImporter: AuthorInfoImporter,
    gitHash: String?,
  ) {
    self.language = language
    self.author = author
    self.buildDir = buildDir
    self.resourcesDir = resourcesDir
    self.translationDir = translationDir
    self.authorInfoImporter = authorInfoImporter
    self.gitHash = gitHash
  }

  func build() throws -> (suttas: Int, segments: Int) {
    let startTime = Date()
    let dbPath = "\(buildDir)/ebt-\(language)-\(author).db"
    try? FileManager.default.removeItem(atPath: dbPath)

    cc.ok1(#line, #function, "Building ebt-\(language)-\(author).db...")

    // Initialize lemmatizer for this language
    lemmatizer = Lemmatizer(lang: language, cacheDir: resourcesDir)

    var db: OpaquePointer?
    guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
      throw BuildError.cannotOpenDatabase(dbPath)
    }
    defer { sqlite3_close(db) }

    // Create schema
    try createSchema(db: db)

    // Insert metadata
    let authorName = authorInfoImporter.getAuthorName(author)
    let jsonString = authorInfoImporter.getAuthorJSON(author)

    try insertMetadata(
      db: db,
      language: language,
      author: author,
      authorName: authorName,
      gitHash: gitHash,
      jsonString: jsonString,
    )

    // Import translation files
    let importer = EbtFileImporter(
      language: language,
      author: author,
      translationDir: translationDir,
    )

    let (suttas, segments) = try importFiles(db: db, importer: importer)

    // Save lemmatizer cache after importing all segments
    if var lemmatizer {
      lemmatizer.saveCache()
    }

    // Compress database
    try compressDatabase(dbPath: dbPath)

    let elapsed = Date().timeIntervalSince(startTime)
    cc.ok1(#line, #function, "Elapsed: \(String(format: "%.2f", elapsed))s")

    return (suttas: suttas, segments: segments)
  }

  private func createSchema(db: OpaquePointer?) throws {
    let schema = """
    CREATE TABLE metadata (
      language TEXT,
      author TEXT,
      author_name TEXT,
      git_hash TEXT,
      build_timestamp TEXT,
      files INTEGER,
      files_breakdown TEXT,
      json TEXT,
      schema_version TEXT,
      PRIMARY KEY (language, author)
    );

    CREATE TABLE suttas (
      suttaUid TEXT PRIMARY KEY,
      total_segments INTEGER
    );

    CREATE TABLE segments (
      suttaUid TEXT,
      scid TEXT,
      text TEXT,
      lemmas TEXT
    );
    """

    var errorMessage: UnsafeMutablePointer<CChar>?
    if sqlite3_exec(db, schema, nil, nil, &errorMessage) != SQLITE_OK {
      let message = String(cString: errorMessage!)
      sqlite3_free(errorMessage)
      throw BuildError.schemaCreationFailed(message)
    }
  }

  private func insertMetadata(
    db: OpaquePointer?,
    language: String,
    author: String,
    authorName: String,
    gitHash: String?,
    jsonString: String?,
  ) throws {
    let dateFormatter = ISO8601DateFormatter()
    let buildTimestamp = dateFormatter.string(from: Date())

    let statement =
      "INSERT INTO metadata (language, author, author_name, git_hash, build_timestamp, files, files_breakdown, json, schema_version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, statement, -1, &stmt, nil) == SQLITE_OK else {
      throw BuildError.cannotPrepareStatement
    }

    sqlite3_bind_text(stmt, 1, (language as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 2, (author as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 3, (authorName as NSString).utf8String, -1, nil)
    if let hash = gitHash {
      sqlite3_bind_text(stmt, 4, (hash as NSString).utf8String, -1, nil)
    } else {
      sqlite3_bind_null(stmt, 4)
    }
    sqlite3_bind_text(stmt, 5, (buildTimestamp as NSString).utf8String, -1, nil)
    sqlite3_bind_int(stmt, 6, 0) // files count - will update after import
    sqlite3_bind_null(stmt, 7) // files_breakdown - will update after import
    if let jsonStr = jsonString {
      sqlite3_bind_text(stmt, 8, (jsonStr as NSString).utf8String, -1, nil)
    } else {
      sqlite3_bind_null(stmt, 8)
    }
    let schemaVersionStr = String(EbtData.schemaVersion)
    sqlite3_bind_text(
      stmt,
      9,
      (schemaVersionStr as NSString).utf8String,
      -1,
      nil,
    )

    if sqlite3_step(stmt) != SQLITE_DONE {
      sqlite3_finalize(stmt)
      throw BuildError.metadataInsertFailed
    }
    sqlite3_finalize(stmt)
  }

  private func importFiles(
    db: OpaquePointer?,
    importer: EbtFileImporter,
  ) throws -> (suttas: Int, segments: Int) {
    let files = try importer.findTranslationFiles()

    let insertSuttaStatement = "INSERT OR IGNORE INTO suttas (suttaUid, total_segments) VALUES (?, ?)"
    let insertSegmentStatement = "INSERT INTO segments (suttaUid, scid, text, lemmas) VALUES (?, ?, ?, ?)"

    var suttaStmt: OpaquePointer?
    var segmentStmt: OpaquePointer?

    guard sqlite3_prepare_v2(db, insertSuttaStatement, -1, &suttaStmt, nil) ==
      SQLITE_OK,
      sqlite3_prepare_v2(
        db,
        insertSegmentStatement,
        -1,
        &segmentStmt,
        nil,
      ) ==
      SQLITE_OK
    else {
      throw BuildError.cannotPrepareStatement
    }

    defer {
      sqlite3_finalize(suttaStmt)
      sqlite3_finalize(segmentStmt)
    }

    var totalSuttas = 0
    var totalSegments = 0
    var fileCounts = [
      "sutta": 0,
      "vinaya": 0,
      "abhidhamma": 0,
      "other": 0,
    ]

    for filePath in files.sorted() {
      let segments = try importer.importFile(filePath)

      let fileName = URL(fileURLWithPath: filePath).lastPathComponent
      let baseName = (fileName as NSString).deletingPathExtension
      let components = baseName.split(separator: "_").map(String.init)
      guard let scid = components.first else {
        continue
      }

      // Skip metadata files like "*-name"
      if scid.hasSuffix("-name") {
        continue
      }

      // Determine text type from file path directory
      let textType = classifyTextType(filePath: filePath)
      fileCounts[textType, default: 0] += 1

      // suttaUid is just the scid (language/author stored separately in
      // database path)
      let suttaUid = scid
      let segmentCount = segments.count

      // Insert sutta
      sqlite3_bind_text(
        suttaStmt,
        1,
        (suttaUid as NSString).utf8String,
        -1,
        nil,
      )
      sqlite3_bind_int(suttaStmt, 2, Int32(segmentCount))

      if sqlite3_step(suttaStmt) != SQLITE_DONE {
        cc.bad1(#line, #function, "Insert failed for sutta \(suttaUid)")
        continue
      }
      sqlite3_reset(suttaStmt)
      totalSuttas += 1

      // Insert segments
      for (scidVal, segmentText) in segments.sorted(by: { $0.key < $1.key }) {
        sqlite3_bind_text(
          segmentStmt,
          1,
          (suttaUid as NSString).utf8String,
          -1,
          nil,
        )
        sqlite3_bind_text(
          segmentStmt,
          2,
          (scidVal as NSString).utf8String,
          -1,
          nil,
        )
        sqlite3_bind_text(
          segmentStmt,
          3,
          (segmentText as NSString).utf8String,
          -1,
          nil,
        )
        // lemmas column with space-padded lemmatized tokens
        let lemmas = lemmatizeSegment(segmentText)
        sqlite3_bind_text(
          segmentStmt,
          4,
          (lemmas as NSString).utf8String,
          -1,
          nil,
        )

        if sqlite3_step(segmentStmt) != SQLITE_DONE {
          continue
        }
        sqlite3_reset(segmentStmt)
        totalSegments += 1
      }
    }

    // Store file counts in metadata
    let filesJson = encodeFileCounts(fileCounts, total: files.count)
    try updateMetadataFiles(db: db, filesJson: filesJson)

    let dbSize = try? FileManager.default
      .attributesOfItem(atPath: "\(buildDir)/ebt-\(language)-\(author).db")[
        .size,
      ] as? Int ??
      0
    let dbSizeMB = Double(dbSize ?? 0) / 1_000_000
    cc.ok1(
      #line,
      #function,
      "\(totalSuttas) suttas, \(totalSegments) segments (\(String(format: "%.1f", dbSizeMB)) MB)",
    )

    return (suttas: totalSuttas, segments: totalSegments)
  }

  /// Classifies text type based on file path directory
  /// Files in /sutta/ are classified as sutta
  /// Files in /vinaya/ are classified as vinaya
  private func classifyTextType(filePath: String) -> String {
    if filePath.contains("/vinaya/") {
      return "vinaya"
    } else if filePath.contains("/sutta/") {
      return "sutta"
    }
    return "other"
  }

  /// Encodes file counts as JSON, only including non-zero counts
  private func encodeFileCounts(_ counts: [String: Int], total: Int) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    var dict: [String: Int] = ["total": total]
    // Only add counts that are non-zero
    for (key, count) in counts {
      if count > 0 {
        dict[key] = count
      }
    }
    if let data = try? encoder.encode(dict),
       let jsonString = String(data: data, encoding: .utf8)
    {
      return jsonString
    }
    return "{\"total\": \(total)}"
  }

  /// Updates metadata with file counts
  private func updateMetadataFiles(
    db: OpaquePointer?,
    filesJson: String,
  ) throws {
    guard let database = db else {
      throw BuildError.cannotPrepareStatement
    }

    let query = "UPDATE metadata SET files_breakdown = ? WHERE language = ? AND author = ?"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK
    else {
      throw BuildError.cannotPrepareStatement
    }

    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, (filesJson as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 2, (language as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 3, (author as NSString).utf8String, -1, nil)

    if sqlite3_step(stmt) != SQLITE_DONE {
      throw BuildError.metadataInsertFailed
    }
  }

  private func compressDatabase(dbPath: String) throws {
    let zstPath = "\(resourcesDir)/ebt-\(language)-\(author).db.zst"
    try? FileManager.default.removeItem(atPath: zstPath)

    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = [
      "-c",
      "/opt/homebrew/bin/zstd -f -o \(zstPath) \(dbPath)",
    ]

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
      if let zstSize = try? FileManager.default
        .attributesOfItem(atPath: zstPath)[.size] as? Int
      {
        let zstSizeMB = Double(zstSize) / 1_000_000
        if let dbSize = try? FileManager.default
          .attributesOfItem(atPath: dbPath)[.size] as? Int
        {
          let ratio = (Double(dbSize) - Double(zstSize)) / Double(dbSize) * 100
          cc.ok1(
            #line,
            #function,
            "Compressed to \(String(format: "%.1f", zstSizeMB)) MB (\(String(format: "%.0f", ratio))% reduction)",
          )
        }
      }
    } else {
      throw BuildError.compressionFailed
    }
  }

  /// Lemmatizes text and returns space-padded lowercase lemma tokens
  /// Example: "men shaving their heads" → " man shave their head "
  /// Uses shared Lemmatizer instance for the language
  /// - Parameter text: Text to lemmatize
  /// - Returns: Space-padded string of lowercase lemmatized words
  private func lemmatizeSegment(_ text: String) -> String {
    guard var lemm = lemmatizer else {
      // Fallback if lemmatizer not initialized
      return " " + text + " "
    }
    let result = lemm.lemmatizeForSqlData(text)
    lemmatizer = lemm // Persist cache mutations back to property
    return result
  }
}

enum BuildError: Error {
  case cannotOpenDatabase(String)
  case schemaCreationFailed(String)
  case cannotPrepareStatement
  case metadataInsertFailed
  case compressionFailed
}
