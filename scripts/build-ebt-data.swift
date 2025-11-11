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

// Create schema - segment-level indexing
let schema = """
CREATE TABLE suttas (
  sutta_key TEXT PRIMARY KEY,
  total_segments INTEGER
);

CREATE TABLE segments (
  sutta_key TEXT,
  segment_id TEXT,
  segment_text TEXT
);

CREATE VIRTUAL TABLE segments_fts USING fts5(
  sutta_key UNINDEXED,
  segment_id UNINDEXED,
  segment_text
);

CREATE TRIGGER segments_ai AFTER INSERT ON segments BEGIN
  INSERT INTO segments_fts(sutta_key, segment_id, segment_text)
  VALUES (new.sutta_key, new.segment_id, new.segment_text);
END;
"""

var errorMessage: UnsafeMutablePointer<CChar>?
if sqlite3_exec(db, schema, nil, nil, &errorMessage) != SQLITE_OK {
  let message = String(cString: errorMessage!)
  print("ERROR: Schema creation failed: \(message)")
  sqlite3_free(errorMessage)
  exit(1)
}

// Prepare insert statements
let insertSuttaStatement = "INSERT OR IGNORE INTO suttas (sutta_key, total_segments) VALUES (?, ?)"
let insertSegmentStatement = "INSERT INTO segments (sutta_key, segment_id, segment_text) VALUES (?, ?, ?)"

var suttaStmt: OpaquePointer?
var segmentStmt: OpaquePointer?

guard sqlite3_prepare_v2(db, insertSuttaStatement, -1, &suttaStmt, nil) == SQLITE_OK,
      sqlite3_prepare_v2(db, insertSegmentStatement, -1, &segmentStmt, nil) == SQLITE_OK else {
  print("ERROR: Cannot prepare insert statements")
  exit(1)
}

defer {
  sqlite3_finalize(suttaStmt)
  sqlite3_finalize(segmentStmt)
}

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

// Collections
let collections = ["an", "dn", "kn", "mn", "sn"]
var insertedSegments = 0
var processedSuttas = 0

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

    let suttaKey = "en/sujato/\(scid)"

    // Read JSON file
    guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
      print("WARNING: Cannot read \(fileName)")
      continue
    }

    // Parse JSON to extract segments
    guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
      print("WARNING: Cannot parse JSON in \(fileName)")
      continue
    }

    let segmentCount = jsonObject.count

    // Insert sutta
    sqlite3_bind_text(suttaStmt, 1, (suttaKey as NSString).utf8String, -1, nil)
    sqlite3_bind_int(suttaStmt, 2, Int32(segmentCount))

    if sqlite3_step(suttaStmt) != SQLITE_DONE {
      print("ERROR: Insert failed for sutta \(suttaKey)")
      exit(1)
    }
    sqlite3_reset(suttaStmt)

    // Insert segments
    for (segmentId, value) in jsonObject.sorted(by: { $0.key < $1.key }) {
      let segmentText: String
      if let stringValue = value as? String {
        segmentText = stringValue
      } else if let numberValue = value as? NSNumber {
        segmentText = numberValue.stringValue
      } else {
        continue
      }

      sqlite3_bind_text(segmentStmt, 1, (suttaKey as NSString).utf8String, -1, nil)
      sqlite3_bind_text(segmentStmt, 2, (segmentId as NSString).utf8String, -1, nil)
      sqlite3_bind_text(segmentStmt, 3, (segmentText as NSString).utf8String, -1, nil)

      if sqlite3_step(segmentStmt) != SQLITE_DONE {
        print("ERROR: Insert segment failed for \(suttaKey):\(segmentId)")
        exit(1)
      }
      sqlite3_reset(segmentStmt)
      insertedSegments += 1
    }

    processedSuttas += 1
    if processedSuttas % 100 == 0 {
      print("  Processed \(processedSuttas) suttas, \(insertedSegments) segments...")
    }
  }
}

let elapsed = Date().timeIntervalSince(startTime)
let dbSize = try? fileManager.attributesOfItem(atPath: dbPath)[.size] as? Int ?? 0
let dbSizeMB = Double(dbSize ?? 0) / 1_000_000

print("SUCCESS: Processed \(processedSuttas) suttas, indexed \(insertedSegments) segments")
print("  Database size: \(String(format: "%.1f", dbSizeMB)) MB")
print("  Time elapsed: \(String(format: "%.2f", elapsed))s")
