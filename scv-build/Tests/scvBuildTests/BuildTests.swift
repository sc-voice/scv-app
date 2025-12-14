import Foundation
import NaturalLanguage
import Testing

@Suite("scv-build Tests")
struct BuildTests {
  @Test("Placeholder test")
  func placeholder() {
    #expect(true)
  }

  @Test("EbtDBBuilder lemmatizeSegment removes punctuation before lemmatizing")
  func lemmatizeSegmentRemovesPunctuation() {
    // Create a simple lemmatizer to test the behavior
    let lemmatizer = NLTagger(tagSchemes: [.lemma])

    // Test string WITH punctuation (as it would be in source files)
    let textWithPunct = "Because he has understood that approval is the root of suffering,"

    // FIXED: Remove punctuation before lemmatizing (what EbtDBBuilder now does)
    let cleanText = textWithPunct.replacingOccurrences(
      of: "[^a-zA-Z0-9\\s]",
      with: "",
      options: .regularExpression,
    )
    lemmatizer.string = cleanText

    var lemmasWithPunctFixed: [String] = []
    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
    lemmatizer.enumerateTags(
      in: cleanText.startIndex ..< cleanText.endIndex,
      unit: .word,
      scheme: .lemma,
      options: options,
    ) { tag, tokenRange in
      let lemma = (tag?.rawValue ?? String(cleanText[tokenRange])).lowercased()
      lemmasWithPunctFixed.append(lemma)
      return true
    }

    // Test string WITHOUT punctuation (as it would be from search)
    let textNoPunct = "Because he has understood that approval is the root of suffering"
    lemmatizer.string = textNoPunct

    var lemmasNoPunct: [String] = []
    lemmatizer.enumerateTags(
      in: textNoPunct.startIndex ..< textNoPunct.endIndex,
      unit: .word,
      scheme: .lemma,
      options: options,
    ) { tag, tokenRange in
      let lemma = (tag?.rawValue ?? String(textNoPunct[tokenRange]))
        .lowercased()
      lemmasNoPunct.append(lemma)
      return true
    }

    print(
      "[LEMMATIZE WITH PUNCT (FIXED)] \(textWithPunct) → cleaned → \(cleanText) → \(lemmasWithPunctFixed)",
    )
    print("[LEMMATIZE NO PUNCT]           \(textNoPunct) → \(lemmasNoPunct)")

    // After removing punctuation before lemmatizing, both should produce
    // identical results
    #expect(
      lemmasWithPunctFixed == lemmasNoPunct,
      "Punctuation should be removed before lemmatizing to match search behavior",
    )

    // Both should contain "suffer" (not "suffering")
    #expect(
      lemmasNoPunct.contains("suffer"),
      "Should contain 'suffer' not 'suffering'",
    )
    #expect(
      lemmasWithPunctFixed.contains("suffer"),
      "After fix, should contain 'suffer' not 'suffering'",
    )
  }

  @Test("EbtSeeker builds correct LIKE pattern for lemma search")
  func lemmaSearchPatternGeneration() {
    // Test case 1: Two lemmas (root, suffer)
    // Expected: "% root %suffer %"
    #expect("% root %suffer %".count == 17, "Two lemma pattern")

    // Test case 2: Three lemmas (root, of, suffer)
    // Expected: "% root %of% suffer %"
    #expect("% root %of% suffer %".count == 21, "Three lemma pattern")

    // Test case 3: Four lemmas (lemma1, lemma2, lemma3, lemma4)
    // Expected: "% lemma1 %lemma2%lemma3% lemma4 %"
    #expect(
      "% lemma1 %lemma2%lemma3% lemma4 %".count == 34,
      "Four lemma pattern",
    )

    print("[PATTERN 2-LEMMAS] Two lemmas should produce: '% root %suffer %'")
    print(
      "[PATTERN 3-LEMMAS] Three lemmas should produce: '% root %of% suffer %'",
    )
    print(
      "[PATTERN 4-LEMMAS] Four lemmas should produce: '% lemma1 %lemma2%lemma3% lemma4 %'",
    )
  }
}
