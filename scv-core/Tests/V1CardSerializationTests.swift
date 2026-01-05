//
//  V1CardSerializationTests.swift
//  scv-core
//
//  V1 serialization baseline tests for Card.
//  These tests verify that the current serialization format can be used to
//  generate v1 fixtures for backward compatibility testing.
//
//  See: doc/Serialization.md for fixture management and versioning strategy.
//

import Foundation
@testable import scvCore
import Testing

@Suite("V1CardSerializationTests")
struct V1CardSerializationTests {
  // MARK: - Configuration

  /// Enable fixture generation. Set to false to skip saving fixtures.
  static let GENERATE_V1_FIXTURES = false

  // MARK: - Helpers

  static func getFixtureJSON(_ card: Card, testName: String) throws -> Data {
    let fixturesPath = "/Users/visakha/dev/scv-app/scv-core/Tests/Fixtures"
    let filePath = "\(fixturesPath)/V1_\(testName).json"

    if GENERATE_V1_FIXTURES {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let encoded = try encoder.encode(card)

      try FileManager.default.createDirectory(
        atPath: fixturesPath,
        withIntermediateDirectories: true,
        attributes: nil,
      )
      try encoded.write(to: URL(fileURLWithPath: filePath))
      return encoded
    } else {
      return try Data(contentsOf: URL(fileURLWithPath: filePath))
    }
  }

  // MARK: - Serialization: Sutta Card

  @Test func cardRoundTripSerialization() throws {
    /// Test sutta card serialization (nil searchResults)
    let originalCard = Card(
      cardType: .sutta,
      typeId: 5,
      searchQuery: "",
      suttaReference: "MN 10",
    )

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(originalCard, testName: "Card_Sutta")

    // Decode
    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: encoded)

    // Verify properties match
    // Note: UUID from fixture, not from originally created card
    #expect(decodedCard
      .uuid == UUID(uuidString: "A6B95362-41F5-4E9F-A532-E3E65E5CE58C"))
    #expect(decodedCard.cardType == originalCard.cardType)
    #expect(decodedCard.typeId == originalCard.typeId)
    #expect(decodedCard.searchQuery == originalCard.searchQuery)
    #expect(decodedCard.suttaReference == originalCard.suttaReference)
  }

  // MARK: - Serialization: Search Card with Results

  @Test func cardWithSearchResponseRoundTrip() throws {
    /// Test search card with basic SearchResponse
    let searchResponse = SearchResponse(
      author: "test",
      lang: "en",
      pattern: "anicca",
      segsMatched: 10,
    )
    let originalCard = Card(
      cardType: .search,
      typeId: 3,
      searchQuery: "anicca",
      searchResults: searchResponse,
    )

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(originalCard, testName: "Card_Search")

    // Decode
    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: encoded)

    // Verify values from fixture
    #expect(decodedCard
      .uuid == UUID(uuidString: "34BB54E5-1004-46AF-9481-F6FABC1A947F"))
    #expect(decodedCard.cardType == originalCard.cardType)
    #expect(decodedCard.searchResults != nil)
    #expect(decodedCard.searchResults?.pattern == originalCard.searchResults?
      .pattern)
    #expect(decodedCard.searchResults?.author == originalCard.searchResults?
      .author)
    #expect(decodedCard.searchResults?.segsMatched == originalCard
      .searchResults?.segsMatched)
  }

  @Test func cardWithMockSearchResponseRoundTrip() throws {
    /// Test search card with mlDocs (mock SearchResponse)
    guard let mockResponse = SearchResponse.createMockResponse() else {
      #expect(Bool(false), "Failed to load mock SearchResponse")
      return
    }

    let originalCard = Card(
      cardType: .search,
      typeId: 2,
      searchQuery: "root of suffering",
      searchResults: mockResponse,
    )

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(
      originalCard,
      testName: "Card_SearchWithMlDocs",
    )

    // Decode
    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: encoded)

    // Verify values from fixture
    #expect(decodedCard
      .uuid == UUID(uuidString: "74EA6822-BE14-4E69-9F3C-5871BC9E94CD"))
    #expect(decodedCard.searchResults != nil)
    #expect(decodedCard.searchResults?.pattern == originalCard.searchResults?
      .pattern)
    #expect(decodedCard.searchResults?.author == originalCard.searchResults?
      .author)
    #expect(decodedCard.searchResults?.mlDocs.count == originalCard
      .searchResults?.mlDocs.count)

    // Verify nested MLDocument data
    let doc = decodedCard.searchResults?.mlDocs.first
    let origDoc = originalCard.searchResults?.mlDocs.first
    #expect(doc?.sutta_uid == origDoc?.sutta_uid)
    #expect(doc?.segMap.count == origDoc?.segMap.count)
  }

  @Test func cardWithNilSearchResponse() throws {
    /// Test new search card before search (nil searchResults)
    let card = Card(
      cardType: .search,
      typeId: 3,
      searchQuery: "test",
      searchResults: nil,
    )

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(card, testName: "Card_SearchNil")

    // Decode
    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: encoded)

    // Verify values from fixture
    #expect(decodedCard
      .uuid == UUID(uuidString: "19C8FF11-8A99-45E9-ADD8-B74E5D0A11E8"))
    #expect(decodedCard.searchResults == nil)
  }

  @Test func cardWithEmptySearchResponse() throws {
    /// Test search card with no results (empty SearchResponse)
    let emptyResponse = SearchResponse()
    let card = Card(
      cardType: .search,
      typeId: 4,
      searchResults: emptyResponse,
    )

    // Encode and save/load fixture
    let encoded = try Self.getFixtureJSON(card, testName: "Card_SearchEmpty")

    // Decode
    let decoder = JSONDecoder()
    let decodedCard = try decoder.decode(Card.self, from: encoded)

    // Verify values from fixture
    #expect(decodedCard
      .uuid == UUID(uuidString: "FA5912AD-9675-46DE-A3F4-3E07041797A2"))
    #expect(decodedCard.searchResults != nil)
    #expect(decodedCard.searchResults?.mlDocs.count == card.searchResults?
      .mlDocs.count)
    #expect(decodedCard.searchResults?.pattern == card.searchResults?.pattern)
  }
}
