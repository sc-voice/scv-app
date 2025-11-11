import Testing
@testable import scvCore

@Suite("EbtData Tests")
struct EbtDataTests {
  @Test("Get translation by key returns JSON string")
  func getTranslationByKey() async {
    let key = "en/sujato/mn1"
    let json = await EbtData.shared.getTranslation(key: key)

    #expect(json != nil)
    #expect(json?.contains("mn1") ?? false)
  }

  @Test("Get translation with invalid key returns nil")
  func getTranslationInvalidKey() async {
    let json = await EbtData.shared.getTranslation(key: "en/sujato/invalid999999")

    #expect(json == nil)
  }

  @Test("Keyword search finds matching translations")
  func keywordSearchMatches() async {
    let results = await EbtData.shared.searchKeywords(query: "suffering")

    #expect(!results.isEmpty)
    #expect(results.count > 0)
  }

  @Test("Keyword search returns keys in correct format")
  func keywordSearchKeyFormat() async {
    let results = await EbtData.shared.searchKeywords(query: "root")

    for key in results {
      #expect(key.hasPrefix("en/sujato/"))
    }
  }

  @Test("Keyword search with nonexistent term returns empty")
  func keywordSearchNoMatches() async {
    let results = await EbtData.shared.searchKeywords(query: "xyzabc123notaword")

    #expect(results.isEmpty)
  }

  @Test("Regexp search finds matching translations")
  func regexpSearchMatches() async {
    let results = await EbtData.shared.searchRegexp(pattern: "suffering.*root")

    #expect(!results.isEmpty)
  }

  @Test("Regexp search returns keys in correct format")
  func regexpSearchKeyFormat() async {
    let results = await EbtData.shared.searchRegexp(pattern: "buddha|mendicant")

    for key in results {
      #expect(key.hasPrefix("en/sujato/"))
    }
  }

  @Test("Regexp search with invalid pattern returns empty")
  func regexpSearchInvalidPattern() async {
    let results = await EbtData.shared.searchRegexp(pattern: "[invalid(pattern")

    #expect(results.isEmpty)
  }

  @Test("Search results respect Settings.maxDoc limit")
  func searchResultsRespectLimit() async {
    let originalMaxDoc = Settings.shared.maxDoc
    defer { Settings.shared.maxDoc = originalMaxDoc }

    Settings.shared.maxDoc = 5
    let results = await EbtData.shared.searchKeywords(query: "the")

    #expect(results.count <= 5)
  }

  @Test("Key lookup for known translation succeeds")
  func knownTranslationRetrieval() async {
    let key = "en/sujato/mn1"
    let json = await EbtData.shared.getTranslation(key: key)

    #expect(json != nil)
    // Verify it contains expected JSON structure
    #expect(json?.contains("\"") ?? false)
  }

  @Test("Search for 'root of suffering' finds translations")
  func rootOfSufferingSearch() async {
    let results = await EbtData.shared.searchKeywords(query: "root of suffering")

    #expect(!results.isEmpty)
    #expect(results.count > 0)
    // Verify all results are valid keys
    for key in results {
      #expect(key.hasPrefix("en/sujato/"))
    }
  }

  @Test("'root of suffering' search returns expected keys")
  func rootOfSufferingReturnsExpectedKeys() async {
    let results = await EbtData.shared.searchKeywords(query: "root of suffering")

    let expectedKeys = [
      "en/sujato/sn42.11",
      "en/sujato/mn105",
      "en/sujato/mn1",
      "en/sujato/sn56.21",
      "en/sujato/mn116",
      "en/sujato/mn66",
      "en/sujato/dn16"
    ]

    let foundKeys = expectedKeys.filter { results.contains($0) }
    #expect(foundKeys.count == results.count)
  }
}
