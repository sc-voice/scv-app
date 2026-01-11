import Foundation
import scvCore

public enum BuildDBError: Error {
  case noArgumentsProvided
  case invalidFormat(String)
  case buildFailed(String)
}

public enum RunCommand {
  case buildDatabases([(lang: String, author: String)])
  case rebuildFromManifest
  case buildManifest
  case listManifest
  case listMetadata(lang: String, author: String)
}

public class BuildDBCommand {
  private let projectRoot: String
  private let translationDir: String
  private let authorFilePath: String
  private let buildDir: String
  private let resourcesDir: String

  public init(projectRoot: String) {
    self.projectRoot = projectRoot

    translationDir = "\(projectRoot)/local/ebt-data/translation"
    authorFilePath = "\(projectRoot)/local/ebt-data/_author.json"
    buildDir = "\(projectRoot)/local/build"
    resourcesDir = "\(projectRoot)/scv-core/Sources/Resources"

    // Ensure build and Resources directories exist
    try? FileManager.default.createDirectory(
      atPath: buildDir,
      withIntermediateDirectories: true,
    )
    try? FileManager.default.createDirectory(
      atPath: resourcesDir,
      withIntermediateDirectories: true,
    )
  }

  public func run() throws {
    let args = CommandLine.arguments.dropFirst()
    cc.ok2(#line, #function, args)

    if args.isEmpty {
      printUsage()
      return
    }

    let command = try parseArguments(Array(args))
    cc.ok2(#line, #function, command)

    switch command {
    case .buildDatabases(let authors):
      try buildSelectedDatabases(authors)
      try compressSelectedDatabases(authors)
    case .rebuildFromManifest:
      let manifestBuilder = createManifestBuilder()
      let authors = try manifestBuilder.readManifest()
      print(
        "Rebuilding databases from manifest: \(authors.map { "\($0.lang)/\($0.author)" }.joined(separator: ", "))",
      )
      try buildSelectedDatabases(authors)
      try compressSelectedDatabases(authors)
    case .buildManifest:
      try createManifestBuilder().build()
    case .listManifest:
      try createManifestBuilder().listManifest()
    case .listMetadata(let lang, let author):
      try createManifestBuilder().listMetadata(lang: lang, author: author)
    }
    cc.ok1(#line, #function, command)
  }

  // MARK: - Argument Parsing

  public func parseArguments(_ args: [String]) throws -> RunCommand {
    var selectedAuthors: [(lang: String, author: String)] = []
    var buildManifest = false
    var listManifest = false
    var rebuildFromManifest = false
    var listMetadata: (lang: String, author: String)? = nil

    var i = 0
    while i < args.count {
      let arg = args[i]

      if arg == "--build-manifest" {
        buildManifest = true
      } else if arg == "--list-manifest" {
        listManifest = true
      } else if arg == "--rebuild-from-manifest" {
        rebuildFromManifest = true
      } else if arg == "--list-metadata" {
        i += 1
        guard i < args.count else {
          throw BuildDBError.invalidFormat(
            "ERROR: --list-metadata requires lang:author argument",
          )
        }
        listMetadata = try parseAuthorPair(args[i])
      } else {
        selectedAuthors.append(try parseAuthorPair(arg))
      }
      i += 1
    }

    // Determine command from flags
    if rebuildFromManifest {
      return .rebuildFromManifest
    }
    if buildManifest {
      return .buildManifest
    }
    if listManifest {
      return .listManifest
    }
    if let meta = listMetadata {
      return .listMetadata(lang: meta.lang, author: meta.author)
    }

    guard !selectedAuthors.isEmpty else {
      throw BuildDBError.noArgumentsProvided
    }

    return .buildDatabases(selectedAuthors)
  }

  public func parseAuthorPair(_ arg: String) throws -> (lang: String, author: String) {
    let parts = arg.split(separator: ":").map(String.init)
    guard parts.count == 2 else {
      throw BuildDBError.invalidFormat(
        "ERROR: Invalid format '\(arg)'. Expected 'lang:author'",
      )
    }
    return (lang: parts[0], author: parts[1])
  }

  // MARK: - Database Building

  public func buildSelectedDatabases(_ authors: [(lang: String, author: String)]) throws {
    let gitHash = getEbtDataGitHash() ?? "gitHash?"
    let gitHashTimestamp = getEbtDataGitHashTimestamp() ?? "gitHashTimestamp?"
    cc.ok2(#line, #function, "gitHash:\(gitHash)", "gitHashTimestamp:\(gitHashTimestamp)")
    let authorInfoImporter = AuthorInfoImporter(filePath: authorFilePath)

    var totalSuttas = 0
    var totalSegments = 0
    var builtCount = 0

    for (lang, author) in authors {
      let builderTranslationDir = getTranslationDirectory(lang: lang, author: author)

      let builder = EbtDBBuilder(
        language: lang,
        author: author,
        buildDir: buildDir,
        resourcesDir: resourcesDir,
        translationDir: builderTranslationDir,
        authorInfoImporter: authorInfoImporter,
        gitHash: gitHash,
        gitHashTimestamp: gitHashTimestamp,
      )

      do {
        let (suttas, segments) = try builder.buildDatabase()
        totalSuttas += suttas
        totalSegments += segments
        builtCount += 1
        cc.ok2(#line, #function, lang, author, segments)
      } catch {
        cc.bad2(#line, #function, lang, author, error)
      }
    }

    cc.ok1(#line, #function, "totalSutta:\(totalSuttas)", "totalSegments:\(totalSegments)")
  }

  public func compressSelectedDatabases(_ authors: [(lang: String, author: String)]) throws {
    for (lang, author) in authors {
      let dbPath = "\(buildDir)/ebt-\(lang)-\(author).db"
      cc.ok2(#line, #function, dbPath)
      let builder = EbtDBBuilder(
        language: lang,
        author: author,
        buildDir: buildDir,
        resourcesDir: resourcesDir,
        translationDir: getTranslationDirectory(lang: lang, author: author),
        authorInfoImporter: AuthorInfoImporter(filePath: authorFilePath),
        gitHash: getEbtDataGitHash(),
      )

      do {
        try builder.compressDatabase(dbPath: dbPath)
        cc.ok1(#line, #function, dbPath)
      } catch {
        cc.bad1(#line, #function, dbPath, error)
      }
    }
  }

  public func getTranslationDirectory(lang: String, author: String) -> String {
    // Use root directory for pli:ms, translation directory for others
    if lang == "pli" && author == "ms" {
      return "\(projectRoot)/local/ebt-data/root"
    }
    return translationDir
  }

  // MARK: - Manifest Operations

  private func createManifestBuilder() -> DBManifestBuilder {
    DBManifestBuilder(
      buildDir: buildDir,
      resourcesDir: resourcesDir,
    )
  }

  private func printUsage() {
    print("""
    Build per-author SQLite databases for SC-Voice

    USAGE:
      scv-build <lang:author> [<lang:author> ...]

    EXAMPLES:
      scv-build en:sujato
      scv-build en:sujato de:sabbamitta

    COMMANDS:
      scv-build --rebuild-from-manifest       Rebuild all databases from db-manifest.json
      scv-build --build-manifest              Generate db-manifest.json from built databases
      scv-build --list-manifest               List all databases in db-manifest.json
      scv-build --list-metadata en:sujato    Display detailed metadata for one database

    OUTPUT:
      Intermediate databases (.db): local/build/ebt-<lang>-<author>.db
      Compressed databases (.zst): scv-core/Sources/Resources/ebt-<lang>-<author>.db.zst
    """)
  }

  private func getEbtDataGitHash() -> String? {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = [
      "-c",
      "cd \(projectRoot)/local/ebt-data && git rev-parse HEAD 2>/dev/null",
    ]
    let pipe = Pipe()
    task.standardOutput = pipe
    do {
      try task.run()
      task.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      if let hash = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      {
        return hash.isEmpty ? nil : hash
      }
    } catch {
      return nil
    }
    return nil
  }

  /// Gets the commit timestamp of ebt-data repository HEAD
  /// Returns ISO 8601 formatted timestamp string
  /// - Returns: ISO 8601 timestamp string (e.g., "2025-12-19T04:13:06Z") or nil if unavailable
  private func getEbtDataGitHashTimestamp() -> String? {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = [
      "-c",
      "cd \(projectRoot)/local/ebt-data && git log -1 --format=%ci HEAD 2>/dev/null",
    ]
    let pipe = Pipe()
    task.standardOutput = pipe
    do {
      try task.run()
      task.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      if let timestamp = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      {
        return timestamp.isEmpty ? nil : timestamp
      }
    } catch {
      return nil
    }
    return nil
  }
}
