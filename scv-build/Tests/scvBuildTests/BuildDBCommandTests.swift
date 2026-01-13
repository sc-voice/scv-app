import Foundation
import scv_build
import scvCore
import Testing

@Suite("BuildDBCommand Tests")
struct BuildDBCommandTests {
  // Helper to get project root from test environment
  private func getProjectRoot() -> String {
    // Start from current working directory which is the project root when tests
    // run
    FileManager.default.currentDirectoryPath
  }

  // MARK: - parseAuthorPair Tests

  @Test("parseAuthorPair with valid lang:author format")
  func parseAuthorPairValid() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    // Access private method via reflection for testing
    let result = try cmd.parseAuthorPair("en:sujato")
    #expect(result.lang == "en")
    #expect(result.author == "sujato")
  }

  @Test("parseAuthorPair with multiple colons in author")
  func parseAuthorPairMultipleColons() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    // Should fail - only one colon allowed
    #expect(throws: BuildDBError.self) {
      try cmd.parseAuthorPair("en:my:sujato")
    }
  }

  @Test("parseAuthorPair with no colon")
  func parseAuthorPairNoColon() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    #expect(throws: BuildDBError.self) {
      try cmd.parseAuthorPair("ensujato")
    }
  }

  @Test("parseAuthorPair with empty components")
  func parseAuthorPairEmptyComponents() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    // "en:" or ":sujato" should fail
    #expect(throws: BuildDBError.self) {
      try cmd.parseAuthorPair("en:")
    }
    #expect(throws: BuildDBError.self) {
      try cmd.parseAuthorPair(":sujato")
    }
  }

  // MARK: - parseArguments Tests

  @Test("parseArguments with single database spec")
  func parseArgumentsSingleDatabase() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = try cmd.parseArguments(["en:sujato"])

    if case let .buildDatabases(authors) = result {
      #expect(authors.count == 1)
      #expect(authors[0].lang == "en")
      #expect(authors[0].author == "sujato")
    } else {
      Issue.record("Expected .buildDatabases command")
    }
  }

  @Test("parseArguments with multiple database specs")
  func parseArgumentsMultipleDatabases() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = try cmd.parseArguments([
      "en:sujato",
      "de:sabbamitta",
      "pli:ms",
    ])

    if case let .buildDatabases(authors) = result {
      #expect(authors.count == 3)
      #expect(authors[0].lang == "en")
      #expect(authors[1].lang == "de")
      #expect(authors[2].lang == "pli")
    } else {
      Issue.record("Expected .buildDatabases command")
    }
  }

  @Test("parseArguments with --build-manifest flag")
  func parseArgumentsBuildManifest() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = try cmd.parseArguments(["--build-manifest"])

    if case .buildManifest = result {
      // Success
    } else {
      Issue.record("Expected .buildManifest command")
    }
  }

  @Test("parseArguments with --list-manifest flag")
  func parseArgumentsListManifest() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = try cmd.parseArguments(["--list-manifest"])

    if case .listManifest = result {
      // Success
    } else {
      Issue.record("Expected .listManifest command")
    }
  }

  @Test("parseArguments with --rebuild-from-manifest flag")
  func parseArgumentsRebuildFromManifest() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = try cmd.parseArguments(["--rebuild-from-manifest"])

    if case .rebuildFromManifest = result {
      // Success
    } else {
      Issue.record("Expected .rebuildFromManifest command")
    }
  }

  @Test("parseArguments with --list-metadata flag")
  func parseArgumentsListMetadata() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = try cmd.parseArguments(["--list-metadata", "en:sujato"])

    if case let .listMetadata(lang, author) = result {
      #expect(lang == "en")
      #expect(author == "sujato")
    } else {
      Issue.record("Expected .listMetadata command")
    }
  }

  @Test("parseArguments with --list-metadata missing argument")
  func parseArgumentsListMetadataMissing() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    #expect(throws: BuildDBError.self) {
      try cmd.parseArguments(["--list-metadata"])
    }
  }

  @Test("parseArguments with invalid format")
  func parseArgumentsInvalidFormat() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    #expect(throws: BuildDBError.self) {
      try cmd.parseArguments(["invalid"])
    }
    #expect(throws: BuildDBError.self) {
      try cmd.parseArguments(["en:sujato:extra"])
    }
  }

  @Test("parseArguments with empty input throws")
  func parseArgumentsEmpty() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    #expect(throws: BuildDBError.self) {
      try cmd.parseArguments([])
    }
  }

  @Test("parseArguments prioritizes manifest commands over database specs")
  func parseArgumentsPrioritizeManifest() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    // When --rebuild-from-manifest is present, it should win
    let result = try cmd.parseArguments([
      "en:sujato",
      "--rebuild-from-manifest",
    ])

    if case .rebuildFromManifest = result {
      // Success - manifest command takes priority
    } else {
      Issue.record("Expected manifest command to take priority")
    }
  }

  @Test("parseArguments with mixed valid and invalid specs")
  func parseArgumentsMixedValidInvalid() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    // Valid spec followed by invalid spec should fail
    #expect(throws: BuildDBError.self) {
      try cmd.parseArguments(["en:sujato", "invalid"])
    }
  }

  // MARK: - getTranslationDirectory Tests

  @Test("getTranslationDirectory for pli:ms uses root directory")
  func getTranslationDirectoryPliMs() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = cmd.getTranslationDirectory(lang: "pli", author: "ms")
    #expect(result.hasSuffix("local/ebt-data/root"))
  }

  @Test("getTranslationDirectory for en:sujato uses translation directory")
  func getTranslationDirectoryEnSujato() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = cmd.getTranslationDirectory(lang: "en", author: "sujato")
    #expect(result.hasSuffix("local/ebt-data/translation"))
  }

  @Test("getTranslationDirectory for de:sabbamitta uses translation directory")
  func getTranslationDirectoryDeSabbamitta() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = cmd.getTranslationDirectory(lang: "de", author: "sabbamitta")
    #expect(result.hasSuffix("local/ebt-data/translation"))
  }

  @Test(
    "getTranslationDirectory for pli with different author uses translation directory",
  )
  func getTranslationDirectoryPliOther() throws {
    let cmd = BuildDBCommand(projectRoot: getProjectRoot())
    let result = cmd.getTranslationDirectory(lang: "pli", author: "other")
    #expect(result.hasSuffix("local/ebt-data/translation"))
  }

  // MARK: - RunCommand Enum Tests

  @Test("RunCommand.buildDatabases associated value")
  func runCommandBuildDatabases() {
    let authors = [(lang: "en", author: "sujato")]
    let cmd = RunCommand.buildDatabases(authors)

    if case let .buildDatabases(result) = cmd {
      #expect(result.count == 1)
      #expect(result[0].lang == "en")
    } else {
      Issue.record("Expected buildDatabases command")
    }
  }

  @Test("RunCommand enum cases are distinct")
  func runCommandCasesDistinct() {
    let buildDB = RunCommand.buildDatabases([])
    let rebuildManifest = RunCommand.rebuildFromManifest
    let buildManifest = RunCommand.buildManifest
    let listManifest = RunCommand.listManifest
    let listMeta = RunCommand.listMetadata(lang: "en", author: "sujato")

    // They should be different cases
    if case .buildDatabases = buildDB {
    } else {
      Issue.record("buildDatabases should match")
    }

    if case .rebuildFromManifest = rebuildManifest {
    } else {
      Issue.record("rebuildFromManifest should match")
    }

    if case .buildManifest = buildManifest {
    } else {
      Issue.record("buildManifest should match")
    }

    if case .listManifest = listManifest {
    } else {
      Issue.record("listManifest should match")
    }

    if case .listMetadata = listMeta {
    } else {
      Issue.record("listMetadata should match")
    }
  }

  // MARK: - buildSelectedDatabases Tests

  @Test("buildSelectedDatabases builds en:soma database")
  func buildSelectedDatabasesEnSoma() throws {
    let projectRoot = getProjectRoot()
    let fileManager = FileManager.default
    let dbPath = "\(projectRoot)/local/build/ebt-en-soma.db"
    try? fileManager.removeItem(atPath: dbPath)

    let cmd = BuildDBCommand(projectRoot: projectRoot)
    try cmd.buildSelectedDatabases([(lang: "en", author: "soma")])

    #expect(fileManager.fileExists(atPath: dbPath))
  }

  // MARK: - compressSelectedDatabases Tests

  @Test(
    "compressSelectedDatabases compresses and decompresses en:soma database",
  )
  func compressSelectedDatabasesEnSoma() throws {
    let projectRoot = getProjectRoot()
    let fileManager = FileManager.default
    let dbPath = "\(projectRoot)/local/build/ebt-en-soma.db"
    let zstPath = "\(projectRoot)/scv-core/Sources/Resources/ebt-en-soma.db.zst"

    // Skip if source DB doesn't exist
    guard fileManager.fileExists(atPath: dbPath) else {
      print("⚠️ Skipping compression test - ebt-en-soma.db not found")
      return
    }

    try? fileManager.removeItem(atPath: zstPath)

    let cmd = BuildDBCommand(projectRoot: projectRoot)
    try cmd.compressSelectedDatabases([(lang: "en", author: "soma")])

    #expect(fileManager.fileExists(atPath: zstPath))

    // Verify the compressed file can be decompressed
    let originalData = try Data(contentsOf: URL(fileURLWithPath: dbPath))
    let compressedData = try Data(contentsOf: URL(fileURLWithPath: zstPath))
    let decompressedData = try ZstdDecompression.decompress(compressedData)

    #expect(
      decompressedData == originalData,
      "Decompressed data should match original",
    )
  }
}
