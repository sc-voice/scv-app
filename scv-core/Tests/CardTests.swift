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
}
