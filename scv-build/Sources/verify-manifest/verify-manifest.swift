import Foundation
import scvCore

// Verify that:
// 1. All manifest entries have corresponding .zst files in Resources
// 2. All .zst files in Resources have corresponding .db in local/build
// 3. All .db files in local/build have corresponding .zst in Resources
// 4. All .zst files have modification time >= manifest buildTimestamp
// 5. All .zst files are no earlier than 1 minute before corresponding .db modification time

@main
struct VerifyManifestCommand {
  static func main() {
    let verbosity = 2
    let cc = ColorConsole(#file, #function, verbosity)
    let projectRoot = ProcessInfo.processInfo.environment["PROJECT_ROOT"] ??
      FileManager.default.currentDirectoryPath
    let manifestPath = "\(projectRoot)/scv-core/Sources/Resources/db-manifest.json"
    let resourcesDir = "\(projectRoot)/scv-core/Sources/Resources"
    let buildDir = "\(projectRoot)/local/build"
    let fileManager = FileManager.default
    let iso8601Formatter = ISO8601DateFormatter()

    guard let manifestData = try? Data(contentsOf: URL(fileURLWithPath: manifestPath))
    else {
      cc.bad1(#line, "Could not read manifest at \(manifestPath)")
      exit(1)
    }

    guard
      let json = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
      let databases = json["databases"] as? [[String: Any]]
    else {
      cc.bad1(#line, "Error: Could not parse manifest JSON")
      exit(1)
    }

    var errors: [String] = []

    // Get all .db files in local/build
    guard let buildFiles = try? fileManager.contentsOfDirectory(atPath: buildDir) else {
      cc.bad1(#line, "Could not read \(buildDir)")
      exit(1)
    }
    let buildDbs = Set(buildFiles.filter { $0.hasSuffix(".db") })

    // Get all .zst files in Resources
    guard let resourceFiles = try? fileManager.contentsOfDirectory(atPath: resourcesDir) else {
      cc.bad1(#line, "Could not read \(resourcesDir)")
      exit(1)
    }
    let resourceZsts = Set(resourceFiles.filter { $0.hasSuffix(".db.zst") })

    // 1. Verify all manifest entries have .zst files
    for db in databases {
      guard let language = db["language"] as? String
      else {
        cc.bad2(#line, "langauge?")
        continue
      }

      guard let author = db["author"] as? String
      else {
        cc.bad2(#line, language, "author?")
        continue
      }

      guard let buildTimestampStr = db["buildTimestamp"] as? String
      else {
        cc.bad2(#line, language, author, "no database")
        continue
      }

      let zstFile = "ebt-\(language)-\(author).db.zst"
      let dbFile = "ebt-\(language)-\(author).db"

      // Check if .zst exists
      if !resourceZsts.contains(zstFile) {
        cc.bad2(#line, "Missing", zstFile)
        errors.append("Missing .zst: \(zstFile)")
        continue
      }

      let zstPath = "\(resourcesDir)/\(zstFile)"
      let dbPath = "\(buildDir)/\(dbFile)"

      // 4. Verify .zst modification time >= buildTimestamp
      if let buildTimestamp = iso8601Formatter.date(from: buildTimestampStr),
         let zstAttrs = try? fileManager.attributesOfItem(atPath: zstPath),
         let zstDate = zstAttrs[.modificationDate] as? Date
      {
        if zstDate < buildTimestamp {
          let formatter = DateFormatter()
          formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
          let tsZst = formatter.string(from: zstDate)
          let tsBuild = formatter.string(from: buildTimestamp)
          let msg = "Stale .zst: \(zstFile) (\(tsZst)) < build (\(tsBuild))"
          cc.bad2(#line, msg)
          errors.append(msg)
        }
      }

      // 5. Verify .zst is newer than .db
      if fileManager.fileExists(atPath: dbPath),
         let dbAttrs = try? fileManager.attributesOfItem(atPath: dbPath),
         let zstAttrs = try? fileManager.attributesOfItem(atPath: zstPath),
         let dbDate = dbAttrs[.modificationDate] as? Date,
         let zstDate = zstAttrs[.modificationDate] as? Date
      {
        let oneMinuteBeforeDb = dbDate.addingTimeInterval(-60)
        if zstDate < oneMinuteBeforeDb {
          let formatter = DateFormatter()
          formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
          let tsZst = formatter.string(from: zstDate)
          let tsDb = formatter.string(from: dbDate)
          let msg = "Stale .zst: \(zstFile) (\(tsZst)) is >1min before db (\(tsDb))"
          cc.bad2(#line, msg)
          errors.append(msg)
        }
      }
    }

    // 2. Verify all .zst files have corresponding .db
    for zstFile in resourceZsts {
      let dbFile = String(zstFile.dropLast(4))  // Remove .zst

      if !buildDbs.contains(dbFile) {
        let msg = "Orphaned .zst: \(zstFile) has no corresponding .db in \(buildDir)"
        cc.bad2(#line, msg)
        errors.append(msg)
      }
    }

    // 3. Verify all .db files have corresponding .zst
    for dbFile in buildDbs {
      let zstFile = "\(dbFile).zst"

      if !resourceZsts.contains(zstFile) {
        let msg = "Missing .zst: \(zstFile) for \(dbFile)"
        cc.bad2(#line, msg)
        errors.append(msg)
      }
    }

    if errors.isEmpty {
      cc.ok2(#line, "\(databases.count) manifest entries verified")
      cc.ok2(#line, "\(buildDbs.count) databases in local/build")
      cc.ok2(#line, "\(resourceZsts.count) compressed files in Resources")
      cc.ok1(#line, "Manifest verification passed")
    } else {
      cc.bad1(#line, "Manifest verification \(errors.count) errors" )
      exit(1)
    }
  }
}
