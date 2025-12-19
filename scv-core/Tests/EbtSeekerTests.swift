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

  @Test("EbtSeeker.search() returns result for thig1.1")
  func seekerSearchThig11() async throws {
    // Get seeker for en/soma
    let seeker = try await EbtData.shared.getSeeker(lang: "en", author: "soma")

    // Call search on seeker with suttaref query
    let result = await seeker.search(query: "thig1.1/en/soma")

    // Verify search returned the expected result
    #expect(result.items.count == 1, "Expected 1 result for thig1.1")
    #expect(result.items[0].suttaRef.suttaUid == "thig1.1")
    #expect(result.items[0].suttaRef.lang == "en")
    #expect(result.items[0].suttaRef.author == "soma")

    // Verify metadata
    #expect(result.metadata.docLang == "en", "docLang should be en")
    #expect(result.metadata.docAuthor == "soma", "docAuthor should be soma")
  }

  @Test("getSeeker with invalid author throws error")
  func getSeekerInvalidAuthor() async throws {
    do {
      _ = try await EbtData.shared.getSeeker(lang: "en", author: "nonexistent")
      #expect(Bool(false), "Should have thrown error for invalid author")
    } catch EbtDataError.databaseNotFound {
      // Expected error
    }
  }

  @Test("getSeeker with invalid lang throws error")
  func getSeekerInvalidLang() async throws {
    do {
      _ = try await EbtData.shared.getSeeker(lang: "xx", author: "sujato")
      #expect(Bool(false), "Should have thrown error for invalid lang")
    } catch EbtDataError.databaseNotFound {
      // Expected error
    }
  }

  @Test("getSeeker with defaults uses pli and default author")
  func getSeekerDefaults() async throws {
    let seeker = try await EbtData.shared.getSeeker()

    // Verify metadata shows pli and default author
    let result = await seeker.search(query: "mn1/pli/ms")
    #expect(result.metadata.docLang == "pli", "docLang should be pli")
    #expect(!result.metadata.docAuthor.isEmpty, "docAuthor should not be empty")
  }

  @Test("EbtSeeker.search() with wrong lang/author returns error")
  func seekerSearchWrongLangAuthor() async throws {
    // Create seeker for en/soma
    let seeker = try await EbtData.shared.getSeeker(lang: "en", author: "soma")

    // Try to search for a sutta with wrong lang/author combination
    let wrongLangResult = await seeker.search(query: "mn1/de/sabbamitta")
    #expect(
      wrongLangResult.error != nil,
      "Search with wrong lang should return error",
    )

    // Try to search for a sutta with valid author (kelly) but not in en/soma
    // database
    let wrongAuthorResult = await seeker.search(query: "mn1/en/kelly")
    #expect(
      wrongAuthorResult.error != nil,
      "Search with valid author not in database should return error",
    )

    // Try to search for a sutta with wrong lang code
    let wrongLangCodeResult = await seeker.search(query: "mn1/xx/soma")
    #expect(
      wrongLangCodeResult.error != nil,
      "Search with invalid lang code should return or error",
    )
  }

  @Test("EbtSeeker.search() with correct lang/author returns results")
  func seekerSearchCorrectLangAuthor() async throws {
    // Create seeker for en/soma
    let seeker = try await EbtData.shared.getSeeker(lang: "en", author: "soma")

    // Search for mn1/en/soma which should match seeker's database
    let result = await seeker.search(query: "mn1/en/soma")
    #expect(!result.items.isEmpty, "Search for mn1/en/soma should find results")
    #expect(result.items[0].suttaRef.lang == "en", "Result should have lang en")
    #expect(
      result.items[0].suttaRef.author == "soma",
      "Result should have author soma",
    )
  }

  // DEPRECATED: Tests phrase/keyword search which is being phased out.
  // Use lemma search (searchLemma) instead through EbtQuery or
  // EbtSeeker.searchLemma()
  /*
   @Test("Unified search endpoint returns SeekerResult with metadata")
   func searchRootOfSuffering() async throws {
     let seeker = try await EbtData.shared.getSeeker(
       lang: "en",
       author: "sujato",
     )
     let result = await seeker.search(query: "root of suffering")

     // Verify SeekerResult structure
     #expect(result.items.count == 7)
     #expect(result.metadata.query == "root of suffering")
     #expect(result.metadata.method == .phrase)
     #expect(result.metadata.docLang == "en")
     #expect(result.metadata.docAuthor == "sujato")

     // Verify all expected suttas are present
     let resultSuttas = result.items.map(\.suttaRef.suttaUid)
     for expectedSutta in [
       "sn42.11",
       "mn105",
       "mn1",
       "sn56.21",
       "mn116",
       "mn66",
       "dn16",
     ] {
       #expect(resultSuttas.contains(expectedSutta))
     }
   }
   */

  @Test("DE lemma search: abhängige entstehen performance")
  func deLemmaSearchPerformance() async throws {
    // Preload database before timing
    let seeker = try await EbtData.shared.getSeeker(
      lang: "de",
      author: "sabbamitta",
    )

    // Start timing for search only
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()
    let result = await seeker.searchLemma("abhängige entstehen")

    let msElapsed = (CFAbsoluteTimeGetCurrent() - elapsedAtStart) * 1000
    print(
      "\n[PERF] DE lemma 'abhängige entstehen': \(result.items.count) results in \(String(format: "%.1f", msElapsed))ms",
    )

    for (i, item) in result.items.enumerated() {
      print(
        "[RESULT \(i + 1)] \(item.suttaRef.description) score:\(String(format: "%.3f", item.score))",
      )
    }

    #expect(result.error == nil)
    #expect(result.items.count == 38)
    #expect(
      msElapsed < 100.0,
      "Lemma search should complete in under 100ms, took \(String(format: "%.1f", msElapsed))ms",
    )
  }

  @Test("DE lemma search benchmark: all 38 results with exact scores")
  func deLemmaSearchBenchmark() async throws {
    let seeker = try await EbtData.shared.getSeeker(
      lang: "de",
      author: "sabbamitta",
    )
    let result = await seeker.searchLemma("abhängige entstehen")

    // All 38 results after fixing Lemmatizer diacritical preservation
    // Scores rounded to 3 decimal places
    let expected: [(sutta: String, score: Double)] = [
      ("an10.93/de/sabbamitta", 9.088),
      ("sn12.20/de/sabbamitta", 7.113),
      ("sn36.7/de/sabbamitta", 6.103),
      ("sn22.81/de/sabbamitta", 6.056),
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

    #expect(result.items.count == 38)

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
  }

  @Test("EbtSeeker.lemmatize() DE phrases")
  func lemmatizeDEPhrases() async throws {
    let seeker = try await EbtData.shared.getSeeker(
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
}
