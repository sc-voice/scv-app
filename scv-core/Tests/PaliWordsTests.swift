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
  func testEnglishMn44() async {
    let method:CountMethod = .diacritic
    let counter = PaliWords(lang: "en", method: method)
    guard let suttaRef = SuttaRef.create("mn44/en/sujato") else {
      #expect(Bool(false), "Invalid sutta reference")
      return
    }

    await counter.countPaliWords(suttaRef: suttaRef)

    #expect(counter.paliWords == 13)  // Diacritics found in English translation
    #expect(counter.paliDict.count == (method == .diacritic ? 0 : 466))  // 463 base + 3 morphological variants
  }

  @Test
  func testGermanMn44() async {
    let method:CountMethod = .diacritic
    let counter = PaliWords(lang: "de", method: method)
    guard let suttaRef = SuttaRef.create("mn44/de/sabbamitta") else {
      #expect(Bool(false), "Invalid sutta reference")
      return
    }

    await counter.countPaliWords(suttaRef: suttaRef)

    #expect(counter.paliWords == 13)  // Diacritics found in German translation
    #expect(counter.paliDict.count == (method == .diacritic ? 0 : 466))  // 463 base + 3 morphological variants
    #expect(counter.docPaliDict.keys.contains("rājagaha"))
  }

  @Test
  func testInitialStateEmpty() {
    let counter = PaliWords(lang: "en")
    #expect(counter.paliWords == 0)
    #expect(counter.paliDict.isEmpty)
  }

  @Test
  func testDocPaliDictKeysAreLettersOnly() async {
    let counter = PaliWords(lang: "en")
    guard let suttaRef = SuttaRef.create("mn44/en/sujato") else {
      #expect(Bool(false), "Invalid sutta reference")
      return
    }

    await counter.countPaliWords(suttaRef: suttaRef)

    // All keys in docPaliDict should contain only letters
    for key in counter.docPaliDict.keys {
      let isLettersOnly = key.allSatisfy { $0.isLetter }
      #expect(isLettersOnly, "Key '\(key)' contains non-letter characters")
    }
  }
}
