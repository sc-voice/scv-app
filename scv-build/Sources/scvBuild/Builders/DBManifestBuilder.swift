import Foundation
import SQLite3

public class DBManifestBuilder {
  let buildDir: String
  let resourcesDir: String

  public init(buildDir: String, resourcesDir: String) {
    self.buildDir = buildDir
    self.resourcesDir = resourcesDir
  }

  public func build() throws {
    print("Building db-manifest.json...")

    guard let buildFiles = try? FileManager.default
      .contentsOfDirectory(atPath: buildDir)
    else {
      throw ManifestError.cannotReadBuildDir
    }

    // Read existing manifest to preserve curated fields
    let manifestPath = "\(resourcesDir)/db-manifest.json"
    var existingDatabases: [String: [String: Any]] = [:]
    if FileManager.default.fileExists(atPath: manifestPath) {
      if let manifestData =
        try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
        let manifestJSON = try? JSONSerialization
        .jsonObject(with: manifestData) as? [String: Any],
        let databases = manifestJSON["databases"] as? [[String: Any]]
      {
        for db in databases {
          if let lang = db["language"] as? String,
             let author = db["author"] as? String
          {
            let key = "\(lang):\(author)"
            existingDatabases[key] = db
          }
        }
      }
    }

    var manifestDatabases: [[String: Any]] = []

    for file in buildFiles.sorted() {
      guard file.hasPrefix("ebt-"), file.hasSuffix(".db") else { continue }

      // Extract lang and author from filename: ebt-{lang}-{author}.db
      let parts = file.dropFirst(4).dropLast(3).split(separator: "-")
      guard parts.count >= 2 else { continue }

      let lang = String(parts[0])
      let author = parts.dropFirst().joined(separator: "-")
      let dbPath = "\(buildDir)/\(file)"
      let zstPath = "\(resourcesDir)/ebt-\(lang)-\(author).db.zst"

      // Check if corresponding .zst exists
      guard FileManager.default.fileExists(atPath: zstPath) else {
        print("WARNING: No .zst found for \(file), skipping")
        continue
      }

      if var metadata = extractMetadata(from: dbPath) {
        // Preserve curated fields from existing manifest
        let key = "\(lang):\(author)"
        if let existing = existingDatabases[key] {
          // Keep existing language, author, authorName, authorUrl
          if let existingLang = existing["language"] {
            metadata["language"] = existingLang
          }
          if let existingAuthor = existing["author"] {
            metadata["author"] = existingAuthor
          }
          if let existingAuthorName = existing["authorName"] {
            metadata["authorName"] = existingAuthorName
          }
          if let existingAuthorUrl = existing["authorUrl"] {
            metadata["authorUrl"] = existingAuthorUrl
          }
        }
        manifestDatabases.append(metadata)
      }
    }

    // Ensure pli:ms is always in the manifest if it exists
    let hasPliMs = manifestDatabases.contains { db in
      (db["language"] as? String) == "pli" && (db["author"] as? String) == "ms"
    }
    if !hasPliMs {
      let pliMsDbPath = "\(buildDir)/ebt-pli-ms.db"
      let pliMsZstPath = "\(resourcesDir)/ebt-pli-ms.db.zst"

      if FileManager.default.fileExists(atPath: pliMsDbPath),
         FileManager.default.fileExists(atPath: pliMsZstPath),
         var metadata = extractMetadata(from: pliMsDbPath)
      {
        // Preserve curated fields for pli:ms if it exists
        let key = "pli:ms"
        if let existing = existingDatabases[key] {
          if let existingLang = existing["language"] {
            metadata["language"] = existingLang
          }
          if let existingAuthor = existing["author"] {
            metadata["author"] = existingAuthor
          }
          if let existingAuthorName = existing["authorName"] {
            metadata["authorName"] = existingAuthorName
          }
          if let existingAuthorUrl = existing["authorUrl"] {
            metadata["authorUrl"] = existingAuthorUrl
          }
        }
        manifestDatabases.append(metadata)
        print("  Added pli:ms to manifest")
      }
    }

    // Write manifest.json with canonical (sorted) key ordering
    guard let jsonString = sortedJSONString(for: manifestDatabases) else {
      throw ManifestError.cannotSerializeJSON
    }

    do {
      try jsonString.write(
        toFile: manifestPath,
        atomically: true,
        encoding: .utf8,
      )
      print(
        "SUCCESS: Written db-manifest.json with \(manifestDatabases.count) databases",
      )
      print("  Manifest: \(manifestPath)")
    } catch {
      throw ManifestError.cannotWriteFile(manifestPath)
    }
  }

  /// Generate JSON string with alphabetically sorted keys for canonical
  /// formatting
  /// This ensures diffs show only data changes, not reordering of properties
  private func sortedJSONString(for databases: [[String: Any]]) -> String? {
    // Sort each database's keys alphabetically
    var sortedDatabases: [[String: Any]] = []
    for db in databases {
      var sortedDb: [String: Any] = [:]
      for key in db.keys.sorted() {
        sortedDb[key] = db[key]
      }
      sortedDatabases.append(sortedDb)
    }

    let manifest: [String: Any] = ["databases": sortedDatabases]
    guard
      let jsonData = try? JSONSerialization.data(
        withJSONObject: manifest,
        options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys],
      )
    else {
      return nil
    }

    return String(data: jsonData, encoding: .utf8)
  }

  private func extractMetadata(from dbPath: String) -> [String: Any]? {
    var db: OpaquePointer?
    guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
      print("ERROR: Cannot open database at \(dbPath)")
      return nil
    }
    defer { sqlite3_close(db) }

    let metapropsQuery = "SELECT key, value FROM metaprops"
    var metapropStmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, metapropsQuery, -1, &metapropStmt, nil) ==
      SQLITE_OK
    else {
      print("ERROR: Cannot prepare query for \(dbPath)")
      return nil
    }
    defer { sqlite3_finalize(metapropStmt) }

    var metaprops: [String: String] = [:]
    while sqlite3_step(metapropStmt) == SQLITE_ROW {
      if let keyC = sqlite3_column_text(metapropStmt, 0),
         let valueC = sqlite3_column_text(metapropStmt, 1)
      {
        let key = String(cString: keyC)
        let value = String(cString: valueC)
        metaprops[key] = value
      }
    }

    // Verify required metaprops exist
    guard let language = metaprops["language"],
          let author = metaprops["author"],
          let authorName = metaprops["author_name"],
          let buildTimestamp = metaprops["build_timestamp"]
    else {
      return nil
    }

    var metaDict: [String: Any] = [
      "language": language,
      "author": author,
      "authorName": authorName,
      "buildTimestamp": buildTimestamp,
      "files": [:], // Will compute from file counts below
    ]

    // Optional fields
    if let gitHash = metaprops["git_hash"] {
      metaDict["gitHash"] = gitHash
    }

    if let schemaVersion = metaprops["schema_version"] {
      metaDict["schemaVersion"] = schemaVersion
    }

    if let authorBaseUrl = metaprops["authorBaseUrl"] {
      metaDict["authorBaseUrl"] = authorBaseUrl
    }

    // Compute files_breakdown from individual file counts
    var filesCounts: [String: Int] = [:]
    if let suttaCount = metaprops["files_sutta"], let count = Int(suttaCount) {
      filesCounts["sutta"] = count
    }
    if let vinayaCount = metaprops["files_vinaya"],
       let count = Int(vinayaCount)
    {
      filesCounts["vinaya"] = count
    }
    if let otherCount = metaprops["files_other"], let count = Int(otherCount) {
      filesCounts["other"] = count
    }

    // Calculate total
    let total = filesCounts.values.reduce(0, +)
    filesCounts["total"] = total

    metaDict["files"] = filesCounts

    return metaDict
  }

  func readManifest() throws -> [(lang: String, author: String)] {
    let manifestPath = "\(resourcesDir)/db-manifest.json"

    guard FileManager.default.fileExists(atPath: manifestPath) else {
      throw ManifestError.manifestNotFound
    }

    guard let manifestData =
      try? Data(contentsOf: URL(fileURLWithPath: manifestPath))
    else {
      throw ManifestError.cannotReadManifest
    }

    guard let manifestJSON = try? JSONSerialization
      .jsonObject(with: manifestData) as? [String: Any],
      let databases = manifestJSON["databases"] as? [[String: Any]]
    else {
      throw ManifestError.invalidManifest
    }

    var authors: [(lang: String, author: String)] = []
    for db in databases {
      if let language = db["language"] as? String,
         let author = db["author"] as? String
      {
        authors.append((lang: language, author: author))
      }
    }

    return authors
  }

  func listManifest() throws {
    let manifestPath = "\(resourcesDir)/db-manifest.json"

    guard FileManager.default.fileExists(atPath: manifestPath) else {
      print("ERROR: db-manifest.json not found at \(manifestPath)")
      return
    }

    guard let manifestData =
      try? Data(contentsOf: URL(fileURLWithPath: manifestPath))
    else {
      throw ManifestError.cannotReadManifest
    }

    guard let manifestJSON = try? JSONSerialization
      .jsonObject(with: manifestData) as? [String: Any],
      let databases = manifestJSON["databases"] as? [[String: Any]]
    else {
      throw ManifestError.invalidManifest
    }

    print("Databases in db-manifest.json:")
    print("")

    for (index, db) in databases.enumerated() {
      let language = db["language"] as? String ?? "unknown"
      let author = db["author"] as? String ?? "unknown"
      let authorName = db["authorName"] as? String ?? author
      let buildTimestamp = db["buildTimestamp"] as? String ?? "unknown"
      let files = db["files"] as? Int ?? 0

      print("\(index + 1). \(language):\(author)")
      print("   Author: \(authorName)")
      print("   Files: \(files)")
      print("   Built: \(buildTimestamp)")

      if let gitHash = db["gitHash"] as? String {
        print("   Git Hash: \(gitHash)")
      }
      if let schemaVersion = db["schemaVersion"] as? String {
        print("   Schema Version: \(schemaVersion)")
      }
      if let filesBreakdown = db["filesBreakdown"] as? [String: Any] {
        print("   Files Breakdown: \(filesBreakdown)")
      }
      print("")
    }

    print("Total: \(databases.count) databases")
  }

  func listMetadata(lang: String, author: String) throws {
    let dbPath = "\(buildDir)/ebt-\(lang)-\(author).db"

    var db: OpaquePointer?
    guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
      throw ManifestError.cannotOpenDatabase
    }
    defer { sqlite3_close(db) }

    let metapropsQuery = "SELECT key, value FROM metaprops"
    var metapropStmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, metapropsQuery, -1, &metapropStmt, nil) ==
      SQLITE_OK
    else {
      throw ManifestError.cannotPrepareQuery
    }
    defer { sqlite3_finalize(metapropStmt) }

    var metaprops: [String: String] = [:]
    while sqlite3_step(metapropStmt) == SQLITE_ROW {
      if let keyC = sqlite3_column_text(metapropStmt, 0),
         let valueC = sqlite3_column_text(metapropStmt, 1)
      {
        let key = String(cString: keyC)
        let value = String(cString: valueC)
        metaprops[key] = value
      }
    }

    // Verify required metaprops exist
    guard let language = metaprops["language"],
          let authorStr = metaprops["author"],
          let authorName = metaprops["author_name"]
    else {
      print("ERROR: No metadata found for \(lang):\(author)")
      return
    }

    print("Metadata for \(language):\(authorStr)")
    print("  Source: \(dbPath)")
    print("  Author Name: \(authorName)")

    // Calculate and display total files
    var totalFiles = 0
    if let suttaCount = metaprops["files_sutta"], let count = Int(suttaCount) {
      totalFiles += count
    }
    if let vinayaCount = metaprops["files_vinaya"],
       let count = Int(vinayaCount)
    {
      totalFiles += count
    }
    if let otherCount = metaprops["files_other"], let count = Int(otherCount) {
      totalFiles += count
    }
    print("  Files: \(totalFiles)")

    if let gitHash = metaprops["git_hash"] {
      print("  Git Hash: \(gitHash)")
    }

    if let buildTimestamp = metaprops["build_timestamp"] {
      print("  Build Timestamp: \(buildTimestamp)")
    }

    if let authorBaseUrl = metaprops["authorBaseUrl"] {
      print("  Author Base URL: \(authorBaseUrl)")
    }

    if let schemaVersion = metaprops["schema_version"] {
      print("  Schema Version: \(schemaVersion)")
    }
  }
}

enum ManifestError: Error {
  case cannotReadBuildDir
  case cannotOpenDatabase
  case cannotPrepareQuery
  case cannotSerializeJSON
  case cannotWriteFile(String)
  case cannotReadManifest
  case invalidManifest
  case manifestNotFound
}
