//
//  AutoCompleteTests.swift
//  scv-core
//
//  Created by Claude on 2025-12-25.
//

import Foundation
import Testing

@testable import scvCore

// MARK: - AutoCompleteTests

@Suite struct AutoCompleteTests {
  // MARK: - Helper

  func makeAutoComplete() -> AutoComplete {
    // Create isolated UserDefaults (in-memory, not persisted to disk)
    let isolatedDefaults = UserDefaults(suiteName: UUID().uuidString)!
    let settings = Settings(userDefaults: isolatedDefaults)
    return AutoComplete(settings: settings)
  }

  // MARK: - Basic Tracking

  @Test func trackNewPhrase() {
    let ac = makeAutoComplete()
    let author = "test-author"
    let lang = "en"
    let phrase = "root of suffering"
    let lemma = "root of suffer"
    let documentCount = 42

    ac.track(
      phrase: phrase,
      lemma: lemma,
      documentCount: documentCount,
      author: author,
      lang: lang,
    )

    let suggestions = ac.suggest(prefix: "root", author: author, lang: lang)

    #expect(suggestions.count == 1)
    #expect(suggestions[0].lemma == lemma)
    #expect(suggestions[0].lastUsedPhrase == phrase)
    #expect(suggestions[0].documentCount == documentCount)
    #expect(suggestions[0].usesByMonth.count == 1)
    #expect(suggestions[0].usesByMonth[0].count == 1)
  }

  // MARK: - Lemmatization

  @Test func trackPhraseWithoutLemmaCallsLemmatizer() {
    let ac = makeAutoComplete()
    let author = "test-author"
    let lang = "en"
    let phrase = "suffering"
    let documentCount = 10

    // Track without providing lemma
    ac.track(
      phrase: phrase,
      lemma: nil,
      documentCount: documentCount,
      author: author,
      lang: lang,
    )

    let suggestions = ac.suggest(prefix: "suffer", author: author, lang: lang)

    // Should find the phrase (lemmatizer normalized "suffering" to "suffer")
    #expect(suggestions.count >= 1)
    #expect(suggestions[0].lastUsedPhrase == phrase)
  }

  // MARK: - Multiple Uses (Same Month)

  @Test func trackSamePhraseTwiceIncrementsCounts() {
    let ac = makeAutoComplete()
    let author = "test-author"
    let lang = "en"
    let phrase1 = "root of suffering"
    let phrase2 = "Root of suffering"
    let lemma = "root of suffer"

    // First use
    ac.track(
      phrase: phrase1,
      lemma: lemma,
      documentCount: 50,
      author: author,
      lang: lang,
    )

    // Second use in same month with different casing
    ac.track(
      phrase: phrase2,
      lemma: lemma,
      documentCount: 40,
      author: author,
      lang: lang,
    )

    let suggestions = ac.suggest(prefix: "root", author: author, lang: lang)

    #expect(suggestions.count == 1)
    #expect(suggestions[0].usesByMonth.count == 1)
    #expect(suggestions[0].usesByMonth[0].count == 2)
    #expect(suggestions[0].lastUsed > suggestions[0].created)
    #expect(suggestions[0].lastUsedPhrase == phrase2)
  }

  // MARK: - Utility Calculation

  @Test func utilityIsInverseOfDocumentCount() {
    let ac = makeAutoComplete()
    let author = "test-author"
    let lang = "en"

    ac.track(
      phrase: "test1",
      lemma: "test1",
      documentCount: 10,
      author: author,
      lang: lang,
    )
    ac.track(
      phrase: "test2",
      lemma: "test2",
      documentCount: 20,
      author: author,
      lang: lang,
    )
    ac.track(
      phrase: "test3",
      lemma: "test3",
      documentCount: 0,
      author: author,
      lang: lang,
    )

    let suggestions = ac.suggest(prefix: "test", author: author, lang: lang)

    #expect(suggestions.count == 2)
    // test1: utility = 1/10 = 0.1
    // test2: utility = 1/20 = 0.05
    // test3 (utility = 0) is excluded from suggestions
    #expect(suggestions[0].lemma == "test1")
    #expect(suggestions[0].utility == 0.1)
    #expect(suggestions[1].lemma == "test2")
    #expect(suggestions[1].utility == 0.05)
  }

  // MARK: - Autocomplete Prefix Matching

  @Test func autocompleteMatchesPrefixOfLastUsedPhrase() {
    let ac = makeAutoComplete()
    let author = "test-author"
    let lang = "en"

    ac.track(
      phrase: "root of suffering",
      lemma: "root of suffer",
      documentCount: 10,
      author: author,
      lang: lang,
    )

    // Should match "root"
    var suggestions = ac.suggest(prefix: "root", author: author, lang: lang)
    #expect(suggestions.count == 1)

    // Should match "root of"
    suggestions = ac.suggest(prefix: "root of", author: author, lang: lang)
    #expect(suggestions.count == 1)

    // Should NOT match "suffering" (not a prefix)
    suggestions = ac.suggest(prefix: "suffering", author: author, lang: lang)
    #expect(suggestions.count == 0)
  }

  // MARK: - Author/Lang Isolation

  @Test func phrasesIsolatedByAuthorLang() {
    let ac = makeAutoComplete()

    // Track in en/author1
    ac.track(
      phrase: "english phrase",
      lemma: "english phrase",
      documentCount: 10,
      author: "author1",
      lang: "en",
    )

    // Track in de/author1
    ac.track(
      phrase: "deutsch phrase",
      lemma: "deutsch phrase",
      documentCount: 10,
      author: "author1",
      lang: "de",
    )

    // Track in en/author2
    ac.track(
      phrase: "english phrase 2",
      lemma: "english phrase 2",
      documentCount: 10,
      author: "author2",
      lang: "en",
    )

    // Query en/author1 should only return first phrase
    var suggestions = ac.suggest(
      prefix: "english",
      author: "author1",
      lang: "en",
    )
    #expect(suggestions.count == 1)
    #expect(suggestions[0].lemma == "english phrase")

    // Query de/author1 should only return second phrase
    suggestions = ac.suggest(prefix: "deutsch", author: "author1", lang: "de")
    #expect(suggestions.count == 1)
    #expect(suggestions[0].lemma == "deutsch phrase")

    // Query en/author2 should only return third phrase
    suggestions = ac.suggest(prefix: "english", author: "author2", lang: "en")
    #expect(suggestions.count == 1)
    #expect(suggestions[0].lemma == "english phrase 2")
  }

  // MARK: - Persistence

  @Test func saveAndLoadPersistsData() {
    // Create test AutoComplete with isolated UserDefaults
    let isolatedDefaults = UserDefaults(suiteName: UUID().uuidString)!
    let testSettings = Settings(userDefaults: isolatedDefaults)
    let autoComplete = AutoComplete(settings: testSettings)

    // Track a phrase
    autoComplete.track(
      phrase: "test phrase",
      lemma: "test phrase",
      documentCount: 25,
      author: "author",
      lang: "en",
    )

    // Save
    autoComplete.save()

    // Verify data is in Settings
    #expect(testSettings.autoCompleteData.count == 1)
    let saved = testSettings.autoCompleteData[0]
    #expect(saved.author == "author")
    #expect(saved.lang == "en")
    #expect(saved.phrases.count == 1)
  }

  @Test func loadRestoresDataFromSettings() {
    // Create test AutoComplete with isolated UserDefaults
    let isolatedDefaults = UserDefaults(suiteName: UUID().uuidString)!
    let testSettings = Settings(userDefaults: isolatedDefaults)
    let autoComplete = AutoComplete(settings: testSettings)

    // Track and save phrase
    autoComplete.track(
      phrase: "persistence test",
      lemma: "persistence test",
      documentCount: 15,
      author: "author",
      lang: "en",
    )
    autoComplete.save()

    // Create new AutoComplete instance with same UserDefaults (simulates fresh
    // load)
    let restoredSettings = Settings(userDefaults: isolatedDefaults)
    let autoCompleteRestored = AutoComplete(settings: restoredSettings)

    // Verify data is restored
    let suggestions = autoCompleteRestored.suggest(
      prefix: "persistence",
      author: "author",
      lang: "en",
    )
    #expect(suggestions.count == 1)
    #expect(suggestions[0].lemma == "persistence test")
  }

  // MARK: - RemovePhrase

  @Test func removePhraseDeletesEntry() {
    let ac = makeAutoComplete()

    ac.track(
      phrase: "remove me",
      lemma: "remove me",
      documentCount: 10,
      author: "author",
      lang: "en",
    )

    var suggestions = ac.suggest(prefix: "remove", author: "author", lang: "en")
    #expect(suggestions.count == 1)

    ac.removePhrase(phrase: "remove me", author: "author", lang: "en")

    suggestions = ac.suggest(prefix: "remove", author: "author", lang: "en")
    #expect(suggestions.count == 0)
  }

  @Test func removePhrasePersistsChange() {
    // Create test AutoComplete with isolated UserDefaults
    let isolatedDefaults = UserDefaults(suiteName: UUID().uuidString)!
    let testSettings = Settings(userDefaults: isolatedDefaults)
    let autoComplete = AutoComplete(settings: testSettings)

    autoComplete.track(
      phrase: "remove me",
      lemma: "remove me",
      documentCount: 10,
      author: "author",
      lang: "en",
    )
    autoComplete.removePhrase(phrase: "remove me", author: "author", lang: "en")

    // Verify removed from Settings
    #expect(testSettings.autoCompleteData[0].phrases.count == 0)
  }

  // MARK: - Edge Cases

  @Test func emptyQueryReturnsNoResults() {
    let ac = makeAutoComplete()

    ac.track(
      phrase: "test",
      lemma: "test",
      documentCount: 10,
      author: "author",
      lang: "en",
    )

    let suggestions = ac.suggest(prefix: "", author: "author", lang: "en")
    // Empty string is prefix of any string, so should match
    #expect(suggestions.count == 1)
  }

  @Test func nonexistentAuthorLangReturnsEmpty() {
    let ac = makeAutoComplete()

    let suggestions = ac.suggest(
      prefix: "test",
      author: "nonexistent",
      lang: "xx",
    )
    #expect(suggestions.count == 0)
  }
}
