//
//  AutoComplete.swift
//  scv-core
//
//  Created by Claude on 2025-12-25.
//

import Foundation

// MARK: - MonthUsage

/// Tracks usage count for a specific year/month combination
public struct MonthUsage: Codable, Sendable {
  public let year: Int
  public let month: Int
  public var count: Int

  public init(year: Int, month: Int, count: Int) {
    self.year = year
    self.month = month
    self.count = count
  }
}

// MARK: - PhraseAsset

/// Represents a tracked phrase (normalized to lemma form)
/// Stores usage history, utility metrics, and the original phrase text
public struct PhraseAsset: Codable, Sendable {
  /// Normalized form of phrase (lemmatized) - used as storage key
  public let lemma: String

  /// Original phrase text as typed by user
  public var lastUsedPhrase: String

  /// Timestamp when phrase was first tracked
  public let created: Date

  /// Timestamp of last usage
  public var lastUsed: Date

  /// Number of documents matched by this phrase in latest search
  /// Used to calculate utility: inverse of documentCount
  /// 0 if search returned no results
  public var documentCount: Int

  /// Usage counts by year/month
  public var usesByMonth: [MonthUsage]

  /// Utility score: inversely proportional to documentCount
  /// Returns 0.0 if documentCount is 0
  public var utility: Double {
    documentCount == 0 ? 0.0 : 1.0 / Double(documentCount)
  }

  public init(
    lemma: String,
    lastUsedPhrase: String,
    created: Date,
    lastUsed: Date,
    documentCount: Int,
    usesByMonth: [MonthUsage] = [],
  ) {
    self.lemma = lemma
    self.lastUsedPhrase = lastUsedPhrase
    self.created = created
    self.lastUsed = lastUsed
    self.documentCount = documentCount
    self.usesByMonth = usesByMonth
  }
}

// MARK: - PhrasesByAuthorLang

/// Groups phrases for a specific author/language combination
public struct PhrasesByAuthorLang: Codable, Sendable {
  public let author: String
  public let lang: String
  public var phrases: [String: PhraseAsset]

  public init(
    author: String,
    lang: String,
    phrases: [String: PhraseAsset] = [:],
  ) {
    self.author = author
    self.lang = lang
    self.phrases = phrases
  }
}

// MARK: - AutoComplete

/// Singleton for tracking and suggesting user phrases
/// Learns from search usage to provide autocomplete suggestions
/// Persistence: stored in Settings.autoCompleteData
public final class AutoComplete: @unchecked Sendable {
  let cc = ColorConsole(#file, #function, dbg.AutoComplete.other)

  /// Shared singleton instance
  /// nonisolated(unsafe): singleton initialized once, safe to access from any
  /// thread
  public nonisolated(unsafe) static let shared = AutoComplete()

  /// Phrase data organized by author:lang key
  /// Key format: "author:lang"
  /// Marked internal for testing access (not private)
  nonisolated(unsafe) var phrasesMap: [String: PhrasesByAuthorLang] = [:]

  /// Lemmatizers cached by language
  private nonisolated(unsafe) var lemmatizers: [String: Lemmatizer] = [:]

  /// Settings instance for persistence
  private let settings: Settings

  /// Initialize with optional Settings instance
  /// - Parameter settings: Settings instance to use for persistence (defaults
  /// to Settings.shared)
  public init(settings: Settings? = nil) {
    self.settings = settings ?? Settings.shared
    load()
    cc.ok1(#line, "AutoComplete initialized")
  }

  /// Private initializer for singleton (uses Settings.shared)
  private static let _sharedInstance = AutoComplete(settings: Settings.shared)

  // MARK: - Private Helpers

  /// Create composite key for author/lang combination
  private func makeKey(author: String, lang: String) -> String {
    "\(author):\(lang)"
  }

  /// Get current year and month
  private func currentYearMonth() -> (year: Int, month: Int) {
    let now = Date()
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: now)
    return (components.year ?? 2025, components.month ?? 1)
  }

  /// Get or create lemmatizer for language
  private func getLemmatizer(
    lang: String,
    cacheDir: String = NSSearchPathForDirectoriesInDomains(
      .cachesDirectory,
      .userDomainMask,
      true,
    ).first ?? "",
  ) -> Lemmatizer {
    if let cached = lemmatizers[lang] {
      return cached
    }
    let lemmatizer = Lemmatizer(lang: lang, cacheDir: cacheDir)
    lemmatizers[lang] = lemmatizer
    return lemmatizer
  }

  /// Lemmatize phrase if lemma not provided
  private func resolveLemma(
    phrase: String,
    lemma: String?,
    lang: String,
  ) -> String {
    if let providedLemma = lemma {
      return providedLemma
    }

    var lemmatizer = getLemmatizer(lang: lang)
    let lemmas = lemmatizer.lemmatize(phrase)
    lemmatizer.saveCache()

    // Update cached lemmatizer with cache changes
    lemmatizers[lang] = lemmatizer

    // Return lemmatized phrase as space-separated words
    return lemmas.joined(separator: " ")
  }

  // MARK: - Public API

  /// Track usage of a phrase (typically after search completion)
  /// - Parameters:
  ///   - phrase: Original phrase typed by user
  ///   - lemma: Pre-computed lemma (optional; computed if nil)
  ///   - documentCount: Number of documents matched by search
  ///   - author: Document author
  ///   - lang: Document language code
  public func track(
    phrase: String,
    lemma: String? = nil,
    documentCount: Int,
    author: String,
    lang: String,
  ) {
    let key = makeKey(author: author, lang: lang)
    let resolvedLemma = resolveLemma(phrase: phrase, lemma: lemma, lang: lang)
    let now = Date()
    let (year, month) = currentYearMonth()

    cc.ok1(
      #line,
      "Tracking phrase:",
      phrase,
      "lemma:",
      resolvedLemma,
      "docs:",
      documentCount,
    )

    // Get or create PhrasesByAuthorLang entry
    if phrasesMap[key] == nil {
      phrasesMap[key] = PhrasesByAuthorLang(author: author, lang: lang)
    }

    // Get or create PhraseAsset by lemma
    if phrasesMap[key]?.phrases[resolvedLemma] == nil {
      let newPhraseAsset = PhraseAsset(
        lemma: resolvedLemma,
        lastUsedPhrase: phrase,
        created: now,
        lastUsed: now,
        documentCount: documentCount,
        usesByMonth: [MonthUsage(year: year, month: month, count: 1)],
      )
      phrasesMap[key]?.phrases[resolvedLemma] = newPhraseAsset
      cc.ok2(#line, "Created new phrase:", resolvedLemma)
    } else {
      // Update existing phrase asset
      var phraseAsset = phrasesMap[key]?.phrases[resolvedLemma]!
      phraseAsset?.lastUsedPhrase = phrase // Original user text
      phraseAsset?.lastUsed = now
      phraseAsset?.documentCount = documentCount

      // Update or create usesByMonth entry
      if let index = phraseAsset?.usesByMonth.firstIndex(
        where: { $0.year == year && $0.month == month },
      ) {
        phraseAsset?.usesByMonth[index].count += 1
      } else {
        phraseAsset?.usesByMonth.append(MonthUsage(
          year: year,
          month: month,
          count: 1,
        ))
      }

      phrasesMap[key]?.phrases[resolvedLemma] = phraseAsset!
      cc.ok2(
        #line,
        "Updated phrase:",
        resolvedLemma,
        "new usesByMonth count:",
        phraseAsset?.usesByMonth.count ?? 0,
      )
    }

    save()
  }

  /// Suggest phrases matching a prefix
  /// Filters by lastUsedPhrase prefix, ranks by utility then lastUsed
  /// - Parameters:
  ///   - prefix: Partial phrase prefix to match
  ///   - author: Filter by document author
  ///   - lang: Filter by language
  /// - Returns: Sorted array of matching phrase assets
  public func suggest(
    prefix: String,
    author: String,
    lang: String,
  ) -> [PhraseAsset] {
    let key = makeKey(author: author, lang: lang)
    guard let phrasesByAuthorLang = phrasesMap[key] else {
      cc.ok2(#line, "No phrases for:", key)
      return []
    }

    let prefixLower = prefix.lowercased()

    // Filter by prefix match on lastUsedPhrase (case-insensitive) and exclude
    // zero-utility phrases
    let matching = phrasesByAuthorLang.phrases.values
      .filter {
        $0.lastUsedPhrase.lowercased().hasPrefix(prefixLower) && $0.utility > 0
      }
      .sorted { lhs, rhs in
        // Sort by utility desc, then lastUsed desc
        if lhs.utility != rhs.utility {
          return lhs.utility > rhs.utility
        }
        return lhs.lastUsed > rhs.lastUsed
      }

    cc.ok2(
      #line,
      "suggest for prefix:",
      prefix,
      "found:",
      matching.count,
      "results",
    )

    return matching
  }

  // MARK: - Persistence

  /// Save phrases to Settings
  public func save() {
    let data = Array(phrasesMap.values)
    settings.autoCompleteData = data
    settings.save()
    cc.ok1(#line, "Saved \(data.count) author:lang entries")
  }

  /// Load phrases from Settings
  public func load() {
    let data = settings.autoCompleteData
    phrasesMap = [:]

    for entry in data {
      let key = makeKey(author: entry.author, lang: entry.lang)
      phrasesMap[key] = entry
    }

    cc.ok1(#line, "Loaded \(phrasesMap.count) author:lang entries")
  }

  /// Remove a specific phrase from tracking
  /// - Parameters:
  ///   - phrase: Lemmatized phrase to remove
  ///   - author: Document author
  ///   - lang: Language code
  public func removePhrase(
    phrase: String,
    author: String,
    lang: String,
  ) {
    let key = makeKey(author: author, lang: lang)
    guard phrasesMap[key] != nil else {
      cc.ok2(#line, "No phrases for:", key)
      return
    }

    if phrasesMap[key]?.phrases.removeValue(forKey: phrase) != nil {
      cc.ok2(#line, "Removed phrase:", phrase)
      save()
    } else {
      cc.ok2(#line, "Phrase not found:", phrase)
    }
  }
}
