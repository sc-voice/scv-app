import Foundation

enum BuildDBError: Error {
  case noArgumentsProvided
  case invalidFormat(String)
  case buildFailed(String)
}

class BuildDBCommand {
  private let projectRoot: String
  private let translationDir: String
  private let authorFilePath: String
  private let buildDir: String
  private let resourcesDir: String

  init() {
    projectRoot = ProcessInfo.processInfo.environment["PROJECT_ROOT"] ??
      URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .path

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

  func run() throws {
    let args = CommandLine.arguments.dropFirst()

    if args.isEmpty {
      printUsage()
      return
    }

    var selectedAuthors: [(lang: String, author: String)] = []
    var buildManifest = false
    var listManifest = false
    var rebuildFromManifest = false
    var listMetadata: (lang: String, author: String)? = nil

    var i = args.startIndex
    while i < args.endIndex {
      let arg = args[i]

      if arg == "--build-manifest" {
        buildManifest = true
      } else if arg == "--list-manifest" {
        listManifest = true
      } else if arg == "--rebuild-from-manifest" {
        rebuildFromManifest = true
      } else if arg == "--list-metadata" {
        i = args.index(after: i)
        guard i < args.endIndex else {
          throw BuildDBError.invalidFormat(
            "ERROR: --list-metadata requires lang:author argument",
          )
        }
        let parts = args[i].split(separator: ":").map(String.init)
        guard parts.count == 2 else {
          throw BuildDBError.invalidFormat(
            "ERROR: Invalid format '\(args[i])'. Expected 'lang:author'",
          )
        }
        listMetadata = (lang: parts[0], author: parts[1])
      } else {
        let parts = arg.split(separator: ":").map(String.init)
        if parts.count == 2 {
          selectedAuthors.append((lang: parts[0], author: parts[1]))
        } else {
          throw BuildDBError.invalidFormat(
            "ERROR: Invalid format '\(arg)'. Expected 'lang:author' or --list-metadata lang:author",
          )
        }
      }
      i = args.index(after: i)
    }

    if rebuildFromManifest {
      let manifestBuilder = DBManifestBuilder(
        buildDir: buildDir,
        resourcesDir: resourcesDir,
      )
      selectedAuthors = try manifestBuilder.readManifest()

      // Always ensure pli:ms is included
      let pliMsEntry = (lang: "pli", author: "ms")
      if !selectedAuthors
        .contains(where: {
          $0.lang == pliMsEntry.lang && $0.author == pliMsEntry.author
        })
      {
        selectedAuthors.append(pliMsEntry)
      }

      print(
        "Rebuilding databases from manifest: \(selectedAuthors.map { "\($0.lang)/\($0.author)" }.joined(separator: ", "))",
      )
      // Fall through to build logic below
    } else if buildManifest {
      let manifestBuilder = DBManifestBuilder(
        buildDir: buildDir,
        resourcesDir: resourcesDir,
      )
      try manifestBuilder.build()
      return
    } else if listManifest {
      let manifestBuilder = DBManifestBuilder(
        buildDir: buildDir,
        resourcesDir: resourcesDir,
      )
      try manifestBuilder.listManifest()
      return
    }

    if let meta = listMetadata {
      let manifestBuilder = DBManifestBuilder(
        buildDir: buildDir,
        resourcesDir: resourcesDir,
      )
      try manifestBuilder.listMetadata(lang: meta.lang, author: meta.author)
      return
    }

    if selectedAuthors.isEmpty {
      throw BuildDBError.noArgumentsProvided
    }

    // Always ensure pli:ms is included
    let pliMsEntry = (lang: "pli", author: "ms")
    if !selectedAuthors
      .contains(where: {
        $0.lang == pliMsEntry.lang && $0.author == pliMsEntry.author
      })
    {
      selectedAuthors.append(pliMsEntry)
    }

    print(
      "Building selected databases: \(selectedAuthors.map { "\($0.lang)/\($0.author)" }.joined(separator: ", "))",
    )

    let authorInfoImporter = AuthorInfoImporter(filePath: authorFilePath)
    let gitHash = getEbtDataGitHash()

    var totalSuttas = 0
    var totalSegments = 0
    var builtCount = 0

    for (lang, author) in selectedAuthors {
      // Use root directory for pli:ms, translation directory for others
      let builderTranslationDir = (lang == "pli" && author == "ms")
        ? "\(projectRoot)/local/ebt-data/root"
        : translationDir

      let builder = EbtDBBuilder(
        language: lang,
        author: author,
        buildDir: buildDir,
        resourcesDir: resourcesDir,
        translationDir: builderTranslationDir,
        authorInfoImporter: authorInfoImporter,
        gitHash: gitHash,
      )

      do {
        let (suttas, segments) = try builder.build()
        totalSuttas += suttas
        totalSegments += segments
        builtCount += 1
      } catch {
        print("  ERROR: Failed to build \(lang):\(author): \(error)")
      }
    }

    let elapsed = 0.0 // TODO: Add timing
    print("\nSUCCESS: Built \(builtCount) author databases")
    print("  Total: \(totalSuttas) suttas, \(totalSegments) segments")
    print("  Time elapsed: \(String(format: "%.2f", elapsed))s")
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
}
