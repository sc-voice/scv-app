//
//  Manifest.swift
//  scv-core
//
//  Created by Visakha on 15/11/2025.
//

import Foundation

/// Database manifest containing metadata for all bundled databases
/// Loaded from db-manifest.json at app startup
public struct DatabaseManifest: Codable {
  public let databases: [DatabaseInfo]

  /// Load manifest from bundle
  public static func load() -> DatabaseManifest? {
    guard let manifestURL = Bundle.module.url(
      forResource: "db-manifest",
      withExtension: "json",
    ) else {
      return nil
    }

    do {
      let data = try Data(contentsOf: manifestURL)
      let decoder = JSONDecoder()
      return try decoder.decode(DatabaseManifest.self, from: data)
    } catch {
      return nil
    }
  }

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
    authorsForLanguage(language).sorted { $0.files > $1.files }
  }

  /// Get default (most comprehensive) author for language by file count
  public func defaultAuthorForLanguage(_ language: String) -> DatabaseInfo? {
    authorsForLanguageSortedByFiles(language).first
  }
}

/// Information about a single database
public struct DatabaseInfo: Codable, Identifiable {
  public let id: String
  public let language: String
  public let author: String
  public let authorName: String
  public let buildTimestamp: String
  public let files: Int
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
    files: Int,
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
    authorName = try container.decode(String.self, forKey: .authorName)
    buildTimestamp = try container.decode(String.self, forKey: .buildTimestamp)
    files = try container.decode(Int.self, forKey: .files)
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
