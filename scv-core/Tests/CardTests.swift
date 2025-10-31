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
    let beforeCreation = Date()
    let card = Card()

    #expect(card.cardType == .search)
    #expect(card.typeId == 0)
    #expect(card.searchQuery == "")
    #expect(card.searchResults == nil)
    #expect(card.suttaReference == "")

    // createdAt should be within 1 second of now
    let timeDifference = abs(card.createdAt.timeIntervalSince(beforeCreation))
    #expect(timeDifference <= 1.0)
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

  // Verify Card gets PersistentIdentifier automatically
  @Test
  func testCardHasUUID() {
    let card = Card()
    // #expect(card.id is PersistentIdentifier)

    let card2 = Card()
    // #expect(card2.id is PersistentIdentifier)
    #expect(card.id != card2.id)
  }

  // MARK: - Codable Tests

  @Test
  func cardEncodesToJSON() throws {
    let card = Card(
      cardType: .search,
      typeId: 1,
      searchQuery: "mindfulness"
    )

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(card)
    let jsonString = String(data: jsonData, encoding: .utf8)

    #expect(jsonString != nil)
    #expect(jsonString?.contains("\"uuid\"") ?? false)
    #expect(jsonString?.contains("\"cardType\":\"search\"") ?? false)
    #expect(jsonString?.contains("\"typeId\":1") ?? false)
    #expect(jsonString?.contains("\"searchQuery\":\"mindfulness\"") ?? false)
  }

  @Test
  func cardDecodesFromJSON() throws {
    let json = """
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "createdAt": 725846400.0,
      "cardType": "search",
      "typeId": 2,
      "searchQuery": "dhamma",
      "searchResults": null,
      "suttaReference": ""
    }
    """

    let decoder = JSONDecoder()
    let card = try decoder.decode(Card.self, from: json.data(using: .utf8)!)

    #expect(card.uuid == UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
    #expect(card.cardType == .search)
    #expect(card.typeId == 2)
    #expect(card.searchQuery == "dhamma")
    #expect(card.searchResults == nil)
    #expect(card.suttaReference == "")
  }

  @Test
  func cardRoundTripSerialization() throws {
    let originalCard = Card(
      cardType: .sutta,
      typeId: 5,
      searchQuery: "",
      suttaReference: "MN 10"
    )
    let originalUUID = originalCard.uuid

    // Encode to JSON
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(originalCard)

    // Decode from JSON
    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: jsonData)

    // Verify properties match
    #expect(decodedCard.uuid == originalUUID)
    #expect(decodedCard.cardType == originalCard.cardType)
    #expect(decodedCard.typeId == originalCard.typeId)
    #expect(decodedCard.searchQuery == originalCard.searchQuery)
    #expect(decodedCard.suttaReference == originalCard.suttaReference)
    #expect(decodedCard.createdAt == originalCard.createdAt)
  }

  @Test
  func cardWithSearchResponseRoundTrip() throws {
    let searchResponse = SearchResponse(
      author: "test",
      lang: "en",
      pattern: "anicca",
      segsMatched: 10
    )
    let originalCard = Card(
      cardType: .search,
      typeId: 3,
      searchQuery: "anicca",
      searchResults: searchResponse
    )

    // Encode and decode
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(originalCard)

    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: jsonData)

    // Verify SearchResponse survived round-trip
    #expect(decodedCard.searchResults != nil)
    #expect(decodedCard.searchResults?.pattern == "anicca")
    #expect(decodedCard.searchResults?.author == "test")
    #expect(decodedCard.searchResults?.segsMatched == 10)
  }

  @Test
  func cardUUIDPreservedAcrossInstances() throws {
    let card1 = Card(cardType: .search, typeId: 1)
    let uuid1 = card1.uuid

    // Encode and decode
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(card1)

    let decoder = JSONDecoder()
    let card2 = try decoder.decode(Card.self, from: jsonData)

    // UUID should be the same
    #expect(card2.uuid == uuid1)

    // But PersistentIdentifier should be different (regenerated)
    #expect(card1.id != card2.id)
  }

  // MARK: - Card/SearchResponse Relationship Tests

  @Test
  func cardWithMockSearchResponse() throws {
    guard let mockResponse = SearchResponse.createMockResponse() else {
      #expect(Bool(false), "Failed to load mock SearchResponse")
      return
    }

    let card = Card(
      cardType: .search,
      typeId: 1,
      searchQuery: "root of suffering",
      searchResults: mockResponse
    )

    #expect(card.searchResults != nil)
    #expect(card.searchResults?.pattern == "root of suffering")
    #expect(card.searchResults?.author == "sujato")
    #expect(card.searchResults?.mlDocs.count == 1)
  }

  @Test
  func cardMockSearchResponseNestedDataIntegrity() throws {
    guard let mockResponse = SearchResponse.createMockResponse() else {
      #expect(Bool(false), "Failed to load mock SearchResponse")
      return
    }

    let card = Card(
      cardType: .search,
      typeId: 1,
      searchResults: mockResponse
    )

    guard let response = card.searchResults else {
      #expect(Bool(false), "SearchResponse should not be nil")
      return
    }

    // Verify SearchResponse fields
    #expect(response.author == "sujato")
    #expect(response.lang == "en")
    #expect(response.pattern == "root of suffering")
    #expect(response.segsMatched == 14)

    // Verify MLDocument
    #expect(response.mlDocs.count == 1)
    let doc = response.mlDocs.first!
    #expect(doc.author == "Bhikkhu Sujato")
    #expect(doc.segMap.count == 55)

    // Verify Segment data
    let segment = doc.segMap["sn42.11:2.11"]
    #expect(segment != nil)
    #expect(segment?.matched == true)
    #expect(segment?.en != nil)
  }

  @Test
  func cardWithMockSearchResponseRoundTrip() throws {
    guard let mockResponse = SearchResponse.createMockResponse() else {
      #expect(Bool(false), "Failed to load mock SearchResponse")
      return
    }

    let originalCard = Card(
      cardType: .search,
      typeId: 2,
      searchQuery: "root of suffering",
      searchResults: mockResponse
    )

    // Encode and decode
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(originalCard)

    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: jsonData)

    // Verify SearchResponse survived round-trip
    #expect(decodedCard.searchResults != nil)
    #expect(decodedCard.searchResults?.pattern == "root of suffering")
    #expect(decodedCard.searchResults?.author == "sujato")
    #expect(decodedCard.searchResults?.mlDocs.count == 1)

    // Verify nested MLDocument data
    let doc = decodedCard.searchResults?.mlDocs.first
    #expect(doc?.sutta_uid == "sn42.11")
    #expect(doc?.segMap.count == 55)
  }

  @Test
  func cardWithNilSearchResponse() throws {
    let card = Card(
      cardType: .search,
      typeId: 3,
      searchQuery: "test",
      searchResults: nil
    )

    #expect(card.searchResults == nil)

    // Encode and decode
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(card)

    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: jsonData)

    #expect(decodedCard.searchResults == nil)
  }

  @Test
  func cardWithEmptySearchResponse() throws {
    let emptyResponse = SearchResponse()
    let card = Card(
      cardType: .search,
      typeId: 4,
      searchResults: emptyResponse
    )

    #expect(card.searchResults != nil)
    #expect(card.searchResults?.mlDocs.count == 0)
    #expect(card.searchResults?.pattern == "")

    // Encode and decode
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(card)

    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: jsonData)

    #expect(decodedCard.searchResults != nil)
    #expect(decodedCard.searchResults?.mlDocs.count == 0)
    #expect(decodedCard.searchResults?.pattern == "")
  }
}
