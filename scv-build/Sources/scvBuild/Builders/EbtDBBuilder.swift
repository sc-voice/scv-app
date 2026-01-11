import Foundation
import scvCore
import SQLite3

public class EbtDBBuilder {
  let language: String
  let author: String
  let buildDir: String
  let resourcesDir: String
  let translationDir: String
  let authorInfoImporter: AuthorInfoImporter
  let gitHash: String?
  let gitHashTimestamp: String?
  private let cc = ColorConsole(#file, #function, dbg.EbtDBBuilder.other)
  private var lemmatizer: Lemmatizer?

  public init(
    language: String,
    author: String,
    buildDir: String,
    resourcesDir: String,
    translationDir: String,
    authorInfoImporter: AuthorInfoImporter,
    gitHash: String?,
    gitHashTimestamp: String? = nil,
  ) {
    self.language = language
    self.author = author
    self.buildDir = buildDir
    self.resourcesDir = resourcesDir
    self.translationDir = translationDir
    self.authorInfoImporter = authorInfoImporter
    self.gitHash = gitHash
    self.gitHashTimestamp = gitHashTimestamp
  }

  public func buildDatabase() throws -> (suttas: Int, segments: Int) {
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

    // Insert basic metaprops after schema created
    try insertMetaprop(db: db, key: "language", value: language)
    try insertMetaprop(db: db, key: "author", value: author)
    try insertMetaprop(db: db, key: "schema_version", value: String(EbtData.schemaVersion))

    // Insert metadata
    let authorName = authorInfoImporter.getAuthorName(author)
    var jsonString = authorInfoImporter.getAuthorJSON(author)

    // Enrich JSON with authorBaseURL
    let authorBaseURL = getAuthorBaseURL(lang: language, author: author)
    if let jsonStr = jsonString,
       let jsonData = jsonStr.data(using: .utf8),
       var jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    {
      if let baseURL = authorBaseURL {
        jsonDict["authorBaseURL"] = baseURL.absoluteString
      }

      // Serialize back to JSON string
      if let enrichedData = try? JSONSerialization.data(withJSONObject: jsonDict),
         let enrichedStr = String(data: enrichedData, encoding: .utf8)
      {
        jsonString = enrichedStr
      }
    }

    try insertMetadata(
      db: db,
      language: language,
      author: author,
      authorName: authorName,
      gitHash: gitHash,
      jsonString: jsonString,
    )

    // Insert author metaprops
    try insertMetaprop(db: db, key: "author_name", value: authorName)

    // Extract author_type from author JSON if available
    if let jsonStr = jsonString,
       let jsonData = jsonStr.data(using: .utf8),
       let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
       let authorType = jsonDict["type"] as? String
    {
      try insertMetaprop(db: db, key: "author_type", value: authorType)
    }

    // Insert git metaprops
    if let hash = gitHash {
      try insertMetaprop(db: db, key: "git_hash", value: hash)
    }
    if let timestamp = gitHashTimestamp {
      try insertMetaprop(db: db, key: "git_hash_timestamp", value: timestamp)
    }

    // Import translation files
    let importer = EbtFileImporter(
      language: language,
      author: author,
      translationDir: translationDir,
    )

    let (suttas, segments, fileCounts) = try importFiles(db: db, importer: importer)

    // Insert file count metaprops
    try insertMetaprop(db: db, key: "files_sutta", value: String(fileCounts["sutta"] ?? 0))
    try insertMetaprop(db: db, key: "files_vinaya", value: String(fileCounts["vinaya"] ?? 0))
    try insertMetaprop(db: db, key: "files_other", value: String(fileCounts["other"] ?? 0))

    // Save lemmatizer cache after importing all segments
    if var lemmatizer {
      lemmatizer.saveCache()
    }

    // Insert build timestamp metaprop
    let dateFormatter = ISO8601DateFormatter()
    let buildTimestamp = dateFormatter.string(from: Date())
    try insertMetaprop(db: db, key: "build_timestamp", value: buildTimestamp)

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

    CREATE TABLE metaprops (
      key TEXT PRIMARY KEY,
      value TEXT
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

  /// Inserts individual metaprop key/value pair into metaprops table
  /// Uses INSERT OR REPLACE to allow updating existing properties
  /// - Parameters:
  ///   - db: SQLite database pointer
  ///   - key: Property key (e.g., "language", "git_hash")
  ///   - value: Property value as string
  private func insertMetaprop(
    db: OpaquePointer?,
    key: String,
    value: String,
  ) throws {
    let statement = "INSERT OR REPLACE INTO metaprops (key, value) VALUES (?, ?)"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, statement, -1, &stmt, nil) == SQLITE_OK else {
      throw BuildError.cannotPrepareStatement
    }

    sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 2, (value as NSString).utf8String, -1, nil)

    if sqlite3_step(stmt) != SQLITE_DONE {
      sqlite3_finalize(stmt)
      throw BuildError.metadataInsertFailed
    }
    sqlite3_finalize(stmt)
  }

  private func importFiles(
    db: OpaquePointer?,
    importer: EbtFileImporter,
  ) throws -> (suttas: Int, segments: Int, fileCounts: [String: Int]) {
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

    return (suttas: totalSuttas, segments: totalSegments, fileCounts: fileCounts)
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

  public func compressDatabase(dbPath: String) throws {
    let zstPath = "\(resourcesDir)/ebt-\(language)-\(author).db.zst"
    try? FileManager.default.removeItem(atPath: zstPath)

    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = [
      "-c",
      "/opt/homebrew/bin/zstd -f -o \(zstPath) \(dbPath)",
    ]

    // Capture stdout/stderr to prevent pipe deadlock
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

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

  /// Gets the base URL for the author's associated GitHub repository.
  ///
  /// Returns the URL to the author's source data in the appropriate repository:
  /// - For root texts (pli/ms): bilara-data root path
  /// - For translations: bilara-data translation path
  /// - If bilara-data doesn't exist: falls back to ebt-data translation path
  ///
  /// - Parameters:
  ///   - lang: Language code (e.g., "en", "de", "pli")
  ///   - author: Author/translator identifier (e.g., "sujato", "ms")
  /// - Returns: URL to the author's source data repository, or nil if author not found
  public func getAuthorBaseURL(lang: String, author: String) -> URL? {
    // Construct bilara-data URL based on type
    let bilaraDataPath: String
    if author == "ms" {
      bilaraDataPath = "root/\(language)/\(author)"
    } else {
      bilaraDataPath = "translation/\(language)/\(author)"
    }

    let bilaraURL = URL(
      string: "https://github.com/suttacentral/bilara-data/tree/published/\(bilaraDataPath)"
    )!

    // Check if bilara-data URL exists synchronously
    if urlExists(bilaraURL) {
      cc.ok1(#line, #function, bilaraURL.absoluteString)
      return bilaraURL
    }

    // Fall back to ebt-data URL
    let ebtDataURL = URL(
      string: "https://github.com/ebt-site/ebt-data/tree/published/translation/\(language)/\(author)"
    )!
    cc.ok1(#line, #function, ebtDataURL.absoluteString)
    return ebtDataURL
  }

  /// Gets the URL to view a sutta in SuttaCentral or ebt-data repository.
  ///
  /// Returns the URL where the sutta can be viewed or accessed:
  /// - If author base URL is from bilara-data: returns SuttaCentral URL (https://suttacentral.net/...)
  /// - Otherwise: returns ebt-data repository URL
  ///
  /// - Parameter suttaRef: The sutta reference containing suttaUid, language, and author
  /// - Returns: SuttaCentral URL if bilara-data available, ebt-data URL otherwise, or nil if author not found
  public func getSuttaRefURL(suttaRef: SuttaRef) -> URL? {
    guard let author = suttaRef.author else {
      return nil
    }

    let baseURL = getAuthorBaseURL(lang: suttaRef.lang, author: author)!

    // Check if base URL is from bilara-data
    if baseURL.absoluteString.contains("bilara-data") {
      // Return SuttaCentral URL
      let suttaCentralURL = URL(
        string: "https://suttacentral.net/\(suttaRef.suttaUid)/\(suttaRef.lang)/\(author)"
      )!
      cc.ok1(#line, #function, suttaCentralURL.absoluteString)
      return suttaCentralURL
    }

    // Return ebt-data URL (either from baseURL or fallback)
    let ebtDataURL = URL(
      string: "https://github.com/ebt-site/ebt-data/tree/published/translation/\(suttaRef.lang)/\(author)"
    )!
    cc.ok1(#line, #function, ebtDataURL.absoluteString)
    return ebtDataURL
  }

  private func urlExists(_ url: URL) -> Bool {
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    request.timeoutInterval = 5.0  // 5 second timeout

    let semaphore = DispatchSemaphore(value: 0)
    var statusCode: Int? = nil

    let task = URLSession.shared.dataTask(with: request) { _, response, error in
      defer { semaphore.signal() }

      guard error == nil,
            let httpResponse = response as? HTTPURLResponse else {
        return
      }
      statusCode = httpResponse.statusCode
    }

    task.resume()

    // Wait up to 5 seconds for response
    let result = semaphore.wait(timeout: .now() + 5.0)

    if result == .timedOut {
      task.cancel()
      cc.bad1(#line, #function, url.absoluteString)
      return false
    }

    let exists = statusCode == 200
    if exists {
      cc.ok1(#line, #function, "exists:", url.absoluteString)
    } else {
      cc.ok1(#line, #function, "!exists:", url.absoluteString)
    }
    return exists
  }
}

enum BuildError: Error {
  case cannotOpenDatabase(String)
  case schemaCreationFailed(String)
  case cannotPrepareStatement
  case metadataInsertFailed
  case compressionFailed
}
