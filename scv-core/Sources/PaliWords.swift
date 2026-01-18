//
//  PaliWords.swift
//  scv-core
//
//  Created by Claude on 2025-01-16.
//

import Foundation

public final class Pali: Sendable {
  static let nonDiacriticalDict: Set<String> = [
    "arahant",
    "bhikkhu",
    "dhamma",
    "nirvana",
  ]

  private static let paliDiacritics =
    CharacterSet(charactersIn: "āīūḍḷṁṅṇṭñĀĪŪḌḶṀṄṆṬÑ")

  /// Check if a word contains Pali-specific diacritics
  /// - Parameter word: Word to check
  /// - Returns: True if word contains at least one Pali diacritic
  private func containsPaliDiacritics(_ word: String) -> Bool {
    word.unicodeScalars.contains { Self.paliDiacritics.contains($0) }
  }

  /// Check if a word is likely Pali based on diacritics or nonDiacriticalDict
  /// - Parameters:
  ///   - word: Word to check
  ///   - minLength: Minimum length for undiacritical words to be considered
  /// Pali (default: 4)
  /// - Returns: True if word contains Pali diacritics OR is in nonDiacriticalDict and
  /// length >= minLength
  public func isPali(_ word: String, minLength: Int = 4) -> Bool {
    let trimmed = word.lowercased()
      .trimmingCharacters(in: .punctuationCharacters)

    // Words with Pali diacritics are definitely Pali
    if containsPaliDiacritics(trimmed) {
      return true
    }

    // Otherwise, must be in nonDiacriticalDict AND >= minLength
    return trimmed.count >= minLength && Self.nonDiacriticalDict.contains(trimmed)
  }

  static let shared = Pali()
}

/// Method for counting Pali words in translations
public enum CountMethod {
  /// Full matching: extract Pali words from source and match with regex word
  /// boundaries
  case exhaustive
  /// Fast path: only match words containing Pali-specific diacritics
  case diacritic
}

/// Counts Pali words from Buddhist scriptures
public class PaliCounter {
  /// Base language for translations (e.g., "en", "pt")
  private let baseLanguage: String

  /// Method for counting Pali words
  private let countMethod: CountMethod

  /// Running total of Pali words found in translated documents
  public private(set) var paliWords: Int = 0

  /// Dictionary of Pali words extracted from pli field, mapped to occurrence
  /// count
  /// Keys are lowercase Pali words, values are counts in the Pali source text
  public var paliDict: [String: Int] = [:]

  /// Dictionary of Pali words found in doc text with their occurrence counts
  /// Keys are lowercase Pali words, values are counts in the translated
  /// document
  public var docPaliDict: [String: Int] = [:]

  /// Per-language deny lists for words that appear in both Pali and the target
  /// language
  /// Maps language codes to sets of words to exclude from docPaliDict
  private let denyLists: [String: Set<String>] = [
    "en": ["me", "a", "i"],
    "de": ["de", "es"],
    "pt": ["de", "a"],
  ]

  /// Pali-specific diacritics not used in European languages (EN, DE, FR, ES,
  /// PT, RU)
  private let paliDiacritics =
    CharacterSet(charactersIn: "āīūḍḷṁṅṇṭñĀĪŪḌḶṀṄṆṬÑ")

  /// Initialize with base language and counting method
  /// - Parameters:
  ///   - lang: Language code (e.g., "en", "pt")
  ///   - method: Counting method (.exhaustive or .diacritic), defaults to
  /// .diacritic for speed
  public init(lang: String, method: CountMethod = .diacritic) {
    baseLanguage = lang
    countMethod = method
  }

  /// Check if a word contains Pali-specific diacritics
  /// - Parameter word: Word to check
  /// - Returns: True if word contains at least one Pali diacritic
  private func containsPaliDiacritics(_ word: String) -> Bool {
    word.unicodeScalars.contains { paliDiacritics.contains($0) }
  }

  /// Check if a word is likely Pali based on diacritics or paliDict membership
  /// - Parameters:
  ///   - word: Word to check
  ///   - minLength: Minimum length for undiacritical words to be considered
  /// Pali (default: 4)
  /// - Returns: True if word contains Pali diacritics OR is in paliDict and
  /// length >= minLength
  func isCountablePali(_ word: String, minLength: Int = 4) -> Bool {
    let trimmed = word.lowercased()
      .trimmingCharacters(in: .punctuationCharacters)

    // Words with Pali diacritics are definitely Pali
    if containsPaliDiacritics(trimmed) {
      return true
    }

    // Otherwise, must be in paliDict AND >= minLength
    return trimmed.count >= minLength && paliDict[trimmed] != nil
  }

  /// Count Pali words in a sutta document
  /// Accumulates counts across multiple suttaRef calls
  /// - Parameter suttaRef: Reference to sutta to analyze
  public func countPaliWords(suttaRef: SuttaRef) async {
    guard let mlDoc = await EbtData.getMLDocument(suttaRef: suttaRef) else {
      return
    }

    switch countMethod {
    case .exhaustive:
      await countPaliWordsExhaustive(mlDoc: mlDoc)
    case .diacritic:
      countPaliWordsDiacritic(mlDoc: mlDoc)
    }
  }

  /// Exhaustive method: Extract Pali words from source and match with regex
  private func countPaliWordsExhaustive(mlDoc: MLDocument) async {
    // Extract Pali words and accumulate in paliDict
    for segment in mlDoc.segments() {
      if let paliText = segment.pli {
        let words = paliText.split(separator: " ")
          .map { String($0).lowercased() }
        for word in words {
          paliDict[word, default: 0] += 1
        }
      }
    }

    // Count Pali words found in translated doc text
    let denyList = denyLists[baseLanguage] ?? Set<String>()

    for segment in mlDoc.segments() {
      if let docText = segment.doc {
        let docLower = docText.lowercased()

        // First pass: match exact Pali words from paliDict
        for paliWord in paliDict.keys {
          // Only count words that contain only letters
          guard paliWord.allSatisfy(\.isLetter) else { continue }

          // Skip words in the deny list for this language
          guard !denyList.contains(paliWord) else { continue }

          // Use regex word boundaries to match whole words only
          do {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: paliWord))\\b"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(docLower.startIndex..., in: docLower)
            let matches = regex.numberOfMatches(
              in: docLower,
              options: [],
              range: range,
            )
            if matches > 0 {
              paliWords += matches
              docPaliDict[paliWord, default: 0] += matches
            }
          } catch {
            // Skip if regex fails
            continue
          }
        }

        // Second pass: match words containing Pali diacritics not yet in
        // docPaliDict
        let words = docLower.split(separator: " ")
        for word in words {
          let wordStr = String(word)
            .trimmingCharacters(in: .punctuationCharacters)

          // Skip if already matched in first pass
          if docPaliDict[wordStr] != nil { continue }

          // Check if word contains Pali diacritics
          if containsPaliDiacritics(wordStr) {
            // Skip words in the deny list
            guard !denyList.contains(wordStr) else { continue }

            paliWords += 1
            // Add morphological variant to paliDict (reflects case/form
            // differences)
            paliDict[wordStr, default: 0] += 1
            docPaliDict[wordStr, default: 0] += 1
          }
        }
      }
    }
  }

  /// Fast diacritic method: only match words containing Pali diacritics
  private func countPaliWordsDiacritic(mlDoc: MLDocument) {
    let denyList = denyLists[baseLanguage] ?? Set<String>()

    for segment in mlDoc.segments() {
      if let docText = segment.doc {
        let docLower = docText.lowercased()
        let words = docLower.split(separator: " ")

        for word in words {
          let wordStr = String(word)
            .trimmingCharacters(in: .punctuationCharacters)

          // Only match letters
          guard wordStr.allSatisfy(\.isLetter) else { continue }

          // Skip words in the deny list
          guard !denyList.contains(wordStr) else { continue }

          // Check if word contains Pali diacritics
          if containsPaliDiacritics(wordStr) {
            paliWords += 1
            docPaliDict[wordStr, default: 0] += 1
          }
        }
      }
    }
  }
}
