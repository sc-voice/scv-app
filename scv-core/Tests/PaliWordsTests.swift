//
//  PaliWordsTests.swift
//  scv-core
//
//  Created by Claude on 2025-01-16.
//

@testable import scvCore
import Testing

struct PaliWordsTests {
  @Test
  func englishMn44() async {
    let method: CountMethod = .diacritic
    let counter = PaliCounter(lang: "en", method: method)
    guard let suttaRef = SuttaRef.create("mn44/en/sujato") else {
      #expect(Bool(false), "Invalid sutta reference")
      return
    }

    await counter.countPaliWords(suttaRef: suttaRef)

    #expect(counter.paliWords == 13) // Diacritics found in English translation
    #expect(counter.paliDict
      .count ==
      (method == .diacritic ? 0 : 466)) // 463 base + 3 morphological variants
  }

  @Test
  func germanMn44() async {
    let method: CountMethod = .diacritic
    let counter = PaliCounter(lang: "de", method: method)
    guard let suttaRef = SuttaRef.create("mn44/de/sabbamitta") else {
      #expect(Bool(false), "Invalid sutta reference")
      return
    }

    await counter.countPaliWords(suttaRef: suttaRef)

    #expect(counter.paliWords == 13) // Diacritics found in German translation
    #expect(counter.paliDict
      .count ==
      (method == .diacritic ? 0 : 466)) // 463 base + 3 morphological variants
    #expect(counter.docPaliDict.keys.contains("rājagaha"))
  }

  @Test
  func initialStateEmpty() {
    let counter = PaliCounter(lang: "en")
    #expect(counter.paliWords == 0)
    #expect(counter.paliDict.isEmpty)
  }

  @Test
  func docPaliDictKeysAreLettersOnly() async {
    let counter = PaliCounter(lang: "en")
    guard let suttaRef = SuttaRef.create("mn44/en/sujato") else {
      #expect(Bool(false), "Invalid sutta reference")
      return
    }

    await counter.countPaliWords(suttaRef: suttaRef)

    // All keys in docPaliDict should contain only letters
    for key in counter.docPaliDict.keys {
      let isLettersOnly = key.allSatisfy(\.isLetter)
      #expect(isLettersOnly, "Key '\(key)' contains non-letter characters")
    }
  }

  @Test
  func isPaliDetectsNonDiacriticalWords() {
    let p7s = PaliCounter(lang: "en")

    // Manually populate paliDict with test words
    p7s.paliDict = [
      "arahant": 1,
      "bhikkhu": 1,
      "dhamma": 1,
      "nirvana": 1,
      "me": 1,
    ]

    // Test words with diacritics (always Pali)
    #expect(
      p7s.isCountablePali("ṭhaddha") == true,
      "Diacritical word should be Pali",
    )
    #expect(p7s.isCountablePali("ī") == true, "Diacritical word should be Pali")

    // Test non-diacritical words from paliDict (>= default minLength 4)
    #expect(p7s.isCountablePali("arahant") == true,
            "Non-diacritical Pali word in dict should be Pali")
    #expect(p7s.isCountablePali("bhikkhu") == true,
            "Non-diacritical Pali word in dict should be Pali")
    #expect(p7s.isCountablePali("nirvana") == true,
            "Non-diacritical Pali word in dict should be Pali")

    // Test short words without diacritics (should be false even if in paliDict)
    #expect(p7s.isCountablePali("me") == false,
            "Short word without diacritics should not be Pali")

    // Test words not in paliDict
    #expect(p7s.isCountablePali("xyzabc") == false,
            "Non-Pali word not in paliDict should be false")

    // Test punctuation trimming
    #expect(p7s.isCountablePali("arahant.") == true,
            "Word with trailing punctuation should be trimmed")
    #expect(p7s.isCountablePali("\"bhikkhu\"") == true,
            "Word with surrounding quotes should be trimmed")
  }
}
