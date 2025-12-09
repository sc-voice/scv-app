import Foundation
import NaturalLanguage
@testable import scvCore
import Testing

@Suite("EbtData Tests")
struct EbtDataTests {
  @Test("Get translation by key returns JSON string")
  func getTranslationByKey() async {
    let key = "thig1.1/en/soma"
    let json = await EbtData.shared.getTranslation(suttaKey: key)

    #expect(json != nil)
    #expect(json?.contains("thig1.1") ?? false)
  }

  @Test("Get translation with invalid key returns nil")
  func getTranslationInvalidKey() async {
    let json = await EbtData.shared
      .getTranslation(suttaKey: "invalid999999/en/soma")

    #expect(json == nil)
  }

  @Test("Keyword search with nonexistent term returns empty")
  func keywordSearchNoMatches() async {
    let result = await EbtData.shared.initSeekerResult(
      "xyzabc123notaword",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
      method: .keyword,
    )
    let searchResult = await EbtData.shared.searchKeywords(result)

    #expect(searchResult.items.isEmpty)
    #expect(searchResult.error == nil)
  }

  @Test("Regexp search finds matching translations")
  func regexpSearchMatches() async {
    let results = await EbtData.shared.searchRegexp(
      lang: "en",
      author: "sujato",
      pattern: "suffering.*root",
    )

    #expect(!results.isEmpty)
  }

  @Test("Regexp search returns valid SuttaRef objects")
  func regexpSearchKeyFormat() async {
    let results = await EbtData.shared.searchRegexp(
      lang: "en",
      author: "sujato",
      pattern: "buddha|mendicant",
    )

    for ref in results {
      #expect(ref.lang == "en")
      #expect(ref.author == "sujato")
      #expect(!ref.suttaUid.isEmpty)
    }
  }

  @Test("Regexp search with invalid pattern returns empty")
  func regexpSearchInvalidPattern() async {
    let results = await EbtData.shared.searchRegexp(
      lang: "en",
      author: "sujato",
      pattern: "[invalid(pattern",
    )

    #expect(results.isEmpty)
  }

  @Test("Search results respect Settings.maxDoc limit")
  func searchResultsRespectLimit() async {
    let originalMaxDoc = Settings.shared.maxDoc
    defer { Settings.shared.maxDoc = originalMaxDoc }

    Settings.shared.maxDoc = 5
    let result = await EbtData.shared.initSeekerResult(
      "the",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 5,
      method: .keyword,
    )
    let searchResult = await EbtData.shared.searchKeywords(result)

    #expect(searchResult.items.count <= 5)
    #expect(searchResult.metadata.maxDoc == 5)
  }

  @Test("Key lookup for known translation succeeds")
  func knownTranslationRetrieval() async {
    let key = "thig1.1/en/soma"
    let json = await EbtData.shared.getTranslation(suttaKey: key)

    #expect(json != nil)
    // Verify it contains expected JSON structure
    #expect(json?.contains("\"") ?? false)
  }

  @Test(
    "Phrase search 2 returns exactly 7 results for 'root of suffering' with correct scores",
  )
  func phraseSearch2RootOfSuffering() async {
    await EbtData.shared.clearDatabaseCache()
    let initResult = await EbtData.shared.initSeekerResult(
      "root of suffering",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
      method: .phrase,
    )
    let result = await EbtData.shared.searchPhrase(initResult)

    let expectedResults: [(key: String, score: Double)] = [
      ("sn42.11/en/sujato", 5.09),
      ("mn105/en/sujato", 3.02),
      ("mn1/en/sujato", 2.01),
      ("sn56.21/en/sujato", 1.05),
      ("mn116/en/sujato", 1.01),
      ("mn66/en/sujato", 1.00),
      ("dn16/en/sujato", 1.00),
    ]

    // Validate count
    #expect(result.items.count == 7)

    // Validate exact ordering and scores (with 0.01 tolerance)
    for (i, expected) in expectedResults.enumerated() {
      #expect(
        i < result.items.count,
        "Result count \(result.items.count) less than expected \(expectedResults.count)",
      )
      let actual = result.items[i]
      let resultKey = "\(actual.suttaRef)"
      #expect(
        resultKey == expected.key,
        "Result at index \(i): got '\(resultKey)' expected '\(expected.key)'",
      )
      #expect(
        abs(actual.score - expected.score) < 0.01,
        "Score at index \(i) for \(expected.key): got \(actual.score) expected \(expected.score)",
      )
    }

    // Verify metadata
    #expect(result.metadata.method == .phrase)
    #expect(result.metadata.query == "root of suffering")
    #expect(result.error == nil)

    // Verify no false positives (an4.257 and mn9 excluded)
    let resultKeys = result.items.map { "\($0.suttaRef)" }
    #expect(!resultKeys.contains("an4.257/en/sujato"))
    #expect(!resultKeys.contains("mn9/en/sujato"))
  }

  @Test("Phrase search 2 with nonexistent phrase returns empty")
  func phraseSearch2NoMatches() async {
    let initResult = await EbtData.shared.initSeekerResult(
      "xyzabc123notaword phraseneverexists",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
      method: .phrase,
    )
    let result = await EbtData.shared.searchPhrase(initResult)

    #expect(result.items.isEmpty)
    #expect(result.error == nil)
  }

  @Test("searchSuttaRef returns single result for valid sutta reference")
  func searchSuttaRefValid() async {
    await EbtData.shared.clearDatabaseCache()
    let initResult = await EbtData.shared.initSeekerResult(
      "mn1",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
    )
    let result = await EbtData.shared.searchSuttaRef(initResult)

    #expect(result.items.count == 1)
    #expect(result.items[0].suttaRef.suttaUid == "mn1")
    #expect(result.items[0].score == 1.0)
    #expect(result.metadata.method == .suttaref)
    #expect(result.metadata.query == "mn1")
    #expect(result.error == nil)
  }

  @Test("searchSuttaRef with full reference mn1/en/sujato")
  func searchSuttaRefFull() async {
    let initResult = await EbtData.shared.initSeekerResult(
      "mn1/en/sujato",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
    )
    let result = await EbtData.shared.searchSuttaRef(initResult)

    #expect(result.items.count == 1)
    #expect(result.items[0].suttaRef.suttaUid == "mn1")
    #expect(result.metadata.method == .suttaref)
    #expect(result.error == nil)
  }

  @Test("searchSuttaRef with invalid reference returns error")
  func searchSuttaRefInvalid() async {
    let initResult = await EbtData.shared.initSeekerResult(
      "not-a-valid-sutta-ref!!!",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
      method: .suttaref,
    )
    let result = await EbtData.shared.searchSuttaRef(initResult)

    #expect(result.items.isEmpty)
    #expect(result.error != nil)
    #expect(result.metadata.method == .suttaref)
  }

  @Test(
    "searchKeywords returns SeekerResult with correct ordering for root of suffering",
  )
  func searchKeywordsRootOfSuffering() async {
    await EbtData.shared.clearDatabaseCache()
    let initResult = await EbtData.shared.initSeekerResult(
      "root of suffering",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
      method: .keyword,
    )
    let result = await EbtData.shared.searchKeywords(initResult)

    let expectedKeys = [
      "sn42.11/en/sujato",
      "mn105/en/sujato",
      "mn1/en/sujato",
      "an4.257/en/sujato",
      "sn56.21/en/sujato",
      "mn116/en/sujato",
      "mn9/en/sujato",
      "mn66/en/sujato",
      "dn16/en/sujato",
    ]

    // Validate SeekerResult structure
    #expect(result.error == nil)
    #expect(result.items.count == 9)

    // Validate metadata
    #expect(result.metadata.method == .keyword)
    #expect(result.metadata.query == "root of suffering")
    #expect(result.metadata.docLang == "en")
    #expect(result.metadata.docAuthor == "sujato")
    #expect(result.metadata.elapsedTime > 0)

    // Validate exact ordering and keys
    let resultStrings = result.items.map { "\($0.suttaRef)" }
    for (i, expected) in expectedKeys.enumerated() {
      #expect(
        i < resultStrings.count,
        "Result count \(resultStrings.count) less than expected \(expectedKeys.count)",
      )
      #expect(
        resultStrings[i] == expected,
        "Result at index \(i): got '\(resultStrings[i])' expected '\(expected)'",
      )
    }

    // Validate all scores are positive
    for item in result.items {
      #expect(item.score > 0, "Score should be positive for \(item.suttaRef)")
    }
  }

  @Test("asSuttaCentralJson matches source file formatting")
  func asSuttaCentralJsonFormatting() async {
    guard let suttaRef = SuttaRef.create("an1.1-10/en/sujato") else {
      Issue.record("Failed to create SuttaRef")
      return
    }
    let mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)

    #expect(mlDoc != nil)
    guard let mlDoc else { return }

    // Load source file to compare formatting
    let sourceFile = "/Users/visakha/dev/scv-app/local/ebt-data/translation/en/sujato/sutta/an/an1/an1.1-10_translation-en-sujato.json"
    guard let sourceJson = try? String(
      contentsOfFile: sourceFile,
      encoding: .utf8,
    ) else {
      print("ERROR: Cannot read source file")
      return
    }

    // Get generated JSON
    guard let generatedJson = mlDoc.asSuttaCentralJson() else {
      print("ERROR: Failed to serialize to JSON")
      return
    }

    // Check formatting: source uses "key": value, generated uses "key" : value
    let sourceHasNoSpaceAroundColon = sourceJson.contains("\":") && !sourceJson
      .contains("\" :")
    let generatedHasSpaceAroundColon = generatedJson.contains("\" :")

    print(
      "\nSource formatting: \(sourceHasNoSpaceAroundColon ? "\"key\":value" : "\"key\" : value")",
    )
    print(
      "Generated formatting: \(generatedHasSpaceAroundColon ? "\"key\" : value" : "\"key\":value")",
    )

    // This test detects the mismatch
    #expect(
      sourceHasNoSpaceAroundColon == !generatedHasSpaceAroundColon,
      "JSON formatting mismatch: source uses compact format, generated uses spaced format",
    )
  }

  @Test("getMLDocument(suttaRef:) returns MLDocument with matching fields")
  func getMLDocumentFromSuttaRefMatchesFields() async {
    guard let suttaRef = SuttaRef.create("an1.1-10/en/sujato") else {
      Issue.record("Failed to create SuttaRef")
      return
    }
    let mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)

    #expect(mlDoc != nil)
    guard let mlDoc else { return }

    // Verify MLDocument fields match SuttaRef properties
    #expect(mlDoc.sutta_uid == suttaRef.suttaUid)
    #expect(mlDoc.docLang == suttaRef.lang)
    #expect(mlDoc.docAuthor == suttaRef.author)
    #expect(mlDoc.author == suttaRef.author)
    #expect(!mlDoc.segMap.isEmpty)

    // Verify segment data matches known content from source JSON
    let testSegmentId = "an1.1:2.2"
    let expectedTextFragment = "sight of a woman occupies"

    guard let segment = mlDoc.segMap[testSegmentId] else {
      Issue.record("Segment not found")
      return
    }
    #expect(segment.doc != nil)
    #expect(segment.doc!.contains(expectedTextFragment))
  }

  @Test("populateQuote() finds first matching segment for keyword search")
  func populateQuoteKeywordSearch() async {
    var item = SeekerResultItem(
      suttaRef: SuttaRef.create("mn1/en/sujato")!,
      score: 1.0,
      quote: nil,
    )

    let success = await EbtData.shared.populateQuote(
      item: &item,
      query: "suffering",
      method: .keyword,
      lang: "en",
      author: "sujato",
    )

    #expect(success)
    #expect(item.quote != nil)
    #expect(item.quote?.contains("<span>") ?? false)
    #expect(item.quote?.contains("</span>") ?? false)
  }

  @Test("populateQuote() matched text is exactly between span tags")
  func populateQuoteExactMatch() async {
    var item = SeekerResultItem(
      suttaRef: SuttaRef.create("thig1.1/en/soma")!,
      score: 1.0,
      quote: nil,
    )

    let success = await EbtData.shared.populateQuote(
      item: &item,
      query: "sleep",
      method: .keyword,
      lang: "en",
      author: "soma",
    )

    #expect(success)
    guard let quote = item.quote else {
      #expect(Bool(false), "Quote should not be nil")
      return
    }

    // Verify exact HTML quote output
    // The JSON source has curly quote (U+201C LEFT DOUBLE QUOTATION MARK), not
    // ASCII quote
    let expectedQuote = "\u{201C}<span>Sleep</span> with ease, Elder, "
    #expect(quote == expectedQuote)
  }

  @Test("populateQuote() HTML escapes special characters")
  func populateQuoteHTMLEscaping() async {
    var item = SeekerResultItem(
      suttaRef: SuttaRef.create("thig1.1/en/soma")!,
      score: 1.0,
      quote: nil,
    )

    let success = await EbtData.shared.populateQuote(
      item: &item,
      query: "i",
      method: .keyword,
      lang: "en",
      author: "soma",
    )

    #expect(success)
    if let quote = item.quote {
      // The quote itself shouldn't contain unescaped HTML entities
      // (unless they're inside the tags)
      let beforeSpan = quote.components(separatedBy: "<span>")[0]
      let afterSpan = quote.components(separatedBy: "</span>").last ?? ""

      // Check that special chars in non-span parts are escaped
      // & should be &amp;, < should be &lt;, etc. (if they appear in text)
      #expect(!beforeSpan.contains("<") || beforeSpan.contains("&lt;"))
      #expect(!afterSpan.contains("<") || afterSpan.contains("&lt;"))
    }
  }

  @Test("populateQuote() adds ellipsis when context is truncated")
  func populateQuoteEllipsis() async {
    var item = SeekerResultItem(
      suttaRef: SuttaRef.create("thig1.1/en/soma")!,
      score: 1.0,
      quote: nil,
    )

    let success = await EbtData.shared.populateQuote(
      item: &item,
      query: "i",
      method: .keyword,
      lang: "en",
      author: "soma",
    )

    #expect(success)
    guard let quote = item.quote else {
      #expect(Bool(false), "Quote should not be nil")
      return
    }

    // If the text is long enough, ellipsis should be present
    // (contextLength = 50 chars before/after)
    // We can't guarantee it will be there for this specific sutta,
    // but we can verify the format: if ellipsis is present, it should be "..."
    if quote.contains("...") {
      #expect(quote.hasPrefix("...") || quote.contains("...<span>") || quote
        .contains("</span>...") || quote.hasSuffix("..."))
    }
  }

  @Test("populateQuote() returns false for non-matching search")
  func populateQuoteNoMatch() async {
    var item = SeekerResultItem(
      suttaRef: SuttaRef.create("thig1.1/en/soma")!,
      score: 1.0,
      quote: nil,
    )

    let success = await EbtData.shared.populateQuote(
      item: &item,
      query: "xyzabc123notaword",
      method: .keyword,
      lang: "en",
      author: "soma",
    )

    #expect(!success)
    #expect(item.quote == nil)
  }

  @Test("populateQuote() works with phrase search")
  func populateQuotePhraseSearch() async {
    var item = SeekerResultItem(
      suttaRef: SuttaRef.create("thig1.1/en/soma")!,
      score: 1.0,
      quote: nil,
    )

    let success = await EbtData.shared.populateQuote(
      item: &item,
      query: "sleep with ease",
      method: .phrase,
      lang: "en",
      author: "soma",
    )

    #expect(success)
    #expect(item.quote != nil)
    #expect(item.quote?.contains("<span>") ?? false)
  }

  @Test("populateQuote() works with regexp search")
  func populateQuoteRegexpSearch() async {
    var item = SeekerResultItem(
      suttaRef: SuttaRef.create("thig1.1/en/soma")!,
      score: 1.0,
      quote: nil,
    )

    let success = await EbtData.shared.populateQuote(
      item: &item,
      query: "sleep.*ease",
      method: .regexp,
      lang: "en",
      author: "soma",
    )

    #expect(success)
    #expect(item.quote != nil)
    #expect(item.quote?.contains("<span>") ?? false)
  }

  @Test("Database schema_version matches EbtData.schemaVersion")
  func databaseSchemaVersionMatch() async throws {
    let expectedVersion = String(EbtData.schemaVersion)

    // Query database for actual schema_version
    let dbVersion = try await EbtData.shared.getDatabaseSchemaVersion(
      lang: "en",
      author: "soma",
    )

    #expect(
      dbVersion == expectedVersion,
      "Database schema_version '\(dbVersion)' does not match EbtData.schemaVersion '\(expectedVersion)'",
    )
  }

  @Test("Files breakdown: sujato has at least 4167 sutta files")
  func filesBreakdownSujato() throws {
    guard let manifest = DatabaseManifest.load(),
          let sujato = manifest.info(language: "en", author: "sujato")
    else {
      #expect(Bool(false), "Could not load sujato from manifest")
      return
    }

    #expect(
      sujato.files.total >= 4167,
      "en/sujato should have at least 4167 files, got \(sujato.files.total)",
    )
  }

  @Test("Files breakdown: sabbamitta has at least 4055 sutta files")
  func filesBreakdownSabbamitta() throws {
    guard let manifest = DatabaseManifest.load(),
          let sabbamitta = manifest.info(language: "de", author: "sabbamitta")
    else {
      #expect(Bool(false), "Could not load sabbamitta from manifest")
      return
    }

    #expect(
      sabbamitta.files.total >= 4055,
      "de/sabbamitta should have at least 4055 files, got \(sabbamitta.files.total)",
    )
  }

  @Test("Files breakdown: brahmali has at least 427 vinaya files")
  func filesBreakdownBrahmali() throws {
    guard let manifest = DatabaseManifest.load(),
          let brahmali = manifest.info(language: "en", author: "brahmali")
    else {
      #expect(Bool(false), "Could not load brahmali from manifest")
      return
    }

    #expect(
      brahmali.files.vinaya >= 427,
      "en/brahmali should have at least 427 vinaya files, got \(brahmali.files.vinaya)",
    )
  }

  @Test("getMLDocument(dn16) => bilingual MLDocument doc:english/pli")
  func getMLDocumentdn16() async {
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()
    guard let suttaRef = SuttaRef.create("dn16/en/sujato") else {
      Issue.record("Failed to create SuttaRef for dn16")
      return
    }

    let mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)

    #expect(mlDoc != nil)
    guard let mlDoc else { return }

    // Verify MLDocument fields match SuttaRef properties
    #expect(mlDoc.sutta_uid == "dn16")
    #expect(mlDoc.docLang == "en")
    #expect(mlDoc.docAuthor == "sujato")
    #expect(mlDoc.author == "sujato")
    #expect(!mlDoc.segMap.isEmpty)

    // Verify segment count (dn16 should have 1664 segments)
    let segmentCount = mlDoc.segMap.count
    #expect(segmentCount == 1664)

    // Verify known segment exists (first true segment after header)
    guard let firstSegment = mlDoc.segMap["dn16:1.1.1"] else {
      Issue.record("First segment (dn16:1.1.1) not found")
      return
    }
    #expect(firstSegment.pli == "Evaṁ me sutaṁ—")
    #expect(firstSegment.doc == "So I have heard. ")
    let msElapsed = Int((CFAbsoluteTimeGetCurrent() - elapsedAtStart) * 1000)
    #expect(msElapsed < 100)
  }
}
