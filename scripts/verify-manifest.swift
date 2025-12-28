#!/usr/bin/env swift
import Foundation

// Verify that all databases declared in manifest.json exist as .zst files
func verifyManifest() {
  let manifestPath = "scv-core/Sources/Resources/db-manifest.json"
  let resourcesDir = "scv-core/Sources/Resources"

  guard let manifestData =
    try? Data(contentsOf: URL(fileURLWithPath: manifestPath))
  else {
    print("Error: Could not read manifest at \(manifestPath)")
    exit(1)
  }

  guard
    let json = try? JSONSerialization
    .jsonObject(with: manifestData) as? [String: Any],
    let databases = json["databases"] as? [[String: Any]]
  else {
    print("Error: Could not parse manifest JSON")
    exit(1)
  }

  var missing: [(String, String)] = []

  for db in databases {
    guard let language = db["language"] as? String,
          let author = db["author"] as? String
    else {
      continue
    }

    let fileName = "ebt-\(language)-\(author).db.zst"
    let filePath = "\(resourcesDir)/\(fileName)"

    if !FileManager.default.fileExists(atPath: filePath) {
      missing.append((language, author))
    }
  }

  if missing.isEmpty {
    exit(0)
  } else {
    for (lang, author) in missing {
      print("\(lang)/\(author)")
    }
    exit(1)
  }
}

verifyManifest()
