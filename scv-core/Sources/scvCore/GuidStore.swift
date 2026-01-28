//
//  GuidStore.swift
//  scv-core
//
//  Swift implementation of file-based storage for GUID-identified items
//  with hierarchical directory organization.
//

import Foundation

/// Configuration for GuidStore
struct GuidStoreConfig {
  /// Root directory name for the store
  var storeName: String = "guid-store"

  /// Number of characters from GUID to use for chapter subdirectory
  var folderPrefix: Int = 2

  /// Default file extension/suffix
  var suffix: String = ""

  /// Default volume name
  var defaultVolume: String = "common"

  /// Custom store path (auto-computed from documents folder if nil)
  var storePath: URL?
}

/// File-based storage system for GUID-identified items with hierarchical
/// directory organization
final class GuidStore: @unchecked Sendable {
  let storePath: URL
  let folderPrefix: Int
  let suffix: String
  let defaultVolume: String

  private let fileManager = FileManager.default
  private let lock = NSLock()

  /// Initialize GuidStore with configuration
  /// - Parameter config: Configuration options
  init(config: GuidStoreConfig = GuidStoreConfig()) {
    folderPrefix = config.folderPrefix
    suffix = config.suffix
    defaultVolume = config.defaultVolume

    // Determine store path
    if let customPath = config.storePath {
      storePath = customPath
    } else {
      let documentsUrl = fileManager.urls(
        for: .documentDirectory,
        in: .userDomainMask,
      )[0]
      storePath = documentsUrl.appendingPathComponent(config.storeName)
    }

    // Create store directory (protected by lock)
    lock.lock()
    defer { lock.unlock() }
    try? fileManager.createDirectory(
      at: storePath,
      withIntermediateDirectories: true,
    )
  }

  /// Resolve file path for a GUID
  /// - Parameters:
  ///   - guid: The GUID identifier
  ///   - volume: Volume name (defaults to instance default)
  ///   - suffix: File suffix/extension (defaults to instance default)
  /// - Returns: URL to the file location
  func guidPath(guid: String, volume: String? = nil,
                suffix: String? = nil) -> URL
  {
    let vol = volume ?? defaultVolume
    let suf = suffix ?? self.suffix
    return guidPath(guid: guid, volume: vol, chapter: nil, suffix: suf)
  }

  /// Resolve file path for a GUID with explicit chapter
  /// - Parameters:
  ///   - guid: The GUID identifier
  ///   - volume: Volume name
  ///   - chapter: Explicit chapter subdirectory name
  ///   - suffix: File suffix/extension
  /// - Returns: URL to the file location
  func guidPath(guid: String, volume: String, chapter: String?,
                suffix: String) -> URL
  {
    // Create volume directory (protected by lock)
    lock.lock()
    defer { lock.unlock() }

    let volumePath = storePath.appendingPathComponent(volume)
    try? fileManager.createDirectory(
      at: volumePath,
      withIntermediateDirectories: true,
    )

    // Determine chapter from GUID prefix if not specified
    let chapterName = chapter ?? String(guid.prefix(folderPrefix))

    // Create chapter directory
    let chapterPath = volumePath.appendingPathComponent(chapterName)
    try? fileManager.createDirectory(
      at: chapterPath,
      withIntermediateDirectories: true,
    )

    // Return file path
    return chapterPath.appendingPathComponent(guid + suffix)
  }

  /// Resolve file path from a signature object
  /// - Parameters:
  ///   - signature: Dictionary with at least a "guid" key
  ///   - volume: Volume name (defaults to instance default, can be overridden
  /// in signature)
  ///   - suffix: File suffix/extension (defaults to instance default, can be
  /// overridden in signature)
  /// - Returns: URL to the file location
  func signaturePath(
    _ signature: [String: Any],
    volume: String? = nil,
    suffix: String? = nil,
  ) -> URL {
    guard let guid = signature["guid"] as? String else {
      fatalError("Signature must contain 'guid' key")
    }

    let vol = (signature["volume"] as? String) ?? volume ?? defaultVolume
    let suf = (signature["suffix"] as? String) ?? suffix ?? self.suffix
    let chapter = signature["chapter"] as? String

    return guidPath(guid: guid, volume: vol, chapter: chapter, suffix: suf)
  }

  /// Asynchronously list all volumes in the store
  /// - Returns: Array of volume names
  nonisolated func listVolumes() async throws -> [String] {
    return try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return [] }
      let contents = try self.fileManager.contentsOfDirectory(
        at: self.storePath,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles],
      )
      return contents.map(\.lastPathComponent)
    }.value
  }

  /// Asynchronously delete all files in a volume
  /// - Parameter volume: Volume name to clear
  /// - Returns: Count of deleted files
  nonisolated func clearVolume(_ volume: String) async throws -> Int {
    return try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return 0 }

      let volumePath = self.storePath.appendingPathComponent(volume)

      guard self.fileManager.fileExists(atPath: volumePath.path) else {
        return 0
      }

      var count = 0

      // Recursively collect all file URLs
      func collectFiles(at path: URL) throws -> [URL] {
        var files: [URL] = []
        let contents = try self.fileManager.contentsOfDirectory(
          at: path,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles],
        )
        for item in contents {
          var isDir: ObjCBool = false
          if self.fileManager.fileExists(atPath: item.path, isDirectory: &isDir) {
            if isDir.boolValue {
              try files.append(contentsOf: collectFiles(at: item))
            } else {
              files.append(item)
            }
          }
        }
        return files
      }

      // Get all files and delete them
      let files = try collectFiles(at: volumePath)
      for fileUrl in files {
        try self.fileManager.removeItem(at: fileUrl)
        count += 1
      }

      // Try to remove the volume directory if empty
      try? self.fileManager.removeItem(at: volumePath)

      return count
    }.value
  }
}
