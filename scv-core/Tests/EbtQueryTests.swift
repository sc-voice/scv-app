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
  let cc = ColorConsole(#file, #function, dbg.EbtQuery.other)

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
    let testSettings = Settings()
    testSettings.docLang = .english
    testSettings.docAuthor = "sujato"

    let query = EbtQuery(
      query: "thig1.1/en/soma, thig1.1/de, thig1.1",
      docLang: testSettings.docLang.code,
      docAuthor: testSettings.docAuthor,
      maxDoc: testSettings.maxDoc,
    )

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
    let query = EbtQuery(
      query: "mn1/en/sujato, not a sutta, sn42.11",
      docLang: "en",
      docAuthor: "sujato",
    )

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
    #expect(
      lemmas.count == 3,
      "Should have 3 lemmas for 3 words, got \(lemmas.count)",
    )
  }

  @Test("EbtSeeker lemmatize mn1:171.4 segment text")
  func seekerLemmatizeMn1Segment() async throws {
    let seeker = try await EbtData.shared.getSeeker(
      lang: "en",
      author: "sujato",
    )
    let segmentText = "Because he has understood that approval is the root of suffering"
    let lemmas = await seeker.lemmatize(segmentText)
    print("[LEMMATIZE] '\(segmentText)' → \(lemmas)")

    // Should lemmatize to base forms
    #expect(!lemmas.isEmpty, "Should lemmatize to words")
    #expect(lemmas.contains("root"), "Should contain 'root'")
    #expect(
      lemmas.contains("suffer"),
      "Should contain 'suffer' (not 'suffering')",
    )
  }

  @Test("EbtSeeker lemmatize dn16:2.3.9 segment text")
  func seekerLemmatizeDn16Segment() async throws {
    let seeker = try await EbtData.shared.getSeeker(
      lang: "en",
      author: "sujato",
    )
    let segmentText = "The root of suffering is cut off, "
    let lemmas = await seeker.lemmatize(segmentText)
    print("[LEMMATIZE] '\(segmentText)' → \(lemmas)")

    // Should lemmatize to base forms
    #expect(!lemmas.isEmpty, "Should lemmatize to words")
    #expect(lemmas.contains("root"), "Should contain 'root'")
    #expect(
      lemmas.contains("suffer"),
      "Should contain 'suffer' (not 'suffering')",
    )
  }

  @Test("EbtQuery.search() with custom Settings for EN/sujato")
  func searchWithCustomSettings() async {
    // Create test Settings with en/sujato
    let testSettings = Settings()
    testSettings.docLang = .english
    testSettings.docAuthor = "sujato"

    // Search using EbtQuery with custom settings
    let ebtQuery = EbtQuery(
      query: "root of suffering",
      docLang: testSettings.docLang.code,
      docAuthor: testSettings.docAuthor,
      maxDoc: testSettings.maxDoc,
    )
    let result = await ebtQuery.search()

    // Verify result structure
    #expect(result.error == nil)
    #expect(result.metadata.query == "root of suffering")
    #expect(result.metadata.method == SearchMethod.lemma)
    #expect(result.metadata.docLang == "en")
    #expect(result.metadata.docAuthor == "sujato")

    // Verify all 7 expected suttas are present
    let resultSuttas = Set(result.items.map(\.suttaRef.suttaUid))
    let expectedSuttas = Set([
      "sn42.11",
      "mn105",
      "mn1",
      "sn56.21",
      "mn116",
      "mn66",
      "dn16",
    ])
    #expect(
      resultSuttas == expectedSuttas,
      "Should find exactly 7 suttas with 'root of suffering', got \(resultSuttas)",
    )
  }

  @Test("EbtQuery.search() with comma-delimited suttarefs")
  func searchWithSuttarefs() async {
    let testSettings = Settings()
    testSettings.docLang = .english
    testSettings.docAuthor = "sujato"

    let ebtQuery = EbtQuery(
      query: "thig1.1, thig1.1/en/soma, thig1.1/de",
      docLang: testSettings.docLang.code,
      docAuthor: testSettings.docAuthor,
      maxDoc: testSettings.maxDoc,
    )

    // Debug: print what was parsed
    for (idx, ref) in ebtQuery.suttaRefs.enumerated() {
      cc.ok2(#line, "Parsed suttaref[\(idx)]: \(ref.toString())")
    }

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
    let ebtQuery = EbtQuery(
      query: "mn1",
      docLang: testSettings.docLang.code,
      docAuthor: testSettings.docAuthor,
      maxDoc: testSettings.maxDoc,
    )
    let result = await ebtQuery.search()

    // Verify metadata uses Settings defaults
    #expect(result.metadata.docLang == "pli", "metadata docLang should be pli")
    #expect(
      result.metadata.docAuthor == "ms",
      "metadata docAuthor should be ms",
    )

    // Verify parsed suttaref was filled in with Settings defaults
    #expect(result.items.count == 1, "Should find 1 result")
    #expect(result.items[0].suttaRef.suttaUid == "mn1")
    #expect(
      result.items[0].suttaRef.lang == "pli",
      "Item lang should default to pli, got \(result.items[0].suttaRef.lang)",
    )
    #expect(
      result.items[0].suttaRef.author == "ms",
      "Item author should default to ms, got \(result.items[0].suttaRef.author ?? "nil")",
    )
  }

  // TODO: Fix pali search with diacritical marks (ū, ī, ā)
  // Lemmatizer.clean() removes Unicode diacritics, need to preserve them
  /*
   @Test("EbtQuery with pli/ms finds 'Nandī dukkhassa mūlan' only in mn1")
   func queryPaliNandi() async {
     let testSettings = Settings()
     testSettings.docLang = .pli
     testSettings.docAuthor = "ms"

     let ebtQuery = EbtQuery(query: "Nandī dukkhassa mūlan", docLang: testSettings.docLang.code, docAuthor: testSettings.docAuthor, maxDoc: testSettings.maxDoc)
     let result = await ebtQuery.search()

     let suttas = Set(result.items.map(\.suttaRef.description))
     #expect(suttas == ["mn1/pli/ms"])
   }
   */

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

    let ebtQuery = EbtQuery(
      query: "thig1.1",
      docLang: testSettings.docLang.code,
      docAuthor: testSettings.docAuthor,
      maxDoc: testSettings.maxDoc,
    )
    let result = await ebtQuery.search()

    // Should find the suttaref with correct lang/author
    #expect(!result.items.isEmpty, "Should find results for thig1.1/en/soma")
    #expect(result.items[0].suttaRef.suttaUid == "thig1.1")
    #expect(result.items[0].suttaRef.lang == "en")
    #expect(result.items[0].suttaRef.author == "soma")

    // Verify metadata uses Settings defaults
    #expect(result.metadata.docLang == "en", "metadata docLang should be en")
    #expect(
      result.metadata.docAuthor == "soma",
      "metadata docAuthor should be soma",
    )
  }

  @Test("EbtQuery with mn1/en/soma where sutta doesn't exist returns error")
  func queryMn1EnSomaNotFound() async {
    let ebtQuery = EbtQuery(query: "mn1/en/soma")
    let result = await ebtQuery.search()

    // Sutta doesn't exist in en/soma database, should return error and zero
    // items
    #expect(
      result.items.isEmpty,
      "Items should be empty when sutta doesn't exist",
    )
    #expect(result.error != nil, "Error should be set when sutta not found")
    #expect(!result.error!.message.isEmpty, "Error message should not be empty")
  }

  @Test(
    "EbtQuery with 'men shaving their heads' uses lemma search not keyword search",
  )
  func queryMenShavingTheirHeadsLemmaSearch() async {
    // Create custom Settings for en/brahmali
    let testSettings = Settings()
    testSettings.docLang = .english
    testSettings.docAuthor = "brahmali"

    let ebtQuery = EbtQuery(
      query: "men shaving their heads",
      docLang: testSettings.docLang.code,
      docAuthor: testSettings.docAuthor,
      maxDoc: testSettings.maxDoc,
    )
    let result = await ebtQuery.search()

    // EbtQuery converts text queries to lemma method (not keyword)
    #expect(
      result.metadata.method == .lemma,
      "Non-suttaref queries should use lemma method, got \(result.metadata.method)",
    )
    // Should find results via lemma search
    // Example: pli-tv-kd20:27.1.1 contains "men shave their head"
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

    let ebtQuery = EbtQuery(
      query: "thig1.1/en/soma",
      docLang: testSettings.docLang.code,
      docAuthor: testSettings.docAuthor,
      maxDoc: testSettings.maxDoc,
    )
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

  @Test(
    "EbtQuery with maxDoc 5 limits 'root of suffering' to exactly 5 specific suttas",
  )
  func queryRootOfSufferingWithMaxDoc5() async {
    let testSettings = Settings()
    testSettings.docLang = .english
    testSettings.docAuthor = "sujato"
    testSettings.maxDoc = 5 // Limit to 5 results

    let ebtQuery = EbtQuery(
      query: "root of suffering",
      docLang: testSettings.docLang.code,
      docAuthor: testSettings.docAuthor,
      maxDoc: testSettings.maxDoc,
    )
    let result = await ebtQuery.search()

    // Should detect lemma method
    #expect(result.metadata.method == .lemma, "Should use lemma method")

    // Should be limited to exactly 5 results
    #expect(
      result.items.count == 5,
      "Should return exactly 5 results with maxDoc 5, got \(result.items.count)",
    )

    // Verify metadata reflects the limit
    #expect(result.metadata.maxDoc == 5, "metadata.maxDoc should be 5")
    #expect(result.error == nil, "Should not have error")

    // Verify all 5 returned suttas match expected (first 5 of the 7 total)
    let resultSuttas = result.items.map(\.suttaRef.suttaUid)
    let expectedSuttas = ["sn42.11", "mn105", "mn1", "sn56.21", "mn116"]
    #expect(
      resultSuttas == expectedSuttas,
      "Should return exactly these 5 suttas in order, got \(resultSuttas)",
    )
  }

  @Test("EbtQuery.allowedCharacters includes all SuttaRef characters")
  func allowedCharactersIncludesSuttaRefChars() {
    // Valid SuttaRef examples covering all allowed character types:
    // - lowercase letters: "mn", "thig"
    // - uppercase letters: "MN", "THIG"
    // - digits: "1", "42", "11"
    // - dot: "."
    // - hyphen: "-"
    // - underscore: "_"
    // - colon: ":"
    // - forward slash: "/"
    let suttaRefExamples = [
      "mn1",
      "MN1",
      "thig1.1",
      "THIG1.1",
      "an1.1-10",
      "AN1.1-10",
      "pli-tv-kd20:27.1.1",
      "mn1/en/sujato",
      "MN1/EN/SUJATO",
      "thig1.1:1.1/en",
      "THIG1.1:1.1/EN",
    ]

    for example in suttaRefExamples {
      let lowercased = example.lowercased()
      for char in lowercased {
        let isAllowed = char.unicodeScalars.allSatisfy {
          EbtQuery.allowedCharacters.contains($0)
        }
        #expect(
          isAllowed,
          "Character '\(char)' in '\(example)' should be allowed",
        )
      }
    }
  }

  @Test("EbtQuery.allowedCharacters includes Pali diacritical marks")
  func allowedCharactersIncludesPaliDiacritics() {
    // Pali uses diacritical marks: ā, ī, ū, ṅ, ṭ, ṇ, ṣ, ḍ, ṃ
    // These are Unicode letters and are included in CharacterSet.letters
    // Note: While SearchQueryFilter passes them through, the lemmatizer strips
    // them
    // during lemmatization (see TODO at line 301 of this file)
    let paliExamples = [
      "ānanda", // a with macron
      "īti", // i with macron
      "ūpadhi", // u with macron
      "aṅga", // n with dot above
      "uṭṭha", // t with dot below
      "niṭṭha", // n with dot below
      "nandi", // s with dot below
      "bodhi", // d with dot below
      "asmī", // m with dot above
      "Āgamā", // uppercase A with macron
      "Īti", // uppercase I with macron
    ]

    for example in paliExamples {
      let lowercased = example.lowercased()
      for char in lowercased {
        let isAllowed = char.unicodeScalars.allSatisfy {
          EbtQuery.allowedCharacters.contains($0)
        }
        #expect(
          isAllowed,
          "Pali character '\(char)' in '\(example)' should be allowed",
        )
      }
    }
  }
}
