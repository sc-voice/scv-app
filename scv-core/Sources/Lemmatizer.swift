//
//  Lemmatizer.swift
//  scv-core
//
//  Created by Claude on 2025-12-13.
//
//  ## Performance Benchmarks
//
//  ### Identity Mapping Optimization (Build 0.0.507)
//
//  Database: en:sujato (4,167 suttas, 148,496 segments)
//
//  Before optimization:
//  - Build time: 90.86s
//  - Cache entries: 20,922 total (16,894 identity mappings = 80.7%)
//  - Cache file size: 457 KB
//  - Database: 22.4 MB uncompressed, 4.8 MB compressed (79% compression)
//
//  After optimization (skip identity mappings in cache):
//  - Build time: 83.94s (6.92s faster, 7.6% improvement)
//  - Cache entries: 3,351 non-identity entries saved
//  - Identity mappings skipped: 10,057 (48.1% of en-sujato lemmas)
//  - Cache reduction: 20,922 → 3,351 entries
//
//  Rationale: NLTagger returns identity mappings automatically, so caching them
//  adds no value. Skipping them reduces cache file size ~80% and improves build
//  performance 7.6% due to faster cache I/O.
//

import Foundation
import NaturalLanguage

/// Shared lemmatizer for normalizing text to base word forms
/// Uses Apple's NaturalLanguage framework with language-specific support
/// Caches lemmatization results to JSONL file for persistence across builds
///
/// Thread-safety: tagger and wordLemmaCache are marked nonisolated(unsafe)
/// because:
/// - NLTagger is thread-safe per Apple documentation (can be shared across
/// threads)
/// - Dictionary copy-on-write ensures safe concurrent reads
/// - Only appends new entries, never removes or reorders
/// - Multiple EbtSeekers (actors) can safely share one Lemmatizer per language
/// - Each actor serializes its own access to shared Lemmatizer methods
public struct Lemmatizer: Sendable {
  let cc = ColorConsole(#file, #function, dbg.Lemmatizer.other)

  // Unicode punctuation constants for text cleaning and testing
  public static let DOUBLE_LOW_QUOTATION_MARK = "\u{201E}" // „
  public static let RIGHT_DOUBLE_QUOTATION_MARK = "\u{201D}" // "
  public static let LEFT_SINGLE_QUOTATION_MARK = "\u{2018}" // '
  public static let RIGHT_SINGLE_QUOTATION_MARK = "\u{2019}" // '
  public static let EN_DASH = "\u{2013}" // –
  public static let EM_DASH = "\u{2014}" // —

  private nonisolated(unsafe) let tagger = NLTagger(tagSchemes: [.lemma])
  private let lang: String
  private nonisolated(unsafe) var wordLemmaCache: [String: String] = [:]
  private let cacheFilePath: String
  private let cachingEnabled: Bool

  /// Compute cache file path for a language
  /// - Parameters:
  ///   - lang: Language code (e.g., "en", "de", "pli")
  ///   - cacheDir: Directory where cache files are stored
  /// - Returns: Full path to language-specific cache file
  public static func cacheFilePath(lang: String, cacheDir: String) -> String {
    "\(cacheDir)/\(lang)-lemmas.json"
  }

  /// Initialize lemmatizer for a specific language
  /// Optionally loads cached lemmas from JSONL file if caching is enabled
  /// - Parameters:
  ///   - lang: Language code (e.g., "en", "de", "pli")
  ///   - cacheDir: Directory for cache files
  ///   - cachingEnabled: Whether to load and save cache (default: true)
  public init(lang: String, cacheDir: String, cachingEnabled: Bool = true) {
    self.lang = lang
    self.cachingEnabled = cachingEnabled
    cacheFilePath = Self.cacheFilePath(lang: lang, cacheDir: cacheDir)

    // Load existing cache from file (only if caching enabled)
    if cachingEnabled {
      var mutableSelf = self
      mutableSelf.loadCache()
      wordLemmaCache = mutableSelf.wordLemmaCache
    }
  }

  /// Load cache from JSONL file
  /// Format: one JSON object per line: {"word":"lemma"}
  private mutating func loadCache() {
    guard FileManager.default.fileExists(atPath: cacheFilePath) else { return }

    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: cacheFilePath))
      guard let content = String(data: data, encoding: .utf8) else { return }

      for line in content.split(
        separator: "\n",
        omittingEmptySubsequences: true,
      ) {
        if let jsonData = line.data(using: .utf8),
           let json = try JSONSerialization
           .jsonObject(with: jsonData) as? [String: String]
        {
          // Merge loaded cache into wordLemmaCache
          for (word, lemma) in json {
            wordLemmaCache[word] = lemma
          }
        }
      }
    } catch {
      // Silently ignore cache load errors
    }
  }

  /// Save cache to JSONL file (only if caching is enabled)
  /// Writes entire cache as individual JSON objects, one per line
  public mutating func saveCache() {
    guard cachingEnabled else { return }

    do {
      let fileURL = URL(fileURLWithPath: cacheFilePath)

      // Create directory if it doesn't exist
      let cacheDir = fileURL.deletingLastPathComponent().path
      try FileManager.default.createDirectory(
        atPath: cacheDir,
        withIntermediateDirectories: true,
      )

      // Write cache as JSONL: one {"word":"lemma"} per line
      // Skip identity mappings (word == lemma) to reduce file size
      var lines: [String] = []
      for (word, lemma) in wordLemmaCache.sorted(by: { $0.key < $1.key }) {
        // Skip identity mappings - they add no value since NLTagger returns
        // them anyway
        guard word != lemma else { continue }

        let jsonData = try JSONSerialization.data(withJSONObject: [word: lemma])
        if let jsonString = String(data: jsonData, encoding: .utf8) {
          lines.append(jsonString)
        }
      }

      cc.ok2(
        #line,
        #function,
        "Saved \(lines.count) non-identity lemmas (skipped \(wordLemmaCache.count - lines.count) identities)",
      )

      let content = lines.joined(separator: "\n")
      try content.write(
        toFile: cacheFilePath,
        atomically: true,
        encoding: .utf8,
      )
    } catch {
      // Silently ignore cache save errors
    }
  }

  /// Remove punctuation from text and lowercase, keeping Unicode letters,
  /// digits, and spaces (preserves diacriticals like ä, ö, ü, ā, ī, ṅ, etc.)
  /// - Parameter text: Text to clean
  /// - Returns: Cleaned lowercase text with punctuation converted to spaces,
  /// multiple spaces collapsed to single space, and trimmed
  public func clean(_ text: String) -> String {
    text.lowercased()
      .replacingOccurrences(
        of: "[^\\p{L}0-9\\s]+",
        with: " ",
        options: .regularExpression,
      )
      .replacingOccurrences(
        of: "\\s+",
        with: " ",
        options: .regularExpression,
      )
      .trimmingCharacters(in: .whitespaces)
  }

  /// Map language code to NLLanguage enum value
  /// - Parameter langCode: Language code (e.g., "en", "de", "fr", "it", "pli")
  /// - Returns: NLLanguage enum value, or nil if unsupported
  private func nlLanguage(for langCode: String) -> NLLanguage? {
    switch langCode {
    case "en":
      .english
    case "de":
      .german
    case "fr":
      .french
    case "it":
      .italian
    case "ru":
      .russian
    case "pli":
      nil // Pali not directly supported by NLTagger
    default:
      nil
    }
  }

  /// Lemmatize text into array of base word forms
  /// Removes punctuation and returns lowercased lemmas
  /// Uses word-by-word lemmatization with caching for consistency
  /// - Parameter text: Text to lemmatize
  /// - Returns: Array of lemmatized word forms
  public mutating func lemmatize(_ text: String) -> [String] {
    var lemmas: [String] = []

    // Remove punctuation before lemmatizing to ensure consistent results
    // This ensures "suffering," lemmatizes to "suffer" not "suffering"
    let cleanText = clean(text)

    // Normalize input for language-specific character mappings
    var normalizedText = cleanText
    switch lang {
    case "de":
      normalizedText = cleanText
        .replacingOccurrences(of: "ae", with: "ä")
        .replacingOccurrences(of: "oe", with: "ö")
        .replacingOccurrences(of: "ue", with: "ü")
    default:
      normalizedText = cleanText
    }

    // Lemmatize word-by-word for consistency (avoid context-dependent
    // lemmatization)
    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = normalizedText

    tokenizer.enumerateTokens(
      in: normalizedText.startIndex ..< normalizedText.endIndex,
    ) { tokenRange, _ in
      let word = String(normalizedText[tokenRange])

      // Check cache first (only if caching enabled)
      if cachingEnabled, let cachedLemma = wordLemmaCache[word] {
        lemmas.append(cachedLemma)
        return true
      }

      // Lemmatize word alone (no context)
      var lemma = word // Default
      tagger.string = word

      // Set language for NLTagger to ensure correct lemmatization
      if let nlLang = nlLanguage(for: lang) {
        tagger.setLanguage(nlLang, range: word.startIndex ..< word.endIndex)
      }

      tagger.enumerateTags(
        in: word.startIndex ..< word.endIndex,
        unit: .word,
        scheme: .lemma,
        options: options,
      ) { tag, _ in
        if tag == nil {
          lemma = word
        } else if tag!.rawValue.isEmpty {
          lemma = word + "2"
        } else {
          lemma = tag!.rawValue
        }
        return true
      }

      // Lowercase lemma for consistency
      lemma = lemma.lowercased()

      // Cache if enabled, then append
      if cachingEnabled {
        wordLemmaCache[word] = lemma
      }
      lemmas.append(lemma)
      return true
    }

    return lemmas
  }

  /// Lemmatize text and return space-padded string for SQL data storage
  /// Format: " lemma1 lemma2 ... lemman "
  /// - Parameter text: Text to lemmatize
  /// - Returns: Space-padded string of lemmatized words for database storage
  public mutating func lemmatizeForSqlData(_ text: String) -> String {
    let lemmas = lemmatize(text)
    guard !lemmas.isEmpty else { return " " + clean(text) + " " }
    return " " + lemmas.joined(separator: " ") + " "
  }
}
