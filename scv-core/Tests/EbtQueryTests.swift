//
//  EbtQueryTests.swift
//  scv-core
//
//  Created by Claude on 2025-12-12.
//

@testable import scvCore
import Testing

@Suite("EbtQuery Tests")
struct EbtQueryTests {
  @Test("EbtQuery with single full scid")
  func querySingleFullScid() {
    let query = EbtQuery(query: "thig1.1/en/soma")

    #expect(query.method == .suttaref, "Should detect suttaref method")
    #expect(query.suttaRefs.count == 1, "Should parse 1 sutta ref")
    #expect(query.suttaRefs[0].suttaUid == "thig1.1")
    #expect(query.suttaRefs[0].lang == "en")
    #expect(query.suttaRefs[0].author == "soma")
  }

  @Test("EbtQuery with mixed format scids and defaults")
  func queryMixedFormatsWithDefaults() {
    let query = EbtQuery(query: "thig1.1/en/soma, thig1.1/de, thig1.1")

    #expect(query.method == .suttaref, "Should detect suttaref method")
    #expect(
      query.suttaRefs.count == 3,
      "Should parse 3 sutta refs, got \(query.suttaRefs.count)",
    )

    // First: full scid
    #expect(query.suttaRefs[0].suttaUid == "thig1.1")
    #expect(query.suttaRefs[0].lang == "en")
    #expect(query.suttaRefs[0].author == "soma")

    // Second: partial scid with lang, should fill in default author for German
    #expect(query.suttaRefs[1].suttaUid == "thig1.1")
    #expect(query.suttaRefs[1].lang == "de")
    #expect(
      query.suttaRefs[1].author == "sabbamitta",
      "German should default to sabbamitta, got \(query.suttaRefs[1].author ?? "nil")",
    )

    // Third: just sutta uid, should fill in defaults
    #expect(query.suttaRefs[2].suttaUid == "thig1.1")
    #expect(query.suttaRefs[2].lang == "en")
    #expect(
      query.suttaRefs[2].author == "sujato",
      "Should default to sujato, got \(query.suttaRefs[2].author ?? "nil")",
    )
  }

  @Test("EbtQuery with non-scid query")
  func queryNonScid() {
    let query = EbtQuery(query: "root of suffering")

    #expect(
      query.method == .lemma,
      "Should default to lemma method for text query",
    )
    #expect(
      query.suttaRefs.isEmpty,
      "Should have empty sutta refs for text query",
    )
  }

  @Test("EbtQuery with mixed valid and invalid entries")
  func queryMixedValidInvalid() {
    let query = EbtQuery(query: "mn1/en/sujato, not a sutta, sn42.11")

    #expect(
      query.method == .suttaref,
      "Should detect suttaref method when some entries are valid",
    )
    #expect(
      query.suttaRefs.count == 2,
      "Should parse 2 valid sutta refs (omitting invalid entries), got \(query.suttaRefs.count)",
    )

    #expect(query.suttaRefs[0].suttaUid == "mn1")
    #expect(query.suttaRefs[0].lang == "en")
    #expect(query.suttaRefs[0].author == "sujato")

    #expect(query.suttaRefs[1].suttaUid == "sn42.11")
  }

  @Test("EbtQuery stores original query string")
  func queryStoresOriginalQuery() {
    let originalQuery = "thig1.1/en/soma"
    let query = EbtQuery(query: originalQuery)

    #expect(query.query == originalQuery, "Should store original query string")
  }

  @Test("EbtQuery parseQuery detects 'men shaving heads' as lemma query")
  func parseQueryMenShavingHeads() {
    let (suttaRefs, method) = EbtQuery.parseQuery(query: "men shaving heads")

    #expect(suttaRefs.isEmpty, "Should not parse as suttarefs")
    #expect(method == .lemma, "Should detect as lemma method, got \(method)")
  }

  @Test("EbtSeeker lemmatize 'men shaving heads' in English")
  func seekerLemmatizeMenShavingHeads() async throws {
    let seeker = try await EbtData.shared.getSeeker(
      lang: "en",
      author: "brahmali",
    )
    let lemmas = await seeker.lemmatize("men shaving heads")
    print("[LEMMATIZE] 'men shaving heads' → \(lemmas)")

    // Should lemmatize to base forms
    #expect(!lemmas.isEmpty, "Should lemmatize to words")
    #expect(lemmas.count == 3, "Should have 3 lemmas for 3 words, got \(lemmas.count)")
  }

  @Test("EbtQuery.search() with custom Settings for EN/sujato")
  func searchWithCustomSettings() async {
    // Create test Settings with en/sujato
    let testSettings = Settings()
    testSettings.docLang = .english
    testSettings.docAuthor = "sujato"

    // Search using EbtQuery with custom settings
    let ebtQuery = EbtQuery(query: "root of suffering", settings: testSettings)
    let result = await ebtQuery.search()

    // Verify result structure
    #expect(result.error == nil)
    #expect(
      result.items.count == 11,
      "Lemma search finds all occurrences of lemmas, got \(result.items.count)",
    )
    #expect(result.metadata.query == "root of suffering")
    #expect(result.metadata.method == SearchMethod.lemma)
    #expect(result.metadata.docLang == "en")
    #expect(result.metadata.docAuthor == "sujato")

    // Verify phrase search subset is present (lemma finds more)
    let resultSuttas = Set(result.items.map(\.suttaRef.suttaUid))
    let phraseSearchSuttas = Set([
      "sn42.11",
      "mn105",
      "mn1",
      "sn56.21",
      "mn116",
      "mn66",
      "dn16",
    ])
    // Lemma search should include all phrase search results
    #expect(
      phraseSearchSuttas.isSubset(of: resultSuttas),
      "Lemma search should include phrase search results",
    )
  }

  @Test("EbtQuery.search() with comma-delimited suttarefs")
  func searchWithSuttarefs() async {
    let ebtQuery = EbtQuery(
      query: "thig1.1, thig1.1/en/soma, thig1.1/de",
      settings: Settings.shared,
    )
    let result = await ebtQuery.search()

    // Should detect suttaref method
    #expect(
      result.metadata.method == .suttaref,
      "Should use suttaref method for comma-delimited references",
    )

    // Should return results for both references
    #expect(
      result.items.count == 3,
      "Should find 3 results, got \(result.items.count)",
    )

    // First result: thig1.1 defaults to en/sujato
    #expect(result.items[0].suttaRef.suttaUid == "thig1.1")
    #expect(result.items[0].suttaRef.lang == "en")
    #expect(result.items[0].suttaRef.author == "sujato")

    // Second result: explicitly en/soma
    #expect(result.items[1].suttaRef.suttaUid == "thig1.1")
    #expect(result.items[1].suttaRef.lang == "en")
    #expect(result.items[1].suttaRef.author == "soma")

    // Third result: defaults to de/sabbamitta
    #expect(result.items[2].suttaRef.suttaUid == "thig1.1")
    #expect(result.items[2].suttaRef.lang == "de")
    #expect(result.items[2].suttaRef.author == "sabbamitta")
  }

  @Test("EbtQuery with pli/ms defaults applies to both items and metadata")
  func queryWithPliDefaults() async {
    // Create custom Settings with pli as default
    let testSettings = Settings()
    testSettings.docLang = .pli
    testSettings.docAuthor = "ms"

    // Search for suttaref without lang/author specified
    // Settings defaults should fill in pli/ms during parsing
    let ebtQuery = EbtQuery(query: "mn1", settings: testSettings)
    let result = await ebtQuery.search()

    // Verify metadata uses Settings defaults
    #expect(result.metadata.docLang == "pli", "metadata docLang should be pli")
    #expect(result.metadata.docAuthor == "ms", "metadata docAuthor should be ms")

    // Verify parsed suttaref was filled in with Settings defaults
    #expect(result.items.count == 1, "Should find 1 result")
    #expect(result.items[0].suttaRef.suttaUid == "mn1")
    #expect(
      result.items[0].suttaRef.lang == "pli",
      "Item lang should default to pli, got \(result.items[0].suttaRef.lang)"
    )
    #expect(
      result.items[0].suttaRef.author == "ms",
      "Item author should default to ms, got \(result.items[0].suttaRef.author ?? "nil")"
    )
  }

  @Test("EbtQuery with invalid lang/author returns zero items and error")
  func queryInvalidLangAuthorZeroItems() async {
    let ebtQuery = EbtQuery(query: "thig1.1/fr/sujato")
    let result = await ebtQuery.search()

    // Result should have zero items for invalid lang/author
    #expect(result.items.isEmpty, "Items should be empty for invalid fr/sujato")
    #expect(result.error != nil, "Error should be set for invalid lang/author")
    #expect(!result.error!.message.isEmpty, "Error message should not be empty")
  }

  @Test("EbtQuery with en/soma defaults finds correct suttaref")
  func queryWithEnSomaDefaults() async {
    let testSettings = Settings()
    testSettings.docLang = .english
    testSettings.docAuthor = "soma"

    let ebtQuery = EbtQuery(query: "thig1.1", settings: testSettings)
    let result = await ebtQuery.search()

    // Should find the suttaref with correct lang/author
    #expect(!result.items.isEmpty, "Should find results for thig1.1/en/soma")
    #expect(result.items[0].suttaRef.suttaUid == "thig1.1")
    #expect(result.items[0].suttaRef.lang == "en")
    #expect(result.items[0].suttaRef.author == "soma")

    // Verify metadata uses Settings defaults
    #expect(result.metadata.docLang == "en", "metadata docLang should be en")
    #expect(result.metadata.docAuthor == "soma", "metadata docAuthor should be soma")
  }

  @Test("EbtQuery with mn1/en/soma where sutta doesn't exist returns error")
  func queryMn1EnSomaNotFound() async {
    let ebtQuery = EbtQuery(query: "mn1/en/soma")
    let result = await ebtQuery.search()

    // Sutta doesn't exist in en/soma database, should return error and zero items
    #expect(result.items.isEmpty, "Items should be empty when sutta doesn't exist")
    #expect(result.error != nil, "Error should be set when sutta not found")
    #expect(!result.error!.message.isEmpty, "Error message should not be empty")
  }

  @Test("EbtQuery with 'men shaving heads' uses lemma search not keyword search")
  func queryMenShavingHeadsLemmaSearch() async {
    // Create custom Settings for en/brahmali
    let testSettings = Settings()
    testSettings.docLang = .english
    testSettings.docAuthor = "brahmali"

    let ebtQuery = EbtQuery(query: "men shaving heads", settings: testSettings)
    let result = await ebtQuery.search()

    // EbtQuery converts text queries to lemma method (not keyword)
    #expect(
      result.metadata.method == .lemma,
      "Non-suttaref queries should use lemma method, got \(result.metadata.method)"
    )
    // Should find results via lemma search
    #expect(!result.items.isEmpty, "Lemma search should find results")
    // Verify metadata uses custom settings
    #expect(result.metadata.docLang == "en")
    #expect(result.metadata.docAuthor == "brahmali")
  }

  @Test("EbtQuery.search() populates segment data for thig1.1")
  func populateInfoThig11() async throws {
    // Search for thig1.1/en/soma using suttaref method via EbtQuery
    let testSettings = Settings()
    testSettings.docLang = .german
    testSettings.docAuthor = "sabbamitta"

    let ebtQuery = EbtQuery(query: "thig1.1/en/soma", settings: testSettings)
    let result = await ebtQuery.search()

    // Verify search returned the expected result
    #expect(result.items.count == 1, "Expected 1 result for thig1.1/en/soma")

    var item0 = result.items[0]
    #expect(item0.suttaRef.suttaUid == "thig1.1")
    #expect(item0.suttaRef.lang == "en")
    #expect(item0.suttaRef.author == "soma")

    // Initially segmentCount and headerSegments should be empty/nil
    #expect(
      item0.segmentCount == nil,
      "segmentCount should be nil before populate()",
    )
    #expect(
      item0.headerSegments.isEmpty,
      "headerSegments should be empty before populate()",
    )

    // Populate segment data directly via populate()
    let seeker = try await EbtData.shared.getSeeker(suttaRef: item0.suttaRef)
    _ = try await item0.populate(
      seeker: seeker,
      query: result.metadata.query,
      method: result.metadata.method,
    )

    // Verify segmentCount was populated
    #expect(
      item0.segmentCount != nil,
      "segmentCount should be populated after populate()",
    )
    #expect(
      item0.segmentCount == 9,
      "thig1.1/en/soma should have 9 segments, got \(String(item0.segmentCount ?? -1))",
    )

    // Verify headerSegments was populated with header segments (segments with
    // :0 in segment_id)
    let headerSegments = item0.headerSegments
    #expect(!headerSegments.isEmpty, "thig1.1 should have header segments")

    // Verify header segment ids contain ":0"
    for segment in headerSegments {
      #expect(
        segment.scid.contains(":0"),
        "Header segment should contain ':0': \(segment.scid)",
      )
    }

    // Verify first three header segments based on actual data
    #expect(
      headerSegments.count >= 2,
      "thig1.1 should have at least 2 header segments, got \(String(headerSegments.count))",
    )

    // Verify first header segment (thig1.1:0.1)
    #expect(
      headerSegments[0].scid == "thig1.1:0.1",
      "First header segment should be thig1.1:0.1",
    )
    #expect(
      headerSegments[0].doc == "Verses of the Elder Bhikkhunīs ",
      "First header segment text mismatch",
    )

    // Verify second header segment (thig1.1:0.2)
    #expect(
      headerSegments[1].scid == "thig1.1:0.2",
      "Second header segment should be thig1.1:0.2",
    )
    #expect(
      headerSegments[1].doc == "Chapter of the Ones ",
      "Second header segment text mismatch",
    )

    // For suttaref searches, quote should be last header segment
    #expect(
      item0.quote != nil,
      "Quote should be populated from last header segment for suttaref search",
    )
    #expect(
      item0.quote == headerSegments.last?.doc,
      "Quote should match last header segment text",
    )
  }
}
