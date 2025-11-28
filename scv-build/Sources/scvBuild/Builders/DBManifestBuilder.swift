import Foundation
import SQLite3

class DBManifestBuilder {
  let buildDir: String
  let resourcesDir: String

  init(buildDir: String, resourcesDir: String) {
    self.buildDir = buildDir
    self.resourcesDir = resourcesDir
  }

  func build() throws {
    print("Building db-manifest.json...")

    guard let buildFiles = try? FileManager.default
      .contentsOfDirectory(atPath: buildDir)
    else {
      throw ManifestError.cannotReadBuildDir
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

      // Extract metadata from .db
      var db: OpaquePointer?
      guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
        print("ERROR: Cannot open database at \(dbPath)")
        continue
      }
      defer { sqlite3_close(db) }

      let query =
        "SELECT language, author, author_name, git_hash, build_timestamp, files, json, schema_version, files_breakdown FROM metadata LIMIT 1"
      var stmt: OpaquePointer?
      guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        print("ERROR: Cannot prepare query for \(file)")
        continue
      }
      defer { sqlite3_finalize(stmt) }

      if sqlite3_step(stmt) == SQLITE_ROW {
        if let langC = sqlite3_column_text(stmt, 0),
           let authorC = sqlite3_column_text(stmt, 1),
           let authorNameC = sqlite3_column_text(stmt, 2),
           let buildTimestampC = sqlite3_column_text(stmt, 4)
        {
          let dbFiles = Int(sqlite3_column_int(stmt, 5))

          var metaDict: [String: Any] = [
            "language": String(cString: langC),
            "author": String(cString: authorC),
            "authorName": String(cString: authorNameC),
            "buildTimestamp": String(cString: buildTimestampC),
            "files": dbFiles,
          ]

          // Optional git_hash
          if sqlite3_column_type(stmt, 3) != SQLITE_NULL,
             let gitHashC = sqlite3_column_text(stmt, 3)
          {
            metaDict["gitHash"] = String(cString: gitHashC)
          }

          // Optional json
          if sqlite3_column_type(stmt, 6) != SQLITE_NULL,
             let jsonC = sqlite3_column_text(stmt, 6)
          {
            metaDict["json"] = String(cString: jsonC)
          }

          // Optional schema_version
          if sqlite3_column_type(stmt, 7) != SQLITE_NULL,
             let schemaVersionC = sqlite3_column_text(stmt, 7)
          {
            metaDict["schemaVersion"] = String(cString: schemaVersionC)
          }

          // Optional files_breakdown - maps to "files" field in manifest
          if sqlite3_column_type(stmt, 8) != SQLITE_NULL,
             let filesBreakdownC = sqlite3_column_text(stmt, 8)
          {
            let filesBreakdownStr = String(cString: filesBreakdownC)
            if let filesData = filesBreakdownStr.data(using: .utf8),
               let filesJson = try? JSONSerialization
               .jsonObject(with: filesData) as? [String: Any]
            {
              metaDict["files"] = filesJson
            }
          }

          manifestDatabases.append(metaDict)
        }
      }
    }

    // Write manifest.json
    let manifest: [String: Any] = ["databases": manifestDatabases]
    guard let jsonData = try? JSONSerialization.data(
      withJSONObject: manifest,
      options: .prettyPrinted,
    ) else {
      throw ManifestError.cannotSerializeJSON
    }

    let manifestPath = "\(resourcesDir)/db-manifest.json"
    do {
      try jsonData.write(to: URL(fileURLWithPath: manifestPath))
      print(
        "SUCCESS: Written db-manifest.json with \(manifestDatabases.count) databases",
      )
      print("  Manifest: \(manifestPath)")
    } catch {
      throw ManifestError.cannotWriteFile(manifestPath)
    }
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

    let query =
      "SELECT language, author, author_name, git_hash, build_timestamp, files, json, schema_version FROM metadata WHERE language = ? AND author = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
      throw ManifestError.cannotPrepareQuery
    }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, (lang as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 2, (author as NSString).utf8String, -1, nil)

    if sqlite3_step(stmt) == SQLITE_ROW {
      let language = String(cString: sqlite3_column_text(stmt, 0))
      let authorStr = String(cString: sqlite3_column_text(stmt, 1))
      let authorName = String(cString: sqlite3_column_text(stmt, 2))
      let gitHash = String(cString: sqlite3_column_text(stmt, 3))
      let buildTimestamp = String(cString: sqlite3_column_text(stmt, 4))
      let files = Int(sqlite3_column_int(stmt, 5))

      print("Metadata for \(language):\(authorStr)")
      print("  Source: \(dbPath)")
      print("  Author Name: \(authorName)")
      print("  Files: \(files)")
      print("  Git Hash: \(gitHash)")
      print("  Build Timestamp: \(buildTimestamp)")

      if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
        let jsonStr = String(cString: sqlite3_column_text(stmt, 6))
        print("  JSON Metadata: \(jsonStr)")
      } else {
        print("  JSON Metadata: (none)")
      }

      if sqlite3_column_type(stmt, 7) != SQLITE_NULL {
        let schemaVersionStr = String(cString: sqlite3_column_text(stmt, 7))
        print("  Schema Version: \(schemaVersionStr)")
      }
    } else {
      print("ERROR: No metadata found for \(lang):\(author)")
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
