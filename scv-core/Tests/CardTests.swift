import Foundation
import Testing
import SwiftData
@testable import scvCore

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
  func cardTitle() {
    let card = Card(cardType: .search, typeId: 5)
    let title = card.title()

    #expect(title.contains("Search"))
    #expect(title.contains("5"))
  }

  @Test
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
  func cardPortugueseLocalization() {
    // Load the pt-PT localization bundle
    guard let bundle = Bundle.module.url(forResource: "pt-PT", withExtension: "lproj"),
          let localizedBundle = Bundle(url: bundle) else {
      #expect(Bool(false), "Failed to load pt-PT localization bundle")
      return
    }

    // Create cards
    let searchCard = Card(cardType: .search)
    let suttaCard = Card(cardType: .sutta)

    // Get the localized names from the cards
    let searchLocalized = searchCard.localizedCardTypeName()
    let suttaLocalized = suttaCard.localizedCardTypeName()

    // Verify Portuguese translations are available in the bundle for the same keys
    let searchPortuguese = NSLocalizedString(
      "card.type.search",
      bundle: localizedBundle,
      comment: "Card type label for search card"
    )
    let suttaPortuguese = NSLocalizedString(
      "card.type.sutta",
      bundle: localizedBundle,
      comment: "Card type label for sutta viewer card"
    )

    // Verify that the Portuguese translations are different from English (i.e., they're actually translated)
    #expect(searchPortuguese == "Pesquisa")
    #expect(searchLocalized == "Search") // In test env, uses system locale (English)

    // Sutta is the same in both languages (proper noun)
    #expect(suttaPortuguese == "Sutta")
    #expect(suttaLocalized == "Sutta")
  }
}
