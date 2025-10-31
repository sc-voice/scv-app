import Foundation
import Testing
import SwiftData
@testable import scvCore

/// Test helper to temporarily swap localization bundle
@MainActor
func withLocalizationBundle(_ bundle: Bundle, _ test: () -> Void) {
  let originalBundle = localizationBundle
  localizationBundle = bundle
  defer { localizationBundle = originalBundle }
  test()
}

@Suite
struct CardTests {

  @Test
  func cardDefaultInitialization() {
    let card = Card()

    #expect(card.cardType == .search)
    #expect(card.typeId == 0)
    #expect(card.searchQuery == "")
    #expect(card.searchResults == nil)
    #expect(card.suttaReference == "")
  }

  @Test
  func cardIconName() {
    let searchCard = Card(cardType: .search)
    #expect(searchCard.iconName() == "magnifyingglass")

    let suttaCard = Card(cardType: .sutta)
    #expect(suttaCard.iconName() == "book")
  }

  @Test
  @MainActor
  func cardTitle() {
    let card = Card(cardType: .search, typeId: 5)
    let title = card.title()

    #expect(title.contains("Search"))
    #expect(title.contains("5"))
  }

  @Test
  @MainActor
  func cardLocalizedCardTypeName() {
    let searchCard = Card(cardType: .search)
    let searchName = searchCard.localizedCardTypeName()
    #expect(searchName == "Search")

    let suttaCard = Card(cardType: .sutta)
    let suttaName = suttaCard.localizedCardTypeName()
    #expect(suttaName == "Sutta")
  }

  @Test
  func cardWithSearchResults() {
    let response = SearchResponse(pattern: "mindfulness")
    let card = Card(cardType: .search, searchResults: response)

    #expect(card.searchResults != nil)
    #expect(card.searchResults?.pattern == "mindfulness")
  }

  @Test
  @MainActor
  func cardPortugueseLocalization() {
    // Load the pt-PT localization bundle
    guard let bundle = Bundle.module.url(forResource: "pt-PT", withExtension: "lproj"),
          let portugueseBundle = Bundle(url: bundle) else {
      #expect(Bool(false), "Failed to load pt-PT localization bundle")
      return
    }

    withLocalizationBundle(portugueseBundle) {
      let searchCard = Card(cardType: .search)
      let suttaCard = Card(cardType: .sutta)

      let searchLocalized = searchCard.localizedCardTypeName()
      let suttaLocalized = suttaCard.localizedCardTypeName()

      #expect(searchLocalized == "Pesquisa")
      #expect(suttaLocalized == "Sutta")
    }
  }

  @Test
  @MainActor
  func cardEnglishLocalization() {
    let searchCard = Card(cardType: .search)
    let suttaCard = Card(cardType: .sutta)

    #expect(searchCard.localizedCardTypeName() == "Search")
    #expect(suttaCard.localizedCardTypeName() == "Sutta")
  }

  @Test
  @MainActor
  func cardLocalizationKeysExist() {
    // Verify all required localization keys exist in the default bundle
    let searchKey = "card.type.search"
    let suttaKey = "card.type.sutta"

    let searchString = searchKey.localized
    let suttaString = suttaKey.localized

    // Keys should resolve to non-empty strings (not remain as keys)
    #expect(!searchString.isEmpty)
    #expect(!suttaString.isEmpty)
    #expect(searchString == "Search")
    #expect(suttaString == "Sutta")
  }

  @Test
  @MainActor
  func cardLocalizationKeysExistInPortuguese() {
    guard let bundle = Bundle.module.url(forResource: "pt-PT", withExtension: "lproj"),
          let portugueseBundle = Bundle(url: bundle) else {
      #expect(Bool(false), "Failed to load pt-PT localization bundle")
      return
    }

    withLocalizationBundle(portugueseBundle) {
      let searchKey = "card.type.search"
      let suttaKey = "card.type.sutta"

      let searchString = searchKey.localized
      let suttaString = suttaKey.localized

      // Keys should resolve to translations in Portuguese
      #expect(!searchString.isEmpty)
      #expect(!suttaString.isEmpty)
      #expect(searchString == "Pesquisa")
      #expect(suttaString == "Sutta")
    }
  }
}
