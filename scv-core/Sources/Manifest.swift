//
//  Manifest.swift
//  scv-core
//
//  Created by Visakha on 15/11/2025.
//

import Foundation

/// Files breakdown for a database (sutta/vinaya/abhidhamma/other counts)
public struct FilesBreakdown: Codable, Sendable, Equatable {
  public let sutta: Int
  public let vinaya: Int
  public let abhidhamma: Int
  public let other: Int
  public let total: Int

  public init(
    sutta: Int = 0,
    vinaya: Int = 0,
    abhidhamma: Int = 0,
    other: Int = 0,
    total: Int = 0,
  ) {
    self.sutta = sutta
    self.vinaya = vinaya
    self.abhidhamma = abhidhamma
    self.other = other
    self.total = total
  }

  enum CodingKeys: String, CodingKey {
    case sutta
    case vinaya
    case abhidhamma
    case other
    case total
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    sutta = try container.decodeIfPresent(Int.self, forKey: .sutta) ?? 0
    vinaya = try container.decodeIfPresent(Int.self, forKey: .vinaya) ?? 0
    abhidhamma = try container
      .decodeIfPresent(Int.self, forKey: .abhidhamma) ?? 0
    other = try container.decodeIfPresent(Int.self, forKey: .other) ?? 0
    total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
  }
}

/// Database manifest containing metadata for all bundled databases
/// Generated from db-manifest.json at build time
public struct DatabaseManifest: Codable, Sendable {
  public let databases: [DatabaseInfo]

  /// Manifest singleton (generated at build time from db-manifest.json)
  public static let shared = generated

  /// Get database info for specific language/author
  public func info(language: String, author: String) -> DatabaseInfo? {
    databases.first { $0.language == language && $0.author == author }
  }

  /// Get all authors for specific language
  public func authorsForLanguage(_ language: String) -> [DatabaseInfo] {
    databases.filter { $0.language == language }
  }

  /// Get all authors for specific language sorted by file count (descending)
  public func authorsForLanguageSortedByFiles(_ language: String)
    -> [DatabaseInfo]
  {
    authorsForLanguage(language).sorted { $0.files.total > $1.files.total }
  }

  /// Get default (most comprehensive) author for language by file count
  public func defaultAuthorForLanguage(_ language: String) -> DatabaseInfo? {
    authorsForLanguageSortedByFiles(language).first
  }

  /// Checks if a SuttaRef exists in the database
  /// - Parameters:
  ///   - suttaRef: The SuttaRef to check
  /// - Returns: true if the sutta/lang/author combination exists, false if
  /// author is nil
  public func suttaRefExists(_ suttaRef: SuttaRef) -> Bool {
    guard let author = suttaRef.author else { return false }
    return info(language: suttaRef.lang, author: author) != nil
  }
}

/// Information about a single database
public struct DatabaseInfo: Codable, Identifiable, Sendable, Equatable {
  public let id: String
  public let language: String
  public let author: String
  public let authorName: String
  public let buildTimestamp: String
  public let files: FilesBreakdown
  public let gitHash: String?
  public let json: String?

  enum CodingKeys: String, CodingKey {
    case language
    case author
    case authorName
    case buildTimestamp
    case files
    case gitHash
    case json
  }

  public init(
    language: String,
    author: String,
    authorName: String,
    buildTimestamp: String,
    files: FilesBreakdown,
    gitHash: String? = nil,
    json: String? = nil,
  ) {
    id = "\(language)/\(author)"
    self.language = language
    self.author = author
    self.authorName = authorName
    self.buildTimestamp = buildTimestamp
    self.files = files
    self.gitHash = gitHash
    self.json = json
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    language = try container.decode(String.self, forKey: .language)
    author = try container.decode(String.self, forKey: .author)
    authorName = try container.decodeIfPresent(
      String.self,
      forKey: .authorName,
    ) ?? ""
    buildTimestamp = try container.decodeIfPresent(
      String.self,
      forKey: .buildTimestamp,
    ) ?? ""
    // Decode files as FilesBreakdown (v5 schema) or create from Int (legacy)
    do {
      files = try container.decode(FilesBreakdown.self, forKey: .files)
    } catch {
      // Fallback for legacy format (Int)
      if let legacyTotal = try container.decodeIfPresent(
        Int.self,
        forKey: .files,
      ) {
        files = FilesBreakdown(total: legacyTotal)
      } else {
        files = FilesBreakdown()
      }
    }
    gitHash = try container.decodeIfPresent(String.self, forKey: .gitHash)
    json = try container.decodeIfPresent(String.self, forKey: .json)
    id = "\(language)/\(author)"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(language, forKey: .language)
    try container.encode(author, forKey: .author)
    try container.encode(authorName, forKey: .authorName)
    try container.encode(buildTimestamp, forKey: .buildTimestamp)
    try container.encode(files, forKey: .files)
    if let gitHash {
      try container.encode(gitHash, forKey: .gitHash)
    }
    if let json {
      try container.encode(json, forKey: .json)
    }
  }
}
