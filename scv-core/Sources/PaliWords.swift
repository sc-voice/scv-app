//
//  PaliWords.swift
//  scv-core
//
//  Created by Claude on 2025-01-16.
//

import Foundation

/// Counts Pali words from Buddhist scriptures
public class PaliWords {
  /// Base language for translations (e.g., "en", "pt")
  private let baseLanguage: String

  /// Running total of Pali words found in translated documents
  public private(set) var paliWords: Int = 0

  /// Dictionary of Pali words extracted from pli field, mapped to occurrence count
  /// Keys are lowercase Pali words, values are counts in the Pali source text
  public var paliDict: [String: Int] = [:]

  /// Dictionary of Pali words found in doc text with their occurrence counts
  /// Keys are lowercase Pali words, values are counts in the translated document
  public var docPaliDict: [String: Int] = [:]

  /// Per-language deny lists for words that appear in both Pali and the target language
  /// Maps language codes to sets of words to exclude from docPaliDict
  private let denyLists: [String: Set<String>] = [
    "en": ["me", "a", "i"],
    "de": ["de", "es"],
    "pt": ["de", "a"],
  ]

  /// Pali-specific diacritics not used in European languages (EN, DE, FR, ES, PT, RU)
  private let paliDiacritics = CharacterSet(charactersIn: "āīūḍḷṁṅṇṭñĀĪŪḌḶṀṄṆṬÑ")

  /// Initialize with base language
  /// - Parameter lang: Language code (e.g., "en", "pt")
  public init(lang: String) {
    self.baseLanguage = lang
  }

  /// Check if a word contains Pali-specific diacritics
  /// - Parameter word: Word to check
  /// - Returns: True if word contains at least one Pali diacritic
  private func containsPaliDiacritics(_ word: String) -> Bool {
    return word.unicodeScalars.contains { paliDiacritics.contains($0) }
  }

  /// Count Pali words in a sutta document
  /// Extracts Pali words from pli field and counts occurrences in doc field
  /// Accumulates counts across multiple suttaRef calls
  /// - Parameter suttaRef: Reference to sutta to analyze
  public func countPaliWords(suttaRef: SuttaRef) async {
    guard let mlDoc = await EbtData.getMLDocument(suttaRef: suttaRef) else {
      return
    }

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
          guard paliWord.allSatisfy({ $0.isLetter }) else { continue }

          // Skip words in the deny list for this language
          guard !denyList.contains(paliWord) else { continue }

          // Use regex word boundaries to match whole words only
          do {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: paliWord))\\b"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(docLower.startIndex..., in: docLower)
            let matches = regex.numberOfMatches(in: docLower, options: [], range: range)
            if matches > 0 {
              paliWords += matches
              docPaliDict[paliWord, default: 0] += matches
            }
          } catch {
            // Skip if regex fails
            continue
          }
        }

        // Second pass: match words containing Pali diacritics not yet in docPaliDict
        let words = docLower.split(separator: " ")
        for word in words {
          let wordStr = String(word).trimmingCharacters(in: .punctuationCharacters)

          // Skip if already matched in first pass
          if docPaliDict[wordStr] != nil { continue }

          // Check if word contains Pali diacritics
          if containsPaliDiacritics(wordStr) {
            // Skip words in the deny list
            guard !denyList.contains(wordStr) else { continue }

            paliWords += 1
            docPaliDict[wordStr, default: 0] += 1
          }
        }
      }
    }
  }
}
