import Foundation
import SQLite3

/// Actor providing access to per-author SQLite databases
/// (ebt-{lang}-{author}.db)
/// Each author has separate database containing segments and metadata
/// Actor ensures thread-safe single-threaded access to SQLite
public actor EbtData {
  public let cc = ColorConsole(#file, #function, dbg.EbtData.other)
  public static let shared = EbtData()

  public nonisolated let lang: String?
  public nonisolated let author: String?
  private let db: OpaquePointer?

  /// Database schema version - increment when changing how data is interpreted
  /// Must match schema_version in database metadata table
  /// V5: Added files field with breakdown (sutta/vinaya/abhidhamma/other
  /// counts)
  /// V6: Renamed columns (sutta_key→suttaUid, segment_id→scid,
  /// segment_text→text),
  /// added space-padded lemmas column, removed FTS5 virtual table
  public static let schemaVersion = 6

  // Safe: Dictionary is only accessed within actor-isolated methods and deinit.
  // Actor serialization ensures only one task accesses databases at a time.
  // Key format: "lang/author" (e.g., "en/sujato", "de/sabbamitta")
  private nonisolated(unsafe) var databases: [String: OpaquePointer] = [:]

  // Safe: EbtSeeker instances are only accessed within actor-isolated methods.
  // Actor serialization ensures only one task accesses seekerCache at a time.
  // nonisolated(unsafe) is used because seekerCache holds references to
  // EbtSeeker actors,
  // which would otherwise create isolation boundary issues. The actor's
  // serialization
  // ensures thread-safety despite the unsafe annotation.
  // Key format: "lang/author" (e.g., "en/sujato", "de/sabbamitta")
  private nonisolated(unsafe) var seekerCache: [String: EbtSeeker] = [:]

  // Safe: Lemmatizer instances are language-specific singletons accessed
  // within actor-isolated methods. nonisolated(unsafe) is safe because
  // Lemmatizer is thread-safe (immutable after initialization).
  // Key format: language code (e.g., "en", "de", "pli")
  private nonisolated(unsafe) var lemmatizers: [String: Lemmatizer] = [:]

  // Manifest loaded once at app startup
  private nonisolated(unsafe) static let manifestCache: DatabaseManifest =
    .shared

  private nonisolated(unsafe) static var instanceCache: [String: EbtData] = [:]

  // Factory for instance tied to lang/author database
  public static func forLangAuthor(lang: String?, author: String?,
                                   settings: Settings = Settings
                                     .shared) async -> EbtData?
  {
    let cc = ColorConsole(#file, #function, dbg.EbtData.other)
    let langActual = lang ?? settings.docLang.rawValue ?? "en"
    let authorActual = author ?? manifestCache
      .defaultAuthorForLanguage(langActual)?.author ?? ""
    let cacheKey = "\(langActual)/\(authorActual)"
    var e7a = instanceCache[cacheKey]
    if e7a != nil {
      cc.ok1(#line, #function, langActual, authorActual, "(cached)")
      return e7a
    }

    do {
      try await EbtData.shared.ensureDatabase(
        lang: langActual,
        author: authorActual,
      )
    } catch {
      cc.bad1(
        #line,
        #function,
        langActual,
        authorActual,
        error.localizedDescription,
      )
      return nil
    }

    let db = EbtData.shared.databases[cacheKey]
    e7a = EbtData(lang: langActual, author: authorActual, db: db)
    instanceCache[cacheKey] = e7a

    cc.ok1(#line, #function, langActual, authorActual, "(new)")
    return e7a
  }

  /// Factory for creating lightweight EbtDb reference to lang/author database
  /// EbtDb provides synchronous-like access by delegating to the EbtData actor
  /// - Parameters:
  ///   - lang: Language code (e.g., "en", "de"), defaults to user's doc
  /// language
  ///   - author: Author identifier (e.g., "sujato"), defaults to manifest
  /// default
  /// - Returns: EbtDb instance, or nil if database cannot be loaded
  public static func dbForLangAuthor(lang: String?, author: String?,
                                     settings: Settings = Settings
                                       .shared) async -> EbtDb?
  {
    let cc = ColorConsole(#file, #function, dbg.EbtData.other)
    let langActual = lang ?? settings.docLang.rawValue ?? "en"
    let authorActual = author ?? manifestCache
      .defaultAuthorForLanguage(langActual)?.author ?? ""

    do {
      try await EbtData.shared.ensureDatabase(
        lang: langActual,
        author: authorActual,
      )
    } catch {
      cc.bad1(
        #line,
        #function,
        langActual,
        authorActual,
        error.localizedDescription,
      )
      return nil
    }

    let db = EbtDb(lang: langActual, author: authorActual, manager: .shared)
    cc.ok1(#line, #function, langActual, authorActual)
    return db
  }

  /// Static convenience method to get MLDocument for a SuttaRef
  /// Uses factory to create/retrieve instance for the suttaRef's lang/author
  /// - Parameter suttaRef: SuttaRef containing language, author, and sutta
  /// identifier
  /// - Returns: MLDocument with segments populated, or nil if not found or
  /// instance creation fails
  public static func getMLDocument(suttaRef: SuttaRef) async -> MLDocument? {
    guard let ebtData = await forLangAuthor(
      lang: suttaRef.lang,
      author: suttaRef.author,
    ) else {
      return nil
    }
    return await ebtData.getMLDocument(suttaRef: suttaRef)
  }

  /// Static convenience method to get segments for a SuttaRef
  /// Uses factory to create/retrieve instance for the suttaRef's lang/author
  /// - Parameter suttaRef: SuttaRef containing language, author, and sutta
  /// identifier
  /// - Returns: Array of Segment objects for the sutta, or empty array if not
  /// found
  public static func segmentsOfSuttaRef(_ suttaRef: SuttaRef) async
    -> [Segment]
  {
    guard let ebtData = await forLangAuthor(
      lang: suttaRef.lang,
      author: suttaRef.author,
    ) else {
      return []
    }
    return await ebtData.segmentsOfSuttaRef(suttaRef)
  }

  /// Static convenience method to check if a SuttaRef exists
  /// Uses factory to create/retrieve instance for the suttaRef's lang/author
  /// - Parameter suttaRef: SuttaRef containing language, author, and sutta
  /// identifier
  /// - Returns: true if sutta exists in database, false otherwise
  public static func suttaRefExists(suttaRef: SuttaRef) async -> Bool {
    guard let ebtData = await forLangAuthor(
      lang: suttaRef.lang,
      author: suttaRef.author,
    ) else {
      return false
    }
    return await ebtData.querySuttaRefExists(suttaRef: suttaRef)
  }

  /// Static convenience method to get EbtSeeker for a specific language and
  /// author
  /// Uses factory to create/retrieve instance for the lang/author pair
  /// - Parameters:
  ///   - lang: Language code
  ///   - author: Author/translator code
  /// - Returns: EbtSeeker instance, or throws if instance creation fails
  public static func getSeeker(lang: String,
                               author: String) async throws -> EbtSeeker
  {
    guard let ebtData = await forLangAuthor(lang: lang, author: author) else {
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }
    return try await ebtData.getSeeker(lang: lang, author: author)
  }

  /// Static convenience method to get EbtSeeker for a SuttaRef
  /// Uses factory to create/retrieve instance for the suttaRef's lang/author
  /// - Parameter suttaRef: SuttaRef containing language, author, and sutta
  /// identifier
  /// - Returns: EbtSeeker instance, or throws if instance creation fails
  public static func getSeeker(suttaRef: SuttaRef) async throws -> EbtSeeker {
    guard let ebtData = await forLangAuthor(
      lang: suttaRef.lang,
      author: suttaRef.author,
    ) else {
      throw EbtDataError.cannotOpenDatabase(
        lang: suttaRef.lang ?? "unknown",
        author: suttaRef.author ?? "unknown",
      )
    }
    return try await ebtData.getSeeker(suttaRef: suttaRef)
  }

  /// Static convenience method to get database schema version for a
  /// language/author pair
  /// Uses factory to create/retrieve instance for the lang/author pair
  /// - Parameters:
  ///   - lang: Language code
  ///   - author: Author/translator code
  /// - Returns: Schema version string, or throws if instance creation fails
  public static func getDatabaseSchemaVersion(
    lang: String,
    author: String,
  ) async throws -> String {
    guard let ebtData = await forLangAuthor(lang: lang, author: author) else {
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }
    return try await ebtData.getDatabaseSchemaVersion(
      lang: lang,
      author: author,
    )
  }

  /// Static convenience method to get sutta UIDs for a language/author pair
  /// Uses factory to create/retrieve instance for the lang/author pair
  /// - Parameters:
  ///   - lang: Language code
  ///   - author: Author/translator code
  /// - Returns: Array of sutta UIDs, or empty array if instance creation fails
  public static func suttaUidsForAuthor(lang: String,
                                        author: String) async -> [String]
  {
    guard let ebtData = await forLangAuthor(lang: lang, author: author) else {
      return []
    }
    return await ebtData.suttaUidsForAuthor(lang: lang, author: author)
  }

  /// Static convenience method to search for lemmatized phrases
  /// Uses factory to create/retrieve instance for the lang/author pair
  /// - Parameters:
  ///   - lang: Language code
  ///   - author: Author/translator code
  ///   - lemmaWords: Array of lemmatized words to search for
  ///   - query: Original query string for metadata
  ///   - maxDoc: Maximum results limit
  /// - Returns: SeekerResult with matching suttas, or empty result if instance
  /// creation fails
  public static func searchLemma(
    lang: String,
    author: String,
    lemmaWords: [String],
    query: String,
    maxDoc: Int = MAX_DOC_DEFAULT,
  ) async -> SeekerResult {
    guard let ebtData = await forLangAuthor(lang: lang, author: author) else {
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
    return await ebtData.searchLemma(
      lang: lang,
      author: author,
      lemmaWords: lemmaWords,
      query: query,
      maxDoc: maxDoc,
    )
  }

  private init(
    lang: String? = nil,
    author: String? = nil,
    db: OpaquePointer? = nil,
  ) {
    self.lang = lang
    self.author = author
    self.db = db
  }

  // MARK: - Manifest Access

  /// Returns loaded database manifest
  /// Fast lookup without decompressing databases
  public nonisolated static func manifest() -> DatabaseManifest {
    manifestCache
  }

  /// Returns all available database info from manifest
  public nonisolated static func availableDatabasesFromManifest()
    -> [DatabaseInfo]
  {
    manifestCache.databases
  }

  /// Returns authors available for specific language from manifest
  public nonisolated static func authorsForLanguageFromManifest(
    _ language: String,
  )
    -> [DatabaseInfo]
  {
    manifestCache.authorsForLanguage(language)
  }

  // MARK: - Lemmatizer Access

  /// Returns path to bundle resources directory where caches and databases are
  /// stored
  private var resourcesDir: String {
    let bundlePath = Bundle.module.bundlePath
    return "\(bundlePath)/resources"
  }

  /// Returns cached Lemmatizer singleton for specific language
  /// Creates and caches new instance on first access
  /// - Parameter lang: Language code (e.g., "en", "de", "pli")
  /// - Returns: Lemmatizer instance for the language
  func getLemmatizer(lang: String) -> Lemmatizer {
    if let existing = lemmatizers[lang] {
      return existing
    }

    let lemmatizer = Lemmatizer(lang: lang, cacheDir: resourcesDir)
    lemmatizers[lang] = lemmatizer
    return lemmatizer
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

  /// Returns schema_version from database metadata for testing/validation
  public func getDatabaseSchemaVersion(lang: String,
                                       author: String) throws -> String
  {
    let dbURL = try ensureDecompressed(lang: lang, author: author)

    var db: OpaquePointer?
    let openResult = sqlite3_open_v2(
      dbURL.path,
      &db,
      SQLITE_OPEN_READONLY,
      nil,
    )

    guard openResult == SQLITE_OK, let database = db else {
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }

    defer { sqlite3_close(database) }

    let query = "SELECT schema_version FROM metadata LIMIT 1"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK
    else {
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }

    defer { sqlite3_finalize(stmt) }

    guard sqlite3_step(stmt) == SQLITE_ROW,
          sqlite3_column_type(stmt, 0) != SQLITE_NULL,
          let versionText = sqlite3_column_text(stmt, 0)
    else {
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }

    return String(cString: versionText)
  }

  /// Returns path to decompressed database in Caches, decompressing if needed
  private func ensureDecompressed(lang: String, author: String) throws -> URL {
    let fileName = "ebt-\(lang)-\(author).db"
    cc.ok2(#line, #function, fileName)
    let cacheURL = FileManager.default.urls(
      for: .cachesDirectory,
      in: .userDomainMask,
    )[0]
    let dbURL = cacheURL.appendingPathComponent(fileName)
    cc.ok2(#line, #function, "cacheURL", cacheURL, "dbURL", dbURL)

    // Check if already decompressed in Caches
    if FileManager.default.fileExists(atPath: dbURL.path) {
      // Validate schema version and git hash
      if isValidCache(dbURL: dbURL, lang: lang, author: author) {
        cc.ok1(#line, #function, "cached:", fileName)
        return dbURL
      } else {
        // Cache invalid (old schema or stale content), delete it
        cc.ok2(#line, #function, "Invalid cache detected, deleting:", fileName)
        try? FileManager.default.removeItem(at: dbURL)
      }
    }

    // Find and decompress .zst from bundle
    guard let zstURL = Bundle.module.url(
      forResource: "ebt-\(lang)-\(author)",
      withExtension: "db.zst",
    ) else {
      cc.bad1(#line, #function, fileName + ".zst not found:")
      throw EbtDataError.databaseNotFound(lang: lang, author: author)
    }
    cc.ok2(#line, #function, "zstURL:\(zstURL)")

    // Read compressed data from bundle
    let compressedData = try Data(contentsOf: zstURL)

    cc.ok2(#line, #function, "ZstdDecompression.decompress()",
           "\(compressedData.count)B")

    // Decompress using libzstd
    let decompressedData = try ZstdDecompression.decompress(compressedData)
    cc.ok2(#line, #function, "ZstdDecompression.write:", dbURL)

    // Write decompressed database to Caches
    try decompressedData.write(to: dbURL)
    cc.ok1(#line, #function, fileName, "OK")

    return dbURL
  }

  // MARK: - Database Connection

  /// Lazily opens database connection for specific author on first access
  /// Decompresses from bundle .zst to Caches if needed
  private func ensureDatabase(lang: String, author: String) throws {
    let key = "\(lang)/\(author)"
    guard databases[key] == nil else { return }
    cc.ok2(#line, #function, "key:", key)

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
      cc.bad1(#line, #function, "cannotOpenDatabase")
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }

    databases[key] = database

    let git_hash = getMetaprop(lang: lang, author: author, key: "git_hash")
    guard let git_hash else {
      cc.bad1(#line, #function, "missing git_hash")
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }

    let timestamp = getMetaprop(lang: lang, author: author, key: "git_hash_timestamp")
    guard let timestamp else {
      cc.bad1(#line, #function, "missing git_hash_timestamp")
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }

    cc.ok1(#line, #function, "loaded ebt-data[\(key)] commit:\(git_hash) \(timestamp)")
  }

  /// Gets database pointer for language/author, ensuring it's loaded
  /// Single source of truth for database lookup - avoiding code duplication
  /// - Parameters:
  ///   - lang: Language code
  ///   - author: Author/translator identifier
  /// - Returns: OpaquePointer to SQLite database
  /// - Throws: EbtDataError if database cannot be opened
  private func getDatabaseForLangAuthor(lang: String,
                                        author: String) throws -> OpaquePointer
  {
    let key = "\(lang)/\(author)"
    try ensureDatabase(lang: lang, author: author)
    guard let db = databases[key] else {
      cc.bad1(#line, #function, "database not found", key)
      throw EbtDataError.cannotOpenDatabase(lang: lang, author: author)
    }
    return db
  }

  /// Returns cached EbtSeeker for given language and author, creating if needed
  /// Defaults to Pali language if not specified
  /// Defaults to default author for language if not specified
  /// Ensures database is loaded before creating EbtSeeker
  func getSeeker(lang: String = "pli",
                 author: String = "") throws -> EbtSeeker
  {
    // Resolve author to default if empty
    var resolvedAuthor = author
    if resolvedAuthor.isEmpty {
      if let defaultInfo = EbtData.manifestCache
        .defaultAuthorForLanguage(lang)
      {
        resolvedAuthor = defaultInfo.author
      } else {
        cc.bad1(#line, #function, lang, "default author?")
        throw EbtDataError.cannotOpenDatabase(lang: lang, author: "")
      }
    }

    let key = "\(lang)/\(resolvedAuthor)"

    // Return cached instance if available
    if let cached = seekerCache[key] {
      return cached
    }

    // Create new seeker and cache it
    // Note: We ensure database is loaded but EbtSeeker doesn't use db directly
    // It delegates database queries back to EbtData.shared
    let _ = try getDatabaseForLangAuthor(lang: lang, author: resolvedAuthor)

    let lemmatizer = getLemmatizer(lang: lang)
    let seeker = EbtSeeker(
      lang: lang,
      author: resolvedAuthor,
      lemmatizer: lemmatizer,
    )
    seekerCache[key] = seeker
    return seeker
  }

  func getSeeker(suttaRef: SuttaRef) throws -> EbtSeeker {
    try getSeeker(
      lang: suttaRef.lang,
      author: suttaRef.author ?? "",
    )
  }

  deinit {
    // Safe: Actor has no remaining references when deinit runs.
    // databases dictionary is nonisolated(unsafe) but only accessed here and in
    // actor methods.
    // sqlite3_close must be called on same thread that opened connection.
    for (_, database) in databases {
      sqlite3_close(database)
    }
  }

  // MARK: - MLDocument Retrieval

  /// Returns trilingual MLDocument for a SuttaRef
  /// with trilingual segments comprising pli, doc, and ref fields
  /// The doc field text is determined by the suttaRef language and author
  /// - Parameter suttaRef: SuttaRef containing language, author, and sutta
  /// identifier
  /// - Parameter refLang (Optional) [TODO]
  /// - Parameter refAuthor (Optional) [TODO]
  /// - Returns: MLDocument with segments populated, or nil if not found
  public func getMLDocument(suttaRef: SuttaRef) -> MLDocument? {
    let docLang = suttaRef.lang ?? "pli"
    guard var mlDoc = getDocument(suttaRef: suttaRef) else {
      cc.bad1(#line, #function, suttaRef.description)
      return nil
    }

    if docLang == "pli" {
      for (scid, var segment) in mlDoc.segMap {
        segment.pli = segment.doc
        mlDoc.segMap[scid] = segment
      }
    } else {
      guard let pliRef = SuttaRef.create(suttaRef.suttaUid) else {
        cc.bad1(#line, #function, "could not create pli ref")
        return mlDoc
      }
      guard let pliDoc = getDocument(suttaRef: pliRef) else {
        cc.bad1(#line, #function, pliRef.toString())
        return mlDoc
      }
      for (scid, pliSegment) in pliDoc.segMap {
        let pliText = pliSegment.doc
        if var docSegment = mlDoc.segMap[scid] {
          docSegment.pli = pliText
          mlDoc.segMap[scid] = docSegment
        } else {
          let newSegment = Segment(scid: scid, pli: pliText)
          mlDoc.segMap[scid] = newSegment
        }
      }
    }

    return mlDoc
  }

  /// Returns single-language MLDocument for a SuttaRef
  /// - Parameter suttaRef: SuttaRef containing language, author, and sutta
  /// identifier
  /// - Returns: MLDocument with segments populated, or nil if not found
  public func getDocument(suttaRef: SuttaRef) -> MLDocument? {
    guard let author = suttaRef.author else {
      cc.bad1(#line, #function, "missing author")
      return nil
    }
    let lang = suttaRef.lang
    let suttaId = suttaRef.suttaUid

    do {
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else {
        cc.bad1(#line, #function, key, "database?")
        return nil
      }

      // Get author name from metaprops
      let authorName = getMetaprop(lang: lang, author: author, key: "author_name") ?? author

      // Query segments for this sutta (schema v6: using suttaUid, scid, text)
      let query = "SELECT scid, text FROM segments WHERE suttaUid = ? ORDER BY scid"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        cc.bad1(#line, #function, "sqlite3_prepare_v2 failed")
        return nil
      }

      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (suttaId as NSString).utf8String, -1, nil)

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

      guard !segMap.isEmpty else {
        cc.bad1(#line, #function, suttaId, "segments?")
        return nil
      }

      // Construct MLDocument
      let mlDoc = MLDocument(
        author: author,
        segMap: segMap,
        sutta_uid: suttaId,
        docLang: lang,
        docAuthor: author,
        docAuthorName: authorName,
      )

      cc.ok1(#line, #function, suttaId, "OK")
      return mlDoc
    } catch {
      cc.bad1(#line, #function, error.localizedDescription)
      return nil
    }
  }

  /// Search for a specific sutta by reference (e.g., "mn1", "sn42.11")
  /// Returns SeekerResult with .suttaref method
  func searchSuttaRef(_ result: SeekerResult) -> SeekerResult {
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()
    var refinedResult = result

    // Apply maxResults limit to pre-parsed items
    refinedResult
      .items = Array(refinedResult.items
        .prefix(refinedResult.metadata.maxDoc))
    refinedResult.metadata
      .elapsedTime = CFAbsoluteTimeGetCurrent() - elapsedAtStart

    return refinedResult
  }

  // MARK: - Unified Search

  /// Auto-detects search method based on query string content
  /// Attempts to parse as comma-delimited SuttaRef list first
  /// Defaults to lemma search for natural text
  /// - Parameters:
  ///   - query: Search query string
  ///   - docLang: Document language for SuttaRef parsing
  ///   - docAuthor: Document author for SuttaRef parsing
  /// - Returns: SearchMethodDetection with method and pre-parsed items

  /// Initializes SeekerResult with auto-detected or explicit method and
  /// pre-parsed items (if suttaref)
  /// Ensures database is decompressed before returning
  /// - Parameters:
  ///   - query: Search query string
  ///   - docLang: Document language
  ///   - docAuthor: Document author
  ///   - refLang: Reference language
  ///   - refAuthor: Reference author
  ///   - maxResults: Maximum results limit
  ///   - method: Explicit search method (auto-detect if nil)
  /// - Returns: SeekerResult with metadata and results (populated for
  /// .suttaref, empty for others)
  public func initSeekerResult(
    _ query: String,
    docLang: String,
    docAuthor: String,
    refLang: String,
    refAuthor: String?,
    maxResults: Int,
    method: SearchMethod? = nil,
  ) -> SeekerResult {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    let entries = trimmed.split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }

    // Determine method and parse items
    let (detectedMethod, items): (SearchMethod, [SeekerResultItem])

    if let explicitMethod = method {
      detectedMethod = explicitMethod
      items = parseItemsForMethod(
        explicitMethod,
        entries: entries,
        docLang: docLang,
        docAuthor: docAuthor,
      )

      // If explicit .suttaref requested but query is non-empty and no items
      // parsed → error
      if explicitMethod == .suttaref, !trimmed.isEmpty, items.isEmpty {
        let metadata = SearchMetadata(
          query: query,
          method: detectedMethod,
          elapsedTime: 0,
          docLang: docLang,
          docAuthor: docAuthor,
          refLang: refLang,
          refAuthor: refAuthor,
          maxDoc: maxResults,
        )
        return SeekerResult(
          metadata: metadata,
          items: [],
          error: SearchError(
            message: "search.error.invalid_suttaref".localized,
            detail: "Could not parse '\(query)' as a valid sutta reference",
          ),
        )
      }
    } else {
      let parseResult = autoDetectMethodAndParseItems(
        entries: entries,
        trimmed: trimmed,
        docLang: docLang,
        docAuthor: docAuthor,
      )
      detectedMethod = parseResult.method
      items = parseResult.items
    }

    // Ensure database is available
    do {
      try ensureDatabase(lang: docLang, author: docAuthor)
    } catch {
      let metadata = SearchMetadata(
        query: query,
        method: detectedMethod,
        elapsedTime: 0,
        docLang: docLang,
        docAuthor: docAuthor,
        refLang: refLang,
        refAuthor: refAuthor,
        maxDoc: maxResults,
      )
      cc.bad1(#line, #function, "ensureDatbase?", docLang, docAuthor)
      return SeekerResult(
        metadata: metadata,
        items: [],
        error: SearchError(
          message: "search.error.failed".localized,
          detail: "Failed to initialize database",
        ),
      )
    }

    let metadata = SearchMetadata(
      query: query,
      method: detectedMethod,
      elapsedTime: 0,
      docLang: docLang,
      docAuthor: docAuthor,
      refLang: refLang,
      refAuthor: refAuthor,
      maxDoc: maxResults,
    )

    cc.ok1(#line, #function, detectedMethod, query)
    return SeekerResult(metadata: metadata, items: items)
  }

  private nonisolated func parseItemsForMethod(
    _ method: SearchMethod,
    entries: [String],
    docLang: String,
    docAuthor: String,
  ) -> [SeekerResultItem] {
    guard method == .suttaref, !entries.isEmpty else { return [] }

    var items: [SeekerResultItem] = []
    for entry in entries {
      if let suttaRef = SuttaRef.create(
        entry,
        defaultLang: docLang,
        defaultAuthor: docAuthor,
      ) {
        items.append(SeekerResultItem(suttaRef: suttaRef, score: 1.0))
      }
    }
    return items
  }

  private nonisolated func autoDetectMethodAndParseItems(
    entries: [String],
    trimmed _: String,
    docLang: String,
    docAuthor: String,
  ) -> (method: SearchMethod, items: [SeekerResultItem]) {
    guard !entries.isEmpty else { return (.lemma, []) }

    var items: [SeekerResultItem] = []
    for entry in entries {
      if let suttaRef = SuttaRef.create(
        entry,
        defaultLang: docLang,
        defaultAuthor: docAuthor,
      ) {
        items.append(SeekerResultItem(suttaRef: suttaRef, score: 1.0))
      }
    }

    let suttaRefCount = items.count
    if suttaRefCount == entries.count, suttaRefCount > 0 {
      return (.suttaref, items)
    }

    return (.lemma, [])
  }

  // MARK: - SuttaRef Utilities

  /// Creates SuttaRef from sutta key format (e.g., "mn1/en/sujato")
  private func createSuttaRefFromKey(_ key: String) -> SuttaRef? {
    SuttaRef.create(key)
  }

  /// Searches for suttas matching lemmatized words in database
  /// Builds space-padded LIKE pattern and executes SQL query
  /// - Parameters:
  ///   - lang: Language code for database
  ///   - author: Author/translator for database
  ///   - lemmaWords: Array of lemmatized words to search for
  ///   - query: Original query string for metadata
  /// - Returns: SeekerResult with matched suttas and scores
  func searchLemma(
    lang: String,
    author: String,
    lemmaWords: [String],
    query: String,
    maxDoc: Int = MAX_DOC_DEFAULT,
  ) -> SeekerResult {
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()

    do {
      let db = try getDatabaseForLangAuthor(lang: lang, author: author)

      // Build space-padded LIKE pattern: '% lemma1 lemma2 ... lemman %'
      let likePattern = "% " + lemmaWords.joined(separator: " ") + " %"

      let sqlQuery = """
      SELECT s.suttaUid, COUNT(seg.rowid) as match_count, s.total_segments,
             COUNT(seg.rowid) + (CAST(COUNT(seg.rowid) AS FLOAT) / s.total_segments) as combined_score
      FROM segments seg
      JOIN suttas s ON seg.suttaUid = s.suttaUid
      WHERE seg.lemmas LIKE ?
      GROUP BY seg.suttaUid, s.total_segments
      ORDER BY combined_score DESC
      LIMIT ?
      """

      var itemsWithScores: [(suttaUid: String, score: Double)] = []

      var stmt: OpaquePointer?
      guard sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK else {
        return SeekerResult(
          metadata: SearchMetadata(
            query: query,
            method: .lemma,
            elapsedTime: CFAbsoluteTimeGetCurrent() - elapsedAtStart,
            docLang: lang,
            docAuthor: author,
            maxDoc: maxDoc,
          ),
          items: [],
        )
      }
      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (likePattern as NSString).utf8String, -1, nil)
      sqlite3_bind_int(stmt, 2, Int32(maxDoc))

      while sqlite3_step(stmt) == SQLITE_ROW {
        guard let uidC = sqlite3_column_text(stmt, 0) else { continue }
        let suttaUid = String(cString: uidC)
        let score = sqlite3_column_double(stmt, 3)
        itemsWithScores.append((suttaUid: suttaUid, score: score))
      }

      // Convert to SeekerResultItems (already sorted by SQL ORDER BY and
      // limited by LIMIT)
      var items: [SeekerResultItem] = []
      for (suttaUid, score) in itemsWithScores {
        if let ref = SuttaRef.create(
          suttaUid,
          defaultLang: lang,
          defaultAuthor: author,
        ) {
          items.append(SeekerResultItem(suttaRef: ref, score: score))
        }
      }

      return SeekerResult(
        metadata: SearchMetadata(
          query: query,
          method: .lemma,
          elapsedTime: CFAbsoluteTimeGetCurrent() - elapsedAtStart,
          docLang: lang,
          docAuthor: author,
          maxDoc: maxDoc,
        ),
        items: items,
      )
    } catch {
      return SeekerResult(
        metadata: SearchMetadata(
          query: query,
          method: .lemma,
          elapsedTime: CFAbsoluteTimeGetCurrent() - elapsedAtStart,
          docLang: lang,
          docAuthor: author,
          maxDoc: maxDoc,
        ),
        items: [],
        error: SearchError(
          message: "Database error",
          detail: error.localizedDescription,
        ),
      )
    }
  }

  /// Returns all segments for a given sutta reference
  /// Core data access method used by queryQuote, queryHeader, and other seeker
  /// methods
  /// - Parameter suttaRef: The sutta reference (contains lang, author,
  /// suttaUid)
  /// - Returns: Array of Segment objects with scid and doc populated, empty
  /// array on error
  func segmentsOfSuttaRef(_ suttaRef: SuttaRef) async -> [Segment] {
    do {
      let db = try getDatabaseForLangAuthor(
        lang: suttaRef.lang,
        author: suttaRef.author ?? "",
      )

      let sqlQuery = "SELECT scid, text FROM segments WHERE suttaUid = ? ORDER BY scid"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK else {
        return []
      }
      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(
        stmt,
        1,
        (suttaRef.suttaUid as NSString).utf8String,
        -1,
        nil,
      )

      var segments: [Segment] = []
      while sqlite3_step(stmt) == SQLITE_ROW {
        guard let scidC = sqlite3_column_text(stmt, 0),
              let textC = sqlite3_column_text(stmt, 1)
        else {
          continue
        }

        let scid = String(cString: scidC)
        let text = String(cString: textC)

        let segment = Segment(scid: scid, doc: text)
        segments.append(segment)
      }

      return segments
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


  /// Returns value for a single metaprop key
  /// - Parameters:
  ///   - lang: Language code (e.g., "en", "de")
  ///   - author: Author identifier (e.g., "sujato")
  ///   - key: Metaprop key to retrieve (e.g., "git_hash", "build_timestamp")
  /// - Returns: Metaprop value as String, or nil if key not found
  public func getMetaprop(lang: String, author: String,
                          key: String) -> String?
  {
    do {
      try ensureDatabase(lang: lang, author: author)
      let dbKey = "\(lang)/\(author)"
      guard let db = databases[dbKey] else {
        cc.bad1(#line, #function, "database not found:", lang, author)
        return nil
      }

      let query = "SELECT value FROM metaprops WHERE key = ? LIMIT 1"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        cc.bad1(#line, #function, "sqlite3_prepare_v2 failed")
        return nil
      }

      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)

      if sqlite3_step(stmt) == SQLITE_ROW {
        if let valueC = sqlite3_column_text(stmt, 0) {
          let value = String(cString: valueC)
          cc.ok1(#line, #function, key, "=", value)
          return value
        }
      }

      cc.bad1(#line, #function, key, "key?")
      return nil
    } catch {
      cc.bad1(#line, #function, error.localizedDescription)
      return nil
    }
  }

  /// Returns all metaprops as key/value dictionary
  /// - Parameters:
  ///   - lang: Language code (e.g., "en", "de")
  ///   - author: Author identifier (e.g., "sujato")
  /// - Returns: Dictionary of all metaprop keys and values, empty dict if table
  /// empty or not found
  public func getAllMetaprops(lang: String,
                              author: String) -> [String: String]
  {
    do {
      try ensureDatabase(lang: lang, author: author)
      let dbKey = "\(lang)/\(author)"
      guard let db = databases[dbKey] else {
        cc.bad1(#line, #function, "failed to get database for", lang, author)
        return [:]
      }

      let query = "SELECT key, value FROM metaprops"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        cc.bad1(#line, #function, "sqlite3_prepare_v2 failed")
        return [:]
      }

      defer { sqlite3_finalize(stmt) }

      var metaprops: [String: String] = [:]
      while sqlite3_step(stmt) == SQLITE_ROW {
        if let keyC = sqlite3_column_text(stmt, 0),
           let valueC = sqlite3_column_text(stmt, 1)
        {
          let key = String(cString: keyC)
          let value = String(cString: valueC)
          metaprops[key] = value
        }
      }

      cc.ok1(#line, #function, "retrieved", metaprops.count, "metaprops")
      return metaprops
    } catch {
      cc.bad1(#line, #function, error.localizedDescription)
      return [:]
    }
  }

  /// Returns all suttaUids available for specific author
  public func suttaUidsForAuthor(lang: String,
                                 author: String) async -> [String]
  {
    do {
      cc.ok2(#line, #function, lang, author)
      try ensureDatabase(lang: lang, author: author)
      let key = "\(lang)/\(author)"
      guard let db = databases[key] else { return [] }

      let query = "SELECT DISTINCT suttaUid FROM suttas ORDER BY suttaUid"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        cc.bad1(#line, #function, "!SQLITE_OK")
        return []
      }

      defer { sqlite3_finalize(stmt) }

      var suttaUids: [String] = []
      while sqlite3_step(stmt) == SQLITE_ROW {
        if let suttaUidC = sqlite3_column_text(stmt, 0) {
          let suttaUid = String(cString: suttaUidC)
          suttaUids.append(suttaUid)
        }
      }

      cc.ok1(#line, #function, lang, author, "[\(suttaUids.count) suttas]")
      return suttaUids
    } catch {
      cc.bad1(#line, #function, error)
      return []
    }
  }

  /// Clears cached database connections (for testing after database files are
  /// rebuilt)
  public func clearDatabaseCache() {
    for (_, dbPointer) in databases {
      sqlite3_close(dbPointer)
    }
    databases.removeAll()
  }

  /// Validates that cached database has correct schema version and content
  private func isValidCache(dbURL: URL, lang: String, author: String) -> Bool {
    var db: OpaquePointer?
    let openResult = sqlite3_open_v2(
      dbURL.path,
      &db,
      SQLITE_OPEN_READONLY,
      nil,
    )

    guard openResult == SQLITE_OK, let database = db else {
      return false
    }

    defer { sqlite3_close(database) }

    // Query schema_version and git_hash from metadata
    let query = "SELECT schema_version, git_hash FROM metadata WHERE language = ? AND author = ? LIMIT 1"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK
    else {
      return false
    }

    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, (lang as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 2, (author as NSString).utf8String, -1, nil)

    guard sqlite3_step(stmt) == SQLITE_ROW else {
      return false
    }

    // Check schema version
    var cachedSchemaVersion = ""
    if let versionText = sqlite3_column_text(stmt, 0) {
      cachedSchemaVersion = String(cString: versionText)
    }

    let requiredVersion = String(Self.schemaVersion)
    guard cachedSchemaVersion == requiredVersion else {
      cc.ok2(
        #line,
        "Schema mismatch: cached=\(cachedSchemaVersion) required=\(requiredVersion)",
      )
      return false
    }

    // Check git hash
    var cachedGitHash = ""
    if let hashText = sqlite3_column_text(stmt, 1) {
      cachedGitHash = String(cString: hashText)
    }

    let manifest = DatabaseManifest.shared
    guard let dbInfo = manifest.info(language: lang, author: author) else {
      return false
    }

    guard cachedGitHash == dbInfo.gitHash else {
      cc.ok2(
        #line,
        "Content stale: cached=\(cachedGitHash) expected=\(dbInfo.gitHash ?? "nil")",
      )
      return false
    }

    return true
  }

  /// Verify that a cached database matches the expected DatabaseInfo
  /// Compares gitHash from database metadata to expected value
  /// - Parameter info: DatabaseInfo to verify against
  /// - Returns: true if gitHashes match, false if different or database not
  /// found
  public func verifyDatabaseInfo(_ info: DatabaseInfo) -> Bool {
    let fileName = "ebt-\(info.language)-\(info.author).db"
    let cacheURL = FileManager.default.urls(
      for: .cachesDirectory,
      in: .userDomainMask,
    )[0].appendingPathComponent(fileName)

    // Check if cached database exists
    guard FileManager.default.fileExists(atPath: cacheURL.path) else {
      cc.ok1(#line, #function, "Not cached yet:", cacheURL.path)
      return true
    }

    var db: OpaquePointer?
    let openResult = sqlite3_open_v2(
      cacheURL.path,
      &db,
      SQLITE_OPEN_READONLY,
      nil,
    )

    guard openResult == SQLITE_OK, let database = db else {
      cc.bad1(#line, #function, "SQLite?", cacheURL.path)
      return false
    }

    defer { sqlite3_close(database) }

    // Query git_hash from metadata
    let query = "SELECT git_hash FROM metadata WHERE language = ? AND author = ? LIMIT 1"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK
    else {
      cc.bad1(#line, #function, "sqlite3_prepare_v2?", query)
      return false
    }

    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, (info.language as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 2, (info.author as NSString).utf8String, -1, nil)

    guard sqlite3_step(stmt) == SQLITE_ROW else {
      cc.bad1(#line, #function, "sqlite3_step?", query)
      return false
    }

    // Compare git hash
    var cachedGitHash = ""
    if let hashText = sqlite3_column_text(stmt, 0) {
      cachedGitHash = String(cString: hashText)
    }

    guard cachedGitHash == info.gitHash else {
      cc.bad1(
        #line,
        #function,
        "Content mismatch for \(info.language)/\(info.author):",
        "cached:", cachedGitHash,
        "expected:", info.gitHash ?? "nil",
      )
      return false
    }

    cc.ok1(#line, #function, "\(info.language)/\(info.author) OK")
    return true
  }

  /// Verify all cached databases match manifest
  /// Optionally repair by clearing mismatched cached database files
  /// - Parameters:
  ///   - repair: If true, delete cached .db files for any mismatched databases
  /// (default: true)
  /// - Returns: Array of DatabaseInfo entries that were mismatched
  public func verifyCachedDBs(repair: Bool = true) -> [DatabaseInfo] {
    let manifest = DatabaseManifest.shared
    var mismatchedDatabases: [DatabaseInfo] = []

    // Close and remove any cached database references
    // This ensures no stale pointers remain after we delete files
    for dbInfo in manifest.databases {
      let key = "\(dbInfo.language)/\(dbInfo.author)"
      if let db = databases[key] {
        sqlite3_close(db)
        databases.removeValue(forKey: key)
        cc.ok2(#line, "Closed cached database:", key)
      }
    }

    for dbInfo in manifest.databases {
      if !verifyDatabaseInfo(dbInfo) {
        mismatchedDatabases.append(dbInfo)
      }
    }

    if !mismatchedDatabases.isEmpty {
      cc.ok2(
        #line,
        "Found \(mismatchedDatabases.count) mismatched database(s)",
      )

      if repair {
        // Clear cached .db files for mismatched databases
        for dbInfo in mismatchedDatabases {
          let fileName = "ebt-\(dbInfo.language)-\(dbInfo.author).db"
          let cacheURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask,
          )[0].appendingPathComponent(fileName)

          if FileManager.default.fileExists(atPath: cacheURL.path) {
            try? FileManager.default.removeItem(at: cacheURL)
            cc.ok1(
              #line,
              "Cleared stale cache:",
              "\(dbInfo.language)/\(dbInfo.author)",
            )
          }
        }
      }
    }

    return mismatchedDatabases
  }

  /// Check if a sutta reference exists in its database
  /// - Parameter suttaRef: The sutta reference to check
  /// - Returns: true if sutta exists, false if not or database not found
  private func querySuttaRefExists(suttaRef: SuttaRef) async -> Bool {
    do {
      // Get database for this language/author
      let author = suttaRef.author ?? ""
      let db = try getDatabaseForLangAuthor(lang: suttaRef.lang, author: author)

      let sqlQuery = "SELECT 1 FROM segments WHERE suttaUid = ? LIMIT 1"
      var stmt: OpaquePointer?

      guard sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK else {
        cc.bad1(
          #line,
          #function,
          "sqlite3_prepare_v2 failed for \(suttaRef.toString())",
        )
        return false
      }
      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(
        stmt,
        1,
        (suttaRef.suttaUid as NSString).utf8String,
        -1,
        nil,
      )

      let exists = sqlite3_step(stmt) == SQLITE_ROW
      cc.ok1(#line, #function, suttaRef.toString(), "OK")
      return exists
    } catch {
      cc.bad1(#line, #function, suttaRef.toString(), "\(error)")
      return false
    }
  }
}

// MARK: - EbtDb (Lightweight Database Reference)

/// Lightweight, non-actor class that provides synchronous access to a specific
/// database
/// by delegating queries back to the EbtData actor.
/// This solves actor isolation issues by keeping all database operations within
/// the actor,
/// while allowing callers to use a simple synchronous interface.
public class EbtDb {
  public let lang: String
  public let author: String
  private let manager: EbtData

  /// Initialize with language, author, and reference to EbtData actor
  public init(lang: String, author: String, manager: EbtData = .shared) {
    self.lang = lang
    self.author = author
    self.manager = manager
  }

  /// Get a single metaprop value by key
  /// Delegates to the EbtData actor which handles database access
  /// - Parameter key: The metaprop key to retrieve
  /// - Returns: The metaprop value, or nil if not found
  public func getMetaprop(key: String) async -> String? {
    await manager.getMetaprop(lang: lang, author: author, key: key)
  }

  /// Get all metaprops as key/value dictionary
  /// Delegates to the EbtData actor which handles database access
  /// - Returns: Dictionary of all metaprop keys and values
  public func getAllMetaprops() async -> [String: String] {
    await manager.getAllMetaprops(lang: lang, author: author)
  }
}

// MARK: - Error Type

enum EbtDataError: Error {
  case databaseNotFound(lang: String, author: String)
  case cannotOpenDatabase(lang: String, author: String)
  case decompressionFailed(lang: String, author: String)
}
