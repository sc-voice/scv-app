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
      .uuid == UUID(uuidString: "0071F6BA-FF58-4641-B3EC-05A23745FB49"))
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
      .uuid == UUID(uuidString: "594DD7B5-1B95-4CD2-80F1-220F1639D28B"))
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
      .uuid == UUID(uuidString: "5E2A9EC7-5BE2-4964-89AD-201E7DBD0EBF"))
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
      .uuid == UUID(uuidString: "011B7BC2-5AC2-48BE-A7DD-0FB56912B564"))
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
      .uuid == UUID(uuidString: "A44829E3-E861-4D86-BF45-A5465B032EF2"))
    #expect(decodedCard.searchResults != nil)
    #expect(decodedCard.searchResults?.mlDocs.count == card.searchResults?
      .mlDocs.count)
    #expect(decodedCard.searchResults?.pattern == card.searchResults?.pattern)
  }
}
