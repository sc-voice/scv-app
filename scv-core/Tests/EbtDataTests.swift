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
    let result = await EbtData.shared.searchKeywords2(
      lang: "en",
      author: "sujato",
      query: "xyzabc123notaword",
    )

    #expect(result.results.isEmpty)
    #expect(result.error == nil)
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
    let result = await EbtData.shared.searchKeywords2(
      lang: "en",
      author: "sujato",
      query: "the",
    )

    #expect(result.results.count <= 5)
    #expect(result.metadata.maxDoc == 5)
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
    let result = await EbtData.shared.searchPhrase2(
      lang: "en",
      author: "sujato",
      phrase: "root of suffering",
    )

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
    #expect(result.results.count == 7)

    // Validate exact ordering and scores (with 0.01 tolerance)
    for (i, expected) in expectedResults.enumerated() {
      #expect(
        i < result.results.count,
        "Result count \(result.results.count) less than expected \(expectedResults.count)",
      )
      let actual = result.results[i]
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
    let resultKeys = result.results.map { "\($0.suttaRef)" }
    #expect(!resultKeys.contains("an4.257/en/sujato"))
    #expect(!resultKeys.contains("mn9/en/sujato"))
  }

  @Test("Phrase search 2 with nonexistent phrase returns empty")
  func phraseSearch2NoMatches() async {
    let result = await EbtData.shared.searchPhrase2(
      lang: "en",
      author: "sujato",
      phrase: "xyzabc123notaword phraseneverexists",
    )

    #expect(result.results.isEmpty)
    #expect(result.error == nil)
  }

  @Test(
    "searchKeywords2 returns SearchResult with correct ordering for root of suffering",
  )
  func searchKeywords2RootOfSuffering() async {
    await EbtData.shared.clearDatabaseCache()
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
      suttaKey: "an1.1-10/en/sujato",
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
