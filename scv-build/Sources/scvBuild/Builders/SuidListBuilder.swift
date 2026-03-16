import Foundation
import scvCore
import SQLite3

public class SuidListBuilder {
  private let projectRoot: String
  private let buildDir: String
  private let resourcesDir: String

  public init(projectRoot: String) {
    self.projectRoot = projectRoot
    buildDir = "\(projectRoot)/local/build"
    resourcesDir = "\(projectRoot)/scv-core/Sources/Resources"
  }

  public func build() throws {
    let dbPath = "\(buildDir)/ebt-pli-ms.db"
    let outputPath = "\(projectRoot)/scv-core/Sources/SuidListData.swift"

    guard FileManager.default.fileExists(atPath: dbPath) else {
      throw SuidListBuilderError.databaseNotFound(dbPath)
    }

    // Open database
    var db: OpaquePointer?
    guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
      throw SuidListBuilderError
        .databaseOpenFailed(String(cString: sqlite3_errmsg(db)))
    }

    defer { sqlite3_close(db) }

    // Query all suttaUids from suttas table
    var statement: OpaquePointer?
    let query = "SELECT suttaUid FROM suttas ORDER BY suttaUid"

    guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
      throw SuidListBuilderError
        .queryFailed(String(cString: sqlite3_errmsg(db)))
    }

    defer { sqlite3_finalize(statement) }

    var suttauids: [String] = []

    while sqlite3_step(statement) == SQLITE_ROW {
      if let cString = sqlite3_column_text(statement, 0) {
        let suttauid = String(cString: cString)
        suttauids.append(suttauid)
      }
    }

    // Sort by SuttaCentralId.compareLow, with compareHigh as tiebreaker
    suttauids.sort { a, b in
      let cmpLow = SuttaCentralId.compareLow(a, b)
      if cmpLow != 0 {
        return cmpLow < 0
      }
      return SuttaCentralId.compareHigh(a, b) < 0
    }

    // Generate Swift file with array constant
    let quotedUids = suttauids.map { "\"\($0)\"" }
    let swiftCode = """
    // Auto-generated file: SuidListData.swift
    // Generated from EBT database suttas table
    // DO NOT EDIT MANUALLY

    let SUID_LIST: [String] = [
    \(quotedUids.joined(separator: ",\n"))
    ]
    """

    try swiftCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
  }
}

enum SuidListBuilderError: Error {
  case databaseNotFound(String)
  case databaseOpenFailed(String)
  case queryFailed(String)
}
