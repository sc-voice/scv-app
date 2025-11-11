#!/usr/bin/env swift

import Foundation
import SQLite3

let fileManager = FileManager.default
let startTime = Date()

// Paths
let projectRoot = ProcessInfo.processInfo.environment["PROJECT_ROOT"] ??
  URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
let sourceDir = "\(projectRoot)/local/ebt-data/translation/en/sujato/sutta"
let dbPath = "\(projectRoot)/scv-core/Resources/ebt-data.db"

// Ensure Resources directory exists
let resourcesDir = "\(projectRoot)/scv-core/Resources"
try? fileManager.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

// Remove existing DB
try? fileManager.removeItem(atPath: dbPath)

print("Building ebt-data.db from \(sourceDir)...")

// SQLite3 setup
var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
  print("ERROR: Cannot open database at \(dbPath)")
  exit(1)
}

defer { sqlite3_close(db) }

// Create schema
let schema = """
CREATE TABLE translations (
  key TEXT PRIMARY KEY,
  json TEXT NOT NULL
);

CREATE VIRTUAL TABLE translations_fts USING fts5(
  key UNINDEXED,
  json
);

CREATE TRIGGER translations_ai AFTER INSERT ON translations BEGIN
  INSERT INTO translations_fts(key, json) VALUES (new.key, new.json);
END;
"""

var errorMessage: UnsafeMutablePointer<CChar>?
if sqlite3_exec(db, schema, nil, nil, &errorMessage) != SQLITE_OK {
  let message = String(cString: errorMessage!)
  print("ERROR: Schema creation failed: \(message)")
  sqlite3_free(errorMessage)
  exit(1)
}

// Collections
let collections = ["an", "dn", "kn", "mn", "sn"]
var insertedCount = 0
let insertStatement = "INSERT INTO translations (key, json) VALUES (?, ?)"
var stmt: OpaquePointer?

guard sqlite3_prepare_v2(db, insertStatement, -1, &stmt, nil) == SQLITE_OK else {
  print("ERROR: Cannot prepare insert statement")
  exit(1)
}

defer { sqlite3_finalize(stmt) }

// Recursive function to find all JSON files
func findJSONFiles(inDirectory dir: String) -> [String] {
  var files: [String] = []
  guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else {
    return files
  }

  for item in contents {
    let itemPath = "\(dir)/\(item)"
    var isDir: ObjCBool = false
    if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
      if isDir.boolValue {
        files.append(contentsOf: findJSONFiles(inDirectory: itemPath))
      } else if item.hasSuffix(".json") {
        files.append(itemPath)
      }
    }
  }
  return files
}

// Process each collection
for collection in collections {
  let collectionPath = "\(sourceDir)/\(collection)"
  let jsonFiles = findJSONFiles(inDirectory: collectionPath)

  for filePath in jsonFiles.sorted() {
    let fileName = URL(fileURLWithPath: filePath).lastPathComponent

    // Extract SCID from filename: "mn1_translation-en-sujato.json" → "mn1"
    let baseName = (fileName as NSString).deletingPathExtension
    let components = baseName.split(separator: "_").map(String.init)
    guard let scid = components.first else {
      print("WARNING: Cannot parse SCID from \(fileName)")
      continue
    }

    let key = "en/sujato/\(scid)"

    // Read JSON file
    guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
      print("WARNING: Cannot read \(fileName)")
      continue
    }

    // Insert into database
    sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 2, (jsonString as NSString).utf8String, -1, nil)

    if sqlite3_step(stmt) != SQLITE_DONE {
      print("ERROR: Insert failed for key \(key)")
      exit(1)
    }

    sqlite3_reset(stmt)
    insertedCount += 1

    if insertedCount % 500 == 0 {
      print("  Inserted \(insertedCount) translations...")
    }
  }
}

let elapsed = Date().timeIntervalSince(startTime)
let dbSize = try? fileManager.attributesOfItem(atPath: dbPath)[.size] as? Int ?? 0
let dbSizeMB = Double(dbSize ?? 0) / 1_000_000

print("SUCCESS: Inserted \(insertedCount) translations into \(dbPath)")
print("  Database size: \(String(format: "%.1f", dbSizeMB)) MB")
print("  Time elapsed: \(String(format: "%.2f", elapsed))s")
