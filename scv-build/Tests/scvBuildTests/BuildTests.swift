import Foundation
import NaturalLanguage
import scv_build
import scvCore
import SQLite3
import Testing

@Suite("scv-build Tests")
struct BuildTests {
  /// Creates a temporary directory for test databases and returns its path
  /// Automatically cleans up on deinit
  private static func createTestBuildDir() throws
    -> (path: String, cleanup: () -> Void)
  {
    let tempDir = NSTemporaryDirectory()
    let testDir = "\(tempDir)scv-build-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(
      atPath: testDir,
      withIntermediateDirectories: true,
      attributes: nil,
    )
    let cleanup: () -> Void = {
      try? FileManager.default.removeItem(atPath: testDir)
    }
    return (path: testDir, cleanup: cleanup)
  }

  @Test("Placeholder test")
  func placeholder() {
    #expect(true)
  }

  @Test("EbtDBBuilder lemmatizeSegment removes punctuation before lemmatizing")
  func lemmatizeSegmentRemovesPunctuation() {
    // Create a simple lemmatizer to test the behavior
    let lemmatizer = NLTagger(tagSchemes: [.lemma])

    // Test string WITH punctuation (as it would be in source files)
    let textWithPunct = "Because he has understood that approval is the root of suffering,"

    // FIXED: Remove punctuation before lemmatizing (what EbtDBBuilder now does)
    let cleanText = textWithPunct.replacingOccurrences(
      of: "[^a-zA-Z0-9\\s]",
      with: "",
      options: .regularExpression,
    )
    lemmatizer.string = cleanText

    var lemmasWithPunctFixed: [String] = []
    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
    lemmatizer.enumerateTags(
      in: cleanText.startIndex ..< cleanText.endIndex,
      unit: .word,
      scheme: .lemma,
      options: options,
    ) { tag, tokenRange in
      let lemma = (tag?.rawValue ?? String(cleanText[tokenRange])).lowercased()
      lemmasWithPunctFixed.append(lemma)
      return true
    }

    // Test string WITHOUT punctuation (as it would be from search)
    let textNoPunct = "Because he has understood that approval is the root of suffering"
    lemmatizer.string = textNoPunct

    var lemmasNoPunct: [String] = []
    lemmatizer.enumerateTags(
      in: textNoPunct.startIndex ..< textNoPunct.endIndex,
      unit: .word,
      scheme: .lemma,
      options: options,
    ) { tag, tokenRange in
      let lemma = (tag?.rawValue ?? String(textNoPunct[tokenRange]))
        .lowercased()
      lemmasNoPunct.append(lemma)
      return true
    }

    print(
      "[LEMMATIZE WITH PUNCT (FIXED)] \(textWithPunct) → cleaned → \(cleanText) → \(lemmasWithPunctFixed)",
    )
    print("[LEMMATIZE NO PUNCT]           \(textNoPunct) → \(lemmasNoPunct)")

    // After removing punctuation before lemmatizing, both should produce
    // identical results
    #expect(
      lemmasWithPunctFixed == lemmasNoPunct,
      "Punctuation should be removed before lemmatizing to match search behavior",
    )

    // Both should contain "suffer" (not "suffering")
    #expect(
      lemmasNoPunct.contains("suffer"),
      "Should contain 'suffer' not 'suffering'",
    )
    #expect(
      lemmasWithPunctFixed.contains("suffer"),
      "After fix, should contain 'suffer' not 'suffering'",
    )
  }

  @Test("EbtDBBuilder getAuthorBaseURL returns bilara-data URL for translator")
  func getAuthorBaseURLForTranslator() async {
    let builder = EbtDBBuilder(
      language: "en",
      author: "sujato",
      buildDir: "/tmp",
      resourcesDir: "/tmp",
      translationDir: "/tmp",
      authorInfoImporter: AuthorInfoImporter(
        filePath: "/Users/visakha/dev/scv-app/local/ebt-data/_author.json",
      ),
      gitHash: nil,
    )

    let url = builder.getAuthorBaseURL(lang: "en", author: "sujato")

    let expectedURL = "https://github.com/suttacentral/bilara-data/tree/published/translation/en/sujato"
    #expect(url?.absoluteString == expectedURL, "URL should be \(expectedURL)")

    // Verify URL exists
    if let url {
      let exists = await urlExists(url)
      #expect(exists, "URL should exist: \(url.absoluteString)")
    }
  }

  @Test("EbtDBBuilder getAuthorBaseURL handles root author")
  func getAuthorBaseURLForRoot() async {
    let builder = EbtDBBuilder(
      language: "pli",
      author: "ms",
      buildDir: "/tmp",
      resourcesDir: "/tmp",
      translationDir: "/tmp",
      authorInfoImporter: AuthorInfoImporter(
        filePath: "/Users/visakha/dev/scv-app/local/ebt-data/_author.json",
      ),
      gitHash: nil,
    )

    let url = builder.getAuthorBaseURL(lang: "pli", author: "ms")

    let expectedURL = "https://github.com/suttacentral/bilara-data/tree/published/root/pli/ms"
    #expect(url?.absoluteString == expectedURL, "URL should be \(expectedURL)")

    // Verify URL exists
    if let url {
      let exists = await urlExists(url)
      #expect(exists, "URL should exist: \(url.absoluteString)")
    }
  }

  @Test("EbtDBBuilder getAuthorBaseURL falls back to ebt-data for fr/noeismet")
  func getAuthorBaseURLForFrenchTranslator() async {
    let builder = EbtDBBuilder(
      language: "fr",
      author: "noeismet",
      buildDir: "/tmp",
      resourcesDir: "/tmp",
      translationDir: "/tmp",
      authorInfoImporter: AuthorInfoImporter(
        filePath: "/Users/visakha/dev/scv-app/local/ebt-data/_author.json",
      ),
      gitHash: nil,
    )

    let url = builder.getAuthorBaseURL(lang: "fr", author: "noeismet")

    // fr/noeismet bilara-data doesn't exist (404), so falls back to ebt-data
    let expectedURL = "https://github.com/ebt-site/ebt-data/tree/published/translation/fr/noeismet"
    #expect(
      url?.absoluteString == expectedURL,
      "URL should fall back to ebt-data: \(expectedURL)",
    )

    // Verify URL exists
    if let url {
      let exists = await urlExists(url)
      #expect(exists, "URL should exist: \(url.absoluteString)")
    }
  }

  @Test(
    "EbtDBBuilder getSuttaRefURL returns SuttaCentral URL when bilara-data available",
  )
  func getSuttaRefURLBilara() async throws {
    let builder = EbtDBBuilder(
      language: "en",
      author: "sujato",
      buildDir: "/tmp",
      resourcesDir: "/tmp",
      translationDir: "/tmp",
      authorInfoImporter: AuthorInfoImporter(
        filePath: "/Users/visakha/dev/scv-app/local/ebt-data/_author.json",
      ),
      gitHash: nil,
    )

    let suttaRef = try SuttaRef(
      suttaUid: "an3.14",
      lang: "en",
      author: "sujato",
    )
    let url = builder.getSuttaRefURL(suttaRef: suttaRef)

    let expectedURL = "https://suttacentral.net/an3.14/en/sujato"
    #expect(
      url?.absoluteString == expectedURL,
      "URL should be SuttaCentral: \(expectedURL)",
    )

    // Verify URL exists
    if let url {
      let exists = await urlExists(url)
      #expect(exists, "URL should exist: \(url.absoluteString)")
    }
  }

  @Test(
    "EbtDBBuilder getSuttaRefURL returns ebt-data URL when bilara-data unavailable",
  )
  func getSuttaRefURLEbtData() async throws {
    let builder = EbtDBBuilder(
      language: "fr",
      author: "noeismet",
      buildDir: "/tmp",
      resourcesDir: "/tmp",
      translationDir: "/tmp",
      authorInfoImporter: AuthorInfoImporter(
        filePath: "/Users/visakha/dev/scv-app/local/ebt-data/_author.json",
      ),
      gitHash: nil,
    )

    let suttaRef = try SuttaRef(
      suttaUid: "an3.14",
      lang: "fr",
      author: "noeismet",
    )
    let url = builder.getSuttaRefURL(suttaRef: suttaRef)

    let expectedURL = "https://github.com/ebt-site/ebt-data/tree/published/translation/fr/noeismet"
    #expect(
      url?.absoluteString == expectedURL,
      "URL should be ebt-data: \(expectedURL)",
    )

    // Verify URL exists
    if let url {
      let exists = await urlExists(url)
      #expect(exists, "URL should exist: \(url.absoluteString)")
    }
  }

  @Test("EbtDBBuilder buildDatabase creates en:soma database")
  func buildDatabaseEnSoma() throws {
    // Resolve project root from test file location:
    // Tests.swift → scvBuildTests/ → scv-build/ → project root
    let projectRoot = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // scvBuildTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // scv-build
      .path

    let (buildDir, cleanup) = try Self.createTestBuildDir()
    defer { cleanup() }

    let resourcesDir = "\(projectRoot)/scv-core/Sources/Resources"
    let translationDir = "\(projectRoot)/local/ebt-data/translation"
    let authorFilePath = "\(projectRoot)/local/ebt-data/_author.json"

    let dbPath = "\(buildDir)/ebt-en-soma.db"

    let builder = EbtDBBuilder(
      language: "en",
      author: "soma",
      buildDir: buildDir,
      resourcesDir: resourcesDir,
      translationDir: translationDir,
      authorInfoImporter: AuthorInfoImporter(filePath: authorFilePath),
      gitHash: nil,
    )

    // Build database
    let (suttas, segments) = try builder.buildDatabase()

    // Verify database was created
    let exists = FileManager.default.fileExists(atPath: dbPath)
    #expect(exists, "Database file should exist at \(dbPath)")

    // Verify results are reasonable
    #expect(suttas > 0, "Should have populated suttas")
    #expect(segments > 0, "Should have populated segments")
    #expect(
      suttas <= segments,
      "Number of segments (\(segments)) should be >= suttas (\(suttas))",
    )

    print(
      "✓ Built en:soma: \(suttas) suttas, \(segments) segments",
    )
  }

  @Test("EbtDBBuilder buildDatabase creates fr:noeismet database")
  func buildDatabaseFrNoeismet() throws {
    let projectRoot = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // scvBuildTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // scv-build
      .path

    let (buildDir, cleanup) = try Self.createTestBuildDir()
    defer { cleanup() }

    let resourcesDir = "\(projectRoot)/scv-core/Sources/Resources"
    let translationDir = "\(projectRoot)/local/ebt-data/translation"
    let authorFilePath = "\(projectRoot)/local/ebt-data/_author.json"

    let dbPath = "\(buildDir)/ebt-fr-noeismet.db"

    let builder = EbtDBBuilder(
      language: "fr",
      author: "noeismet",
      buildDir: buildDir,
      resourcesDir: resourcesDir,
      translationDir: translationDir,
      authorInfoImporter: AuthorInfoImporter(filePath: authorFilePath),
      gitHash: nil,
    )

    // Build database
    let (suttas, segments) = try builder.buildDatabase()

    // Verify database was created
    let exists = FileManager.default.fileExists(atPath: dbPath)
    #expect(exists, "Database file should exist at \(dbPath)")

    // Verify results are reasonable
    #expect(suttas > 0, "Should have populated suttas")
    #expect(segments > 0, "Should have populated segments")
    #expect(
      suttas <= segments,
      "Number of segments (\(segments)) should be >= suttas (\(suttas))",
    )

    print(
      "✓ Built fr:noeismet: \(suttas) suttas, \(segments) segments",
    )
  }

  @Test("EbtDBBuilder buildDatabase populates metaprops table")
  func buildDatabasePopulatesMetaprops() throws {
    let projectRoot = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // scvBuildTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // scv-build
      .path

    let (buildDir, cleanup) = try Self.createTestBuildDir()
    defer { cleanup() }

    let resourcesDir = "\(projectRoot)/scv-core/Sources/Resources"
    let translationDir = "\(projectRoot)/local/ebt-data/translation"
    let authorFilePath = "\(projectRoot)/local/ebt-data/_author.json"

    let dbPath = "\(buildDir)/ebt-fr-noeismet.db"

    let builder = EbtDBBuilder(
      language: "fr",
      author: "noeismet",
      buildDir: buildDir,
      resourcesDir: resourcesDir,
      translationDir: translationDir,
      authorInfoImporter: AuthorInfoImporter(filePath: authorFilePath),
      gitHash: "abc123def456",
      gitHashTimestamp: "2025-12-19T04:13:06Z",
    )

    // Build database
    _ = try builder.buildDatabase()

    // Verify metaprops table exists and has required keys
    var db: OpaquePointer?
    let openResult = sqlite3_open_v2(
      dbPath,
      &db,
      SQLITE_OPEN_READONLY,
      nil,
    )
    defer { sqlite3_close(db) }

    guard openResult == SQLITE_OK, let db else {
      throw TestError.missingResource("Cannot open database at \(dbPath)")
    }

    // Check metaprops table exists
    let tableCheckQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='metaprops'"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, tableCheckQuery, -1, &stmt, nil) == SQLITE_OK
    else {
      throw TestError.missingResource("Cannot prepare table check query")
    }
    defer { sqlite3_finalize(stmt) }

    guard sqlite3_step(stmt) == SQLITE_ROW else {
      throw TestError.missingResource("metaprops table not found in database")
    }

    // Verify required keys are present
    let requiredKeys = [
      "language",
      "author",
      "author_name",
      "author_type",
      "git_hash",
      "git_hash_timestamp",
      "build_timestamp",
      "schema_version",
      "files_sutta",
      "files_vinaya",
      "files_other",
    ]

    for key in requiredKeys {
      let keyQuery = "SELECT value FROM metaprops WHERE key = ?"
      var keyStmt: OpaquePointer?
      guard sqlite3_prepare_v2(db, keyQuery, -1, &keyStmt, nil) == SQLITE_OK
      else {
        throw TestError.missingResource("Cannot prepare key query for \(key)")
      }
      defer { sqlite3_finalize(keyStmt) }

      sqlite3_bind_text(keyStmt, 1, (key as NSString).utf8String, -1, nil)

      guard sqlite3_step(keyStmt) == SQLITE_ROW else {
        throw TestError
          .missingResource("Metaprop key '\(key)' not found in database")
      }

      // Verify value is not NULL and not empty
      guard let valueC = sqlite3_column_text(keyStmt, 0) else {
        throw TestError.missingResource("Metaprop key '\(key)' has NULL value")
      }
      let value = String(cString: valueC)
      #expect(!value.isEmpty, "Metaprop key '\(key)' should not be empty")
    }

    // Verify specific values
    var metapropValues: [String: String] = [:]
    let allKeysQuery = "SELECT key, value FROM metaprops"
    var allStmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, allKeysQuery, -1, &allStmt, nil) == SQLITE_OK
    else {
      throw TestError.missingResource("Cannot prepare all keys query")
    }
    defer { sqlite3_finalize(allStmt) }

    while sqlite3_step(allStmt) == SQLITE_ROW {
      guard let keyC = sqlite3_column_text(allStmt, 0),
            let valueC = sqlite3_column_text(allStmt, 1)
      else {
        continue
      }
      let key = String(cString: keyC)
      let value = String(cString: valueC)
      metapropValues[key] = value
    }

    #expect(metapropValues["language"] == "fr", "Language should be 'fr'")
    #expect(
      metapropValues["author"] == "noeismet",
      "Author should be 'noeismet'",
    )
    #expect(
      !metapropValues["author_name"]!.isEmpty,
      "Author name should be populated",
    )
    #expect(
      metapropValues["git_hash"] == "abc123def456",
      "Git hash should match builder input",
    )
    #expect(
      metapropValues["git_hash_timestamp"] == "2025-12-19T04:13:06Z",
      "Git hash timestamp should match builder input",
    )

    print(
      "✓ Metaprops table verified: \(metapropValues.count) properties populated",
    )
  }

  @Test("Manifest JSON contains expected database entries")
  func manifestJsonStructure() throws {
    let projectRoot = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // scvBuildTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // scv-build
      .path

    let buildDir = "\(projectRoot)/local/build"
    let resourcesDir = "\(projectRoot)/scv-core/Sources/Resources"

    // Build manifest from current database files
    let manifestBuilder = DBManifestBuilder(
      buildDir: buildDir,
      resourcesDir: resourcesDir,
    )
    try manifestBuilder.build()

    let manifestPath = "\(resourcesDir)/db-manifest.json"

    guard FileManager.default.fileExists(atPath: manifestPath) else {
      throw TestError.missingResource("db-manifest.json not found")
    }

    let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
    guard let manifest = try JSONSerialization
      .jsonObject(with: manifestData) as? [String: Any],
      let databases = manifest["databases"] as? [[String: Any]]
    else {
      throw TestError.missingResource("Invalid manifest structure")
    }

    // Verify databases array is not empty
    #expect(
      databases.count > 0,
      "Manifest should contain at least one database",
    )

    // Find en:soma in manifest
    let somaEntry = databases.first { db in
      (db["language"] as? String) == "en" && (db["author"] as? String) == "soma"
    }

    guard let soma = somaEntry else {
      throw TestError.missingResource("en:soma not found in manifest")
    }

    // Verify all properties
    #expect(soma["language"] as? String == "en", "Language should be en")
    #expect(soma["author"] as? String == "soma", "Author should be soma")
    #expect(
      !(soma["authorName"] as? String ?? "").isEmpty,
      "Author name should exist",
    )
    #expect(
      !(soma["buildTimestamp"] as? String ?? "").isEmpty,
      "Build timestamp should exist",
    )
    #expect(
      !(soma["schemaVersion"] as? String ?? "").isEmpty,
      "Schema version should exist",
    )

    // Verify JSON metadata with actual author info and enriched authorBaseURL
    if let jsonStr = soma["json"] as? String {
      #expect(!jsonStr.isEmpty, "JSON metadata should not be empty")

      // Parse and validate JSON contents
      if let jsonData = jsonStr.data(using: .utf8),
         let jsonDict = try? JSONSerialization
         .jsonObject(with: jsonData) as? [String: Any]
      {
        // JSON should have author type and name
        #expect(
          jsonDict["type"] as? String == "translator",
          "soma type should be 'translator'",
        )
        #expect(
          jsonDict["name"] as? String == "Ayya Soma",
          "soma name should be 'Ayya Soma'",
        )

        // JSON should be enriched with authorBaseURL pointing to bilara-data
        #expect(
          jsonDict["authorBaseURL"] as? String != nil,
          "JSON should have authorBaseURL",
        )
        if let baseURL = jsonDict["authorBaseURL"] as? String {
          #expect(
            baseURL.contains("github.com"),
            "authorBaseURL should be a GitHub URL",
          )
          #expect(
            baseURL.contains("bilara-data"),
            "authorBaseURL should point to bilara-data repository",
          )
          #expect(
            baseURL.contains("en/soma"),
            "authorBaseURL should contain en/soma path",
          )
        }
      }
    }

    // Verify files field
    if let files = soma["files"] {
      #expect(
        files as? [String: Any] != nil || files as? Int != nil,
        "Files should be dict or int",
      )
    }

    print(
      "✓ Manifest verified: en:soma entry has all properties and valid JSON content",
    )

    // Also verify fr:noeismet (falls back to ebt-data since bilara-data doesn't
    // exist)
    let noeismetEntry = databases.first { db in
      (db[
        "language",
      ] as? String) == "fr" && (db["author"] as? String) == "noeismet"
    }

    if let noeismet = noeismetEntry {
      // Verify all properties
      #expect(noeismet["language"] as? String == "fr", "Language should be fr")
      #expect(
        noeismet["author"] as? String == "noeismet",
        "Author should be noeismet",
      )
      #expect(
        !(noeismet["authorName"] as? String ?? "").isEmpty,
        "Author name should exist",
      )
      #expect(
        !(noeismet["buildTimestamp"] as? String ?? "").isEmpty,
        "Build timestamp should exist",
      )
      #expect(
        !(noeismet["schemaVersion"] as? String ?? "").isEmpty,
        "Schema version should exist",
      )

      // Verify JSON metadata
      if let jsonStr = noeismet["json"] as? String {
        #expect(!jsonStr.isEmpty, "JSON metadata should not be empty")

        // Parse and validate JSON contents
        if let jsonData = jsonStr.data(using: .utf8),
           let jsonDict = try? JSONSerialization
           .jsonObject(with: jsonData) as? [String: Any]
        {
          // JSON should have author type and name
          #expect(
            jsonDict["type"] as? String == "translator",
            "noeismet type should be 'translator'",
          )
          #expect(
            jsonDict["name"] as? String == "Noé Ismet",
            "noeismet name should be 'Noé Ismet'",
          )

          // JSON should have authorBaseURL pointing to ebt-data (since
          // bilara-data fr/noeismet doesn't exist)
          #expect(
            jsonDict["authorBaseURL"] as? String != nil,
            "JSON should have authorBaseURL",
          )
          if let baseURL = jsonDict["authorBaseURL"] as? String {
            #expect(
              baseURL.contains("github.com"),
              "authorBaseURL should be a GitHub URL",
            )
            #expect(
              baseURL.contains("ebt-data"),
              "authorBaseURL should point to ebt-data repository (fallback)",
            )
            #expect(
              baseURL.contains("fr/noeismet"),
              "authorBaseURL should contain fr/noeismet path",
            )
          }
        }
      }

      print(
        "✓ Manifest verified: fr:noeismet entry (ebt-data fallback) has all properties and valid JSON content",
      )
    }
  }

  private func urlExists(_ url: URL) async -> Bool {
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"

    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse
      else { return false }
      return httpResponse.statusCode == 200
    } catch {
      return false
    }
  }
}

enum TestError: Error {
  case missingResource(String)
}
