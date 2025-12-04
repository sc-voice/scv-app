//
//  AttributedTextCache.swift
//  scv-core
//
//  Created by Claude on 2025-12-03.
//

import Foundation

#if canImport(SwiftUI)
  import SwiftUI
#endif

/// Cache for attributed text results, keyed by HTML string
/// Only caches AttributedString when explicitly set via populate()
/// Returns nil for uncached entries, allowing fallback to plain text
public class AttributedTextCache: ObservableObject {
  private var cache: [String: AttributedString] = [:]
  private let lock = NSLock()

  public init() {}

  /// Get cached attributed text for HTML string
  /// - Parameter html: The HTML string key
  /// - Returns: AttributedString if cached, nil otherwise
  public func get(_ html: String) -> AttributedString? {
    lock.lock()
    defer { lock.unlock() }
    return cache[html]
  }

  /// Populate cache with attributed text for HTML string
  /// - Parameters:
  ///   - html: The HTML string key
  ///   - attributedString: The attributed text to cache
  public func populate(_ html: String,
                       with attributedString: AttributedString)
  {
    lock.lock()
    defer { lock.unlock() }
    cache[html] = attributedString
  }

  /// Clear specific entry from cache
  public func remove(_ html: String) {
    lock.lock()
    defer { lock.unlock() }
    cache.removeValue(forKey: html)
  }

  /// Clear entire cache
  public func clear() {
    lock.lock()
    defer { lock.unlock() }
    cache.removeAll()
  }

  /// Get cache size (for debugging)
  public var size: Int {
    lock.lock()
    defer { lock.unlock() }
    return cache.count
  }
}
