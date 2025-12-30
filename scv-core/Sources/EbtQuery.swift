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
  private let cc = ColorConsole(#file, #function, dbg.EbtQuery.other)

  /// Character set allowed in search queries
  /// Includes letters (EN, FR, PT, ES, RU), digits, parsing punctuation (. : ,
  /// - _ /),
  /// and basic regexp operators (* + ^ $ \)
  public static let allowedCharacters: CharacterSet = {
    var chars = CharacterSet.letters
    chars.formUnion(CharacterSet.decimalDigits)
    let punctuation = CharacterSet(charactersIn: ".:-_ /,;")
    chars.formUnion(punctuation)
    return chars
  }()

  /// Original query string provided by user
  public let query: String

  /// Detected search method (suttaref, lemma, phrase, keyword, regexp)
  public let method: SearchMethod

  /// Parsed sutta references (populated if method == .suttaref, empty
  /// otherwise)
  public let suttaRefs: [SuttaRef]

  /// Document language for search results
  public let docLang: String

  /// Document author for search results
  public let docAuthor: String

  /// Maximum number of results to return
  public let maxDoc: Int

  /// Initialize by parsing a query string
  /// - Parameters:
  ///   - query: The search query to parse
  ///   - docLang: Document language code (defaults to
  /// Settings.shared.docLang.code)
  ///   - docAuthor: Document author (defaults to Settings.shared.docAuthor)
  ///   - maxDoc: Maximum results (defaults to Settings.shared.maxDoc)
  public init(
    query: String,
    docLang: String? = nil,
    docAuthor: String? = nil,
    maxDoc: Int? = nil,
  ) {
    self.query = query
    self.docLang = docLang ?? Settings.shared.docLang.code
    self
      .docAuthor = docAuthor ??
      (Settings.shared.docLangSettings[Settings.shared.docLang]?.author ?? "")
    self.maxDoc = maxDoc ?? Settings.shared.maxDoc
    let (refs, method) = Self.parseQuery(
      query: query,
      docLang: self.docLang,
      docAuthor: self.docAuthor,
    )
    suttaRefs = refs
    self.method = method
  }

  /// Perform search using this parsed query
  /// Handles different search methods and creates appropriate seekers for
  /// suttarefs
  /// - Returns: SeekerResult with search items or error
  public func search() async -> SeekerResult {
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()
    if method == .suttaref {
      // Create separate seeker for each suttaRef since they may have different
      // lang/author combinations
      var allItems: [SeekerResultItem] = []
      var lastError: SearchError?
      var elapsedTime: TimeInterval = 0

      for suttaRef in suttaRefs {
        if suttaRef != nil {
          let exists = await EbtData.shared
            .querySuttaRefExists(suttaRef: suttaRef)
          if exists {
            let item = SeekerResultItem(
              suttaRef: suttaRef,
              score: 1.0,
            )
            allItems.append(item)
          } else {
            let format = NSLocalizedString("translation.not.found", comment: "")
            let message = String(
              format: format,
              suttaRef.lang,
              suttaRef.author ?? "unknown",
            )
            let detail = "\(suttaRef.toString()) not found in \(suttaRef.lang)/\(suttaRef.author ?? "unknown") database"
            cc.bad1(#line, #function, detail)
            lastError = SearchError(
              message: message,
              detail: detail,
            )
            allItems = []
            break
          }
        }
      }

      return SeekerResult(
        metadata: SearchMetadata(
          query: query,
          method: method,
          elapsedTime: CFAbsoluteTimeGetCurrent() - elapsedAtStart,
          docLang: docLang,
          docAuthor: docAuthor,
        ),
        items: allItems,
        error: lastError,
      )
    } else {
      // Lemma search uses single seeker
      do {
        let seeker = try await EbtData.shared.getSeeker(
          lang: docLang,
          author: docAuthor,
        )
        return await seeker.searchLemma(query, maxDoc: maxDoc)
      } catch {
        return SeekerResult(
          metadata: SearchMetadata(
            query: query,
            method: method,
            elapsedTime: 0,
            docLang: docLang,
            docAuthor: docAuthor,
            maxDoc: maxDoc,
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
  ///   - docLang: Default document language code for sutta reference parsing
  ///   - docAuthor: Default document author for sutta reference parsing
  /// - Returns: Tuple of (suttaRefs, detectedMethod)
  static func parseQuery(
    query: String,
    method: SearchMethod? = nil,
    docLang: String = Settings.shared.docLang.code,
    docAuthor: String = Settings.shared
      .docLangSettings[Settings.shared.docLang]?.author ?? "",
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
        defaultLang: docLang,
        defaultAuthor: docAuthor,
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
