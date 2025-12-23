import Foundation

/// Represents a single node in the Tipiṭaka reference tree
public struct TipitakaRef: Identifiable, Hashable, Codable, Sendable {
  public let id: String // path like "/sutta" or "/sutta/sn/sn1"
  public let name: String // Pali text
  public let caption: String? // Translation
  public var children: [TipitakaRef]?

  /// Creates a new TipitakaRef with path, Pali name, and optional translation
  /// caption
  public init(
    id: String,
    name: String,
    caption: String? = nil,
    children: [TipitakaRef]? = nil,
  ) {
    self.id = id
    self.name = name
    self.caption = caption
    self.children = children
  }
}

// MARK: - Tipitaka Tree Building

public enum Tipitaka {
  /// Constructs a nested tree from a flat list of refs with paths
  ///
  /// Parses paths to determine parent-child relationships and organizes
  /// refs into a tree suitable for OutlineGroup rendering.
  ///
  /// - Parameter flatRefs: Flat array of refs from db-manifest
  /// - Returns: Array of root-level refs with nested children
  public static func buildTree(from flatRefs: [TipitakaRef]) -> [TipitakaRef] {
    var refsByPath: [String: TipitakaRef] = [:]

    // Index all refs by path
    for ref in flatRefs {
      refsByPath[ref.id] = ref
    }

    // Build parent-child relationships bottom-up
    // Sort by path length (deepest first) so children are built before parents
    let sortedPaths = refsByPath.keys.sorted { path1, path2 in
      path1.split(separator: "/").count > path2.split(separator: "/").count
    }

    for path in sortedPaths {
      guard var ref = refsByPath[path] else { continue }
      let segments = path.split(separator: "/", omittingEmptySubsequences: true)

      // Find all direct children (paths with exactly one more segment)
      let children = refsByPath.values.filter { candidate in
        let candidateSegments = candidate.id.split(
          separator: "/",
          omittingEmptySubsequences: true,
        )
        return candidateSegments.count == segments.count + 1 &&
          candidate.id.hasPrefix(path + "/")
      }

      if !children.isEmpty {
        ref.children = children.sorted { $0.id < $1.id }
        refsByPath[path] = ref
      }
    }

    // Return root level only (depth 1, like "/sutta", "/vinaya")
    return refsByPath.values
      .filter {
        $0.id.split(separator: "/", omittingEmptySubsequences: true).count == 1
      }
      .sorted { $0.id < $1.id }
  }

  /// Searches for a ref by its path ID in the tree
  ///
  /// - Parameters:
  ///   - id: Path to search for (e.g., "/sutta/sn/sn1")
  ///   - tree: Root-level refs to search within
  /// - Returns: The matching ref, or nil if not found
  public static func findRef(byId id: String,
                             in tree: [TipitakaRef]) -> TipitakaRef?
  {
    for ref in tree {
      if ref.id == id {
        return ref
      }
      if let children = ref.children,
         let found = findRef(byId: id, in: children)
      {
        return found
      }
    }
    return nil
  }
}
