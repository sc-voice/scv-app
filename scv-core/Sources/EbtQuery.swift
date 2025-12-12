//
//  EbtQuery.swift
//  scv-core
//
//  Created by Claude on 2025-12-12.
//

import Foundation

/// Represents a parsed Buddhist text search query
/// Encapsulates the original query, detected search method, and any parsed
/// sutta references
/// Calls on EbtSeeker to handle specific lang/author queries
public class EbtQuery {
  /// Original query string provided by user
  public let query: String

  /// Detected search method (suttaref, lemma, phrase, keyword, regexp)
  public let method: SearchMethod

  /// Parsed sutta references (populated if method == .suttaref, empty
  /// otherwise)
  public let suttaRefs: [SuttaRef]

  /// Settings used for search (lang/author defaults)
  private let settings: Settings

  /// Initialize by parsing a query string
  /// - Parameters:
  ///   - query: The search query to parse
  ///   - settings: Settings providing default language and author (defaults to
  /// Settings.shared)
  public init(query: String, settings: Settings = Settings.shared) {
    self.query = query
    self.settings = settings
    let (refs, method) = Self.parseQuery(query: query, settings: settings)
    suttaRefs = refs
    self.method = method
  }

  /// Perform search using this parsed query
  /// Handles different search methods and creates appropriate seekers for
  /// suttarefs
  /// - Returns: SeekerResult with search items or error
  public func search() async -> SeekerResult {
    if method == .suttaref {
      // Create separate seeker for each suttaRef since they may have different
      // lang/author combinations
      var allItems: [SeekerResultItem] = []
      var lastError: SearchError?
      var elapsedTime: TimeInterval = 0

      for suttaRef in suttaRefs {
        do {
          let seeker = try await EbtData.shared.getSeeker(
            lang: suttaRef.lang,
            author: suttaRef.author ?? settings.docAuthor,
          )
          let result = await seeker.search(
            query: suttaRef.toString(),
            method: .suttaref,
          )
          allItems.append(contentsOf: result.items)
          elapsedTime += result.metadata.elapsedTime
          if result.error != nil {
            lastError = result.error
          }
        } catch {
          lastError = SearchError(
            message: "Failed to get seeker for \(suttaRef)",
            detail: error.localizedDescription,
          )
        }
      }

      return SeekerResult(
        metadata: SearchMetadata(
          query: query,
          method: method,
          elapsedTime: elapsedTime,
          docLang: settings.docLang.code,
          docAuthor: settings.docAuthor,
        ),
        items: allItems,
        error: lastError,
      )
    } else {
      // Lemma search uses single seeker with settings defaults
      do {
        let seeker = try await EbtData.shared.getSeeker(
          lang: settings.docLang.code,
          author: settings.docAuthor,
        )
        return await seeker.searchLemma(query)
      } catch {
        return SeekerResult(
          metadata: SearchMetadata(
            query: query,
            method: method,
            elapsedTime: 0,
            docLang: settings.docLang.code,
            docAuthor: settings.docAuthor,
          ),
          items: [],
          error: SearchError(
            message: "Failed to get seeker",
            detail: error.localizedDescription,
          ),
        )
      }
    }
  }

  /// Parse a query string into sutta references and detect search method
  /// - Parameters:
  ///   - query: The search query to parse
  ///   - method: Optional explicit search method (auto-detect if nil)
  ///   - settings: Settings providing default language and author
  /// - Returns: Tuple of (suttaRefs, detectedMethod)
  static func parseQuery(
    query: String,
    method: SearchMethod? = nil,
    settings: Settings = Settings.shared,
  ) -> (suttaRefs: [SuttaRef], method: SearchMethod) {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    let entries = trimmed.split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }

    // Try to parse each entry as a SuttaRef with language-specific defaults
    var suttaRefs: [SuttaRef] = []
    for entry in entries {
      // Try parsing with docLang/docAuthor as defaults
      if let ref = SuttaRef.create(
        entry,
        defaultLang: settings.docLang.code,
        defaultAuthor: settings.docAuthor,
      ) {
        suttaRefs.append(ref)
      }
    }

    // Determine method based on whether all entries were valid scids
    let resultMethod: SearchMethod = if !suttaRefs.isEmpty {
      .suttaref
    } else {
      method ?? .lemma
    }

    return (suttaRefs: suttaRefs, method: resultMethod)
  }
}
