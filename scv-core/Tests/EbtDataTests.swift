@testable import scvCore
import Testing

@Suite("EbtData Tests")
struct EbtDataTests {
  @Test("Get translation by key returns JSON string")
  func getTranslationByKey() async {
    let key = "en/sujato/mn1"
    let json = await EbtData.shared.getTranslation(suttaKey: key)

    #expect(json != nil)
    #expect(json?.contains("mn1") ?? false)
  }

  @Test("Get translation with invalid key returns nil")
  func getTranslationInvalidKey() async {
    let json = await EbtData.shared
      .getTranslation(suttaKey: "en/sujato/invalid999999")

    #expect(json == nil)
  }

  @Test("Keyword search finds matching translations")
  func keywordSearchMatches() async {
    let results = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "suffering",
    )

    #expect(!results.isEmpty)
    #expect(results.count > 0)
  }

  @Test("Keyword search returns valid SuttaRef objects")
  func keywordSearchKeyFormat() async {
    let results = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "root",
    )

    for ref in results {
      #expect(ref.lang == "en")
      #expect(ref.author == "sujato")
      #expect(!ref.suttaUid.isEmpty)
    }
  }

  @Test("Keyword search with nonexistent term returns empty")
  func keywordSearchNoMatches() async {
    let results = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "xyzabc123notaword",
    )

    #expect(results.isEmpty)
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
    let results = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "the",
    )

    #expect(results.count <= 5)
  }

  @Test("Key lookup for known translation succeeds")
  func knownTranslationRetrieval() async {
    let key = "en/sujato/mn1"
    let json = await EbtData.shared.getTranslation(suttaKey: key)

    #expect(json != nil)
    // Verify it contains expected JSON structure
    #expect(json?.contains("\"") ?? false)
  }

  @Test("Search for 'root of suffering' finds translations")
  func rootOfSufferingSearch() async {
    let results = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "root of suffering",
    )

    #expect(!results.isEmpty)
    #expect(results.count > 0)
    // Verify all results are valid SuttaRef objects
    for ref in results {
      #expect(ref.lang == "en")
      #expect(ref.author == "sujato")
      #expect(!ref.suttaUid.isEmpty)
    }
  }

  @Test(
    "'root of suffering' keyword search returns expected keys with segment-level ranking",
  )
  func rootOfSufferingReturnsExpectedKeys() async {
    let results = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "root of suffering",
    )

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

    let resultStrings = results.map { "\($0)" }
    // Keyword search should return all 9 results in ranked order
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
    #expect(results.count == 9)
  }

  @Test("Phrase search finds only suttas with exact phrase")
  func phraseSearchFiltersResults() async {
    let keywordResults = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "root of suffering",
    )
    let phraseResults = await EbtData.shared.searchPhrase(
      lang: "en",
      author: "sujato",
      phrase: "root of suffering",
    )

    // Phrase search should be more restrictive than keyword search
    #expect(phraseResults.count <= keywordResults.count)

    let phraseSuttaStrings = phraseResults.map { "\($0)" }
    // Should exclude false positives like an4.257
    #expect(!phraseSuttaStrings.contains("an4.257/en/sujato"))
    // Should still include suttas with actual phrase
    #expect(phraseSuttaStrings.contains("sn42.11/en/sujato"))
  }

  @Test("Phrase search with nonexistent phrase returns empty")
  func phraseSearchNoMatches() async {
    let results = await EbtData.shared.searchPhrase(
      lang: "en",
      author: "sujato",
      phrase: "xyzabc123notaword phraseneverexists",
    )

    #expect(results.isEmpty)
  }

  @Test(
    "searchKeywords2 returns SearchResult with correct ordering for root of suffering",
  )
  func searchKeywords2RootOfSuffering() async {
    let result = await EbtData.shared.searchKeywords2(
      lang: "en",
      author: "sujato",
      query: "root of suffering",
    )

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

    // Validate SearchResult structure
    #expect(result.error == nil)
    #expect(result.results.count == 9)

    // Validate metadata
    #expect(result.metadata.method == .keyword)
    #expect(result.metadata.query == "root of suffering")
    #expect(result.metadata.docLang == "en")
    #expect(result.metadata.docAuthor == "sujato")
    #expect(result.metadata.elapsedTime > 0)

    // Validate exact ordering and keys
    let resultStrings = result.results.map { "\($0.suttaRef)" }
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
    for item in result.results {
      #expect(item.score > 0, "Score should be positive for \(item.suttaRef)")
    }
  }

  @Test("Display keyword vs phrase search results for 'root of suffering'")
  func displayRootOfSufferingResults() async {
    let keywordResults = await EbtData.shared.searchKeywordsWithScores(
      lang: "en",
      author: "sujato",
      query: "root of suffering",
    )
    let phraseResults = await EbtData.shared.searchPhrase(
      lang: "en",
      author: "sujato",
      phrase: "root of suffering",
    )

    print("\n========== KEYWORD SEARCH: 'root of suffering' ==========")
    print("Total results: \(keywordResults.count)\n")

    for (i, result) in keywordResults.enumerated() {
      let relevancePct = Int(result.relevancePercent * 100)
      print("\(i + 1). \(result.key)")
      print(
        "   Matches: \(result.matchCount), Total segments: \(result.totalSegments)",
      )
      print(
        "   Relevance: \(relevancePct)%, Score: \(String(format: "%.2f", result.score))",
      )
    }

    print("\n========== PHRASE SEARCH: 'root of suffering' ==========")
    print("Total results: \(phraseResults.count)\n")
    for (i, result) in phraseResults.enumerated() {
      print("\(i + 1). \(result)")
    }

    print("\n========== FALSE POSITIVES FILTERED ==========")
    let phraseUids = Set(phraseResults.map(\.suttaUid))
    let falsePositives = keywordResults
      .filter { keywordResult in
        let keyComponents = keywordResult.key.split(separator: "/")
          .map(String.init)
        guard keyComponents.count >= 3 else { return false }
        let suttaUid = keyComponents[2]
        return !phraseUids.contains(suttaUid)
      }
    print("Excluded: \(falsePositives.count) suttas")
    for fp in falsePositives {
      let relevancePct = Int(fp.relevancePercent * 100)
      print(
        "  • \(fp.key): \(fp.matchCount) matches, \(relevancePct)%, score \(String(format: "%.2f", fp.score))",
      )
    }
  }

  @Test("Unified search endpoint returns SearchResult with metadata")
  func searchRootOfSuffering() async {
    let result = await EbtData.shared.search(
      query: "root of suffering",
      docLang: "en",
      docAuthor: "sujato",
    )

    // Verify SearchResult structure
    #expect(result.results.count == 7)
    #expect(result.metadata.query == "root of suffering")
    #expect(result.metadata.method == .phrase)
    #expect(result.metadata.docLang == "en")
    #expect(result.metadata.docAuthor == "sujato")

    // Verify all expected suttas are present
    let resultSuttas = result.results.map(\.suttaRef.suttaUid)
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

  @Test("asSuttaCentralJson matches source file formatting")
  func asSuttaCentralJsonFormatting() async {
    let mlDoc = await EbtData.shared.getMLDocument(
      suttaKey: "en/sujato/an1.1-10",
    )

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
}
