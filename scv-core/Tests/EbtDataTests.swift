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

  @Test("Keyword search returns keys in correct format")
  func keywordSearchKeyFormat() async {
    let results = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "root",
    )

    for key in results {
      #expect(key.hasPrefix("en/sujato/"))
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

  @Test("Regexp search returns keys in correct format")
  func regexpSearchKeyFormat() async {
    let results = await EbtData.shared.searchRegexp(
      lang: "en",
      author: "sujato",
      pattern: "buddha|mendicant",
    )

    for key in results {
      #expect(key.hasPrefix("en/sujato/"))
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
    // Verify all results are valid keys
    for key in results {
      #expect(key.hasPrefix("en/sujato/"))
    }
  }

  @Test(
    "'root of suffering' search returns expected keys with segment-level ranking",
  )
  func rootOfSufferingReturnsExpectedKeys() async {
    let results = await EbtData.shared.searchKeywords(
      lang: "en",
      author: "sujato",
      query: "root of suffering",
    )

    let expectedKeys = [
      "en/sujato/sn42.11",
      "en/sujato/mn105",
      "en/sujato/mn1",
      "en/sujato/sn56.21",
      "en/sujato/mn116",
      "en/sujato/mn66",
      "en/sujato/dn16",
    ]

    let foundKeys = expectedKeys.filter { results.contains($0) }
    // Segment-level ranking should find all 7 expectedKeys
    #expect(foundKeys.count == 7)
    // Should be more selective than BM25 (9 results vs 50 before)
    #expect(results.count < 50)
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
    // Should exclude false positives like an4.257
    #expect(!phraseResults.contains("en/sujato/an4.257"))
    // Should still include suttas with actual phrase
    #expect(phraseResults.contains("en/sujato/sn42.11"))
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
    let falsePositives = keywordResults
      .filter { !phraseResults.contains($0.key) }
    print("Excluded: \(falsePositives.count) suttas")
    for fp in falsePositives {
      let relevancePct = Int(fp.relevancePercent * 100)
      print(
        "  • \(fp.key): \(fp.matchCount) matches, \(relevancePct)%, score \(String(format: "%.2f", fp.score))",
      )
    }
  }

  @Test("asSuttaCentralJson matches source file formatting")
  func asSuttaCentralJsonFormatting() async {
    let mlDoc = await EbtData.shared.getMLDocument(
      suttaKey: "en/sujato/an1.1-10",
    )

    #expect(mlDoc != nil)
    guard let mlDoc = mlDoc else { return }

    // Load source file to compare formatting
    let sourceFile = "/Users/visakha/dev/scv-app/local/ebt-data/translation/en/sujato/sutta/an/an1/an1.1-10_translation-en-sujato.json"
    guard let sourceJson = try? String(contentsOfFile: sourceFile, encoding: .utf8) else {
      print("ERROR: Cannot read source file")
      return
    }

    // Get generated JSON
    guard let generatedJson = mlDoc.asSuttaCentralJson() else {
      print("ERROR: Failed to serialize to JSON")
      return
    }

    // Check formatting: source uses "key": value, generated uses "key" : value
    let sourceHasNoSpaceAroundColon = sourceJson.contains("\":") && !sourceJson.contains("\" :")
    let generatedHasSpaceAroundColon = generatedJson.contains("\" :")

    print("\nSource formatting: \(sourceHasNoSpaceAroundColon ? "\"key\":value" : "\"key\" : value")")
    print("Generated formatting: \(generatedHasSpaceAroundColon ? "\"key\" : value" : "\"key\":value")")

    // This test detects the mismatch
    #expect(
      sourceHasNoSpaceAroundColon == !generatedHasSpaceAroundColon,
      "JSON formatting mismatch: source uses compact format, generated uses spaced format",
    )
  }
}
