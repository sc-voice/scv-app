//
//  EbtSeekerTests.swift
//  scv-core
//
//  Created by Claude on 2025-12-03.
//

import CoreFoundation
@testable import scvCore
import Testing

@Suite("EbtSeeker Tests")
struct EbtSeekerTests {
  let cc = ColorConsole(#file, #function, dbg.EbtSeeker.other)

  @Test("getSeeker with invalid author throws error")
  func getSeekerInvalidAuthor() async throws {
    do {
      _ = try await EbtData.getSeeker(lang: "en", author: "nonexistent")
      #expect(Bool(false), "Should have thrown error for invalid author")
    } catch EbtDataError.cannotOpenDatabase {
      // Expected error
    }
  }

  @Test("getSeeker with invalid lang throws error")
  func getSeekerInvalidLang() async throws {
    do {
      _ = try await EbtData.getSeeker(lang: "xx", author: "sujato")
      #expect(Bool(false), "Should have thrown error for invalid lang")
    } catch EbtDataError.cannotOpenDatabase {
      // Expected error
    }
  }

  @Test("DE lemma search benchmark: all 38 results with exact scores")
  func deLemmaSearchBenchmark() async throws {
    // WARNING: THIS IS A BRITTLE TEST THAT DETECTS RELEVANCE SCORE CHANGES
    // IF TEST FAILS, ANALYZE DIFFERENCES FOUND (POSSIBLY TRANSLATOR CHANGE)
    // IF TRANSLATOR CHANGE, ASK CLAUDE TO UPDATE TEST WITH ACTUAL DATA
    let seeker = try await EbtData.getSeeker(
      lang: "de",
      author: "sabbamitta",
    )
    let timeStart = CFAbsoluteTimeGetCurrent()
    let result = await seeker.searchLemma("abhängige entstehen")
    let msElapsed = (CFAbsoluteTimeGetCurrent() - timeStart) * 1000

    // All 39 results after fixing Lemmatizer diacritical preservation
    // Scores rounded to 3 decimal places
    let expected: [(sutta: String, score: Double)] = [
      ("an10.93/de/sabbamitta", 9.088),
      ("sn12.20/de/sabbamitta", 7.113),
      ("sn36.7/de/sabbamitta", 6.103),
      ("sn22.81/de/sabbamitta", 6.056),
      ("mn152/de/sabbamitta", 6.048),
      ("mn28/de/sabbamitta", 6.038),
      ("sn12.1/de/sabbamitta", 4.098),
      ("dn15/de/sabbamitta", 4.016),
      ("mn38/de/sabbamitta", 4.012),
      ("mn115/de/sabbamitta", 3.019),
      ("sn36.9/de/sabbamitta", 2.286),
      ("sn22.21/de/sabbamitta", 2.133),
      ("sn12.60/de/sabbamitta", 2.053),
      ("sn36.8/de/sabbamitta", 2.050),
      ("sn12.25/de/sabbamitta", 2.034),
      ("sn12.2/de/sabbamitta", 2.026),
      ("sn12.24/de/sabbamitta", 2.019),
      ("sn12.37/de/sabbamitta", 1.067),
      ("iti72/de/sabbamitta", 1.050),
      ("sn12.26/de/sabbamitta", 1.045),
      ("sn12.42/de/sabbamitta", 1.042),
      ("ud1.1/de/sabbamitta", 1.042),
      ("ud1.2/de/sabbamitta", 1.042),
      ("sn12.61/de/sabbamitta", 1.031),
      ("sn55.28/de/sabbamitta", 1.030),
      ("sn12.62/de/sabbamitta", 1.029),
      ("sn12.41/de/sabbamitta", 1.028),
      ("ud1.3/de/sabbamitta", 1.027),
      ("sn6.1/de/sabbamitta", 1.019),
      ("sn22.57/de/sabbamitta", 1.013),
      ("mn74/de/sabbamitta", 1.010),
      ("snp3.9/de/sabbamitta", 1.003),
      ("mn98/de/sabbamitta", 1.003),
      ("mn26/de/sabbamitta", 1.003),
      ("mn85/de/sabbamitta", 1.002),
      ("dn1/de/sabbamitta", 1.002),
      ("dn14/de/sabbamitta", 1.001),
      ("dn34/de/sabbamitta", 1.001),
      ("dn33/de/sabbamitta", 1.001),
    ]

    #expect(result.items.count == 39)

    for (i, (expectedSutta, expectedScore)) in expected.enumerated() {
      let actual = result.items[i]
      #expect(
        actual.suttaRef.description == expectedSutta,
        "Result \(i + 1) sutta mismatch: expected \(expectedSutta), got \(actual.suttaRef.description)",
      )
      #expect(
        abs(actual.score - expectedScore) < 0.0005,
        "Result \(i + 1) \(expectedSutta) score mismatch: expected \(expectedScore), got \(actual.score)",
      )
    }
    cc.ok1(#line, #function, "msElapsed:", msElapsed)
  }

  @Test("EbtSeeker.lemmatize() DE phrases")
  func lemmatizeDEPhrases() async throws {
    let seeker = try await EbtData.getSeeker(
      lang: "de",
      author: "sabbamitta",
    )

    // Test "abhängige entstehen"
    let lemmas1 = await seeker.lemmatize("abhängige entstehen")
    print("\n[LEMMATIZE] 'abhängige entstehen' → \(lemmas1)")
    #expect(lemmas1 == ["abhängig", "entstehen"])

    // Test "abhängigen entstanden" (different inflections)
    let lemmas2 = await seeker.lemmatize("abhängigen entstanden")
    print("[LEMMATIZE] 'abhängigen entstanden' → \(lemmas2)")
    #expect(lemmas2 == ["abhängig", "entstehen"])

    // Test "abhangig" (without umlaut - returns as-is when not recognized)
    let lemmas3 = await seeker.lemmatize("abhangig")
    print("[LEMMATIZE] 'abhangig' → \(lemmas3)")
    #expect(lemmas3 == ["abhangig"])

    // Test "entsehen" with typo - returns as-is since not recognized
    let lemmas4 = await seeker.lemmatize("entsehen")
    print("[LEMMATIZE] 'entsehen' → \(lemmas4)")
    #expect(lemmas4 == ["entsehen"])

    // Test multiple word phrase
    let lemmas5 = await seeker.lemmatize("abhängige entstehen Leiden")
    print("[LEMMATIZE] 'abhängige entstehen Leiden' → \(lemmas5)")
    #expect(lemmas5 == ["abhängig", "entstehen", "leiden"])

    // Test ASCII version without umlaut (abhaengig) - should normalize to ä
    let lemmas6 = await seeker.lemmatize("abhaengig entstehen")
    print("[LEMMATIZE] 'abhaengig entstehen' → \(lemmas6)")
    #expect(
      lemmas6 == ["abhängig", "entstehen"],
      "ASCII umlaut should normalize to ä",
    )
  }

  @Test("searchLemma with LIKE special characters (SQL injection protection)")
  func lemmaSearchSQLInjectionProtection() async throws {
    let seeker = try await EbtData.getSeeker(
      lang: "de",
      author: "sabbamitta",
    )

    // Test that LIKE wildcards and special chars in LIKE pattern don't cause
    // SQL errors
    // Parameterized binding should safely escape these as literals, not SQL
    // operators
    let result1 = await seeker.searchLemma("abhängig%")
    #expect(
      result1.error == nil,
      "Search with % should not error: \(result1.error?.message ?? "")",
    )

    let result2 = await seeker.searchLemma("abhängig_")
    #expect(
      result2.error == nil,
      "Search with _ should not error: \(result2.error?.message ?? "")",
    )

    let result3 = await seeker.searchLemma("abhängig'")
    #expect(
      result3.error == nil,
      "Search with single quote should not error: \(result3.error?.message ?? "")",
    )

    let result4 = await seeker.searchLemma("abhängig\\")
    #expect(
      result4.error == nil,
      "Search with backslash should not error: \(result4.error?.message ?? "")",
    )

    // Combined special characters
    let result5 = await seeker.searchLemma("%_'\\")
    #expect(
      result5.error == nil,
      "Search with multiple special chars should not error",
    )

    // Normal known search should still work and return results
    let result6 = await seeker.searchLemma("abhängig entstehen")
    #expect(result6.error == nil, "Normal search should work")
    #expect(
      result6.items.count > 0,
      "Normal search 'abhängig entstehen' should return results",
    )
  }

  @Test("EN lemma search: root of suffering performance")
  func enLemmaSearchPerformance() async throws {
    // Preload database before timing
    let seeker = try await EbtData.getSeeker(
      lang: "en",
      author: "sujato",
    )

    // Start timing for search only
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()
    let result = await seeker.searchLemma("root of suffering")
    let msElapsed = (CFAbsoluteTimeGetCurrent() - elapsedAtStart) * 1000

    #expect(result.error == nil)
    #expect(result.items.count > 0)
    cc.ok1(#line, #function, "msElapsed:", msElapsed)
  }

  // TODO: Fix string length assertions - all counts are off by 1
  // See backlog: Fix EbtSeeker LIKE pattern string length assertions
  /*
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
   */
}
