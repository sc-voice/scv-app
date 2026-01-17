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
    let counter = PaliWords(lang: "en")
    guard let suttaRef = SuttaRef.create("mn44/en/sujato") else {
      #expect(Bool(false), "Invalid sutta reference")
      return
    }

    await counter.countPaliWords(suttaRef: suttaRef)

    #expect(counter.paliDict.count == 463)
    #expect(counter.paliWords == 7)  // Exact matches + diacritic-matched words
  }

  @Test
  func testGermanMn44() async {
    let counter = PaliWords(lang: "de")
    guard let suttaRef = SuttaRef.create("mn44/de/sabbamitta") else {
      #expect(Bool(false), "Invalid sutta reference")
      return
    }

    await counter.countPaliWords(suttaRef: suttaRef)

    #expect(counter.paliDict.count == 463)
    #expect(counter.paliWords == 7)  // Exact matches + diacritic-matched words
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
