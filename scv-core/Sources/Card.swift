//
//  Card.swift
//  scv-apple
//
//  Created by Visakha on 22/10/2025.
//

import Foundation
import SwiftData

// MARK: - CardType Enum

enum CardType: String, CaseIterable, Codable {
  case search
  case sutta
}

// MARK: - Card Model

@Model
final class Card: Codable {
  typealias ID = PersistentIdentifier

  // MARK: - Properties

  private(set) var uuid: UUID = UUID()
  private(set) var createdAt: Date
  private(set) var cardType: CardType
  @MainActor
  var name: String {
    return "\(localizedCardTypeName()) \(typeId)"
  }

  private(set) var typeId: Int

  // Search card properties
  var searchQuery: String = ""
  var searchResults: SearchResponse?

  // Sutta card properties
  var suttaReference: String = ""

  // Document display (for viewing segments with selection tracking)
  var mlDoc: MLDocument?

  // MARK: - Initialization

  init(
    cardType: CardType = .search,
    typeId: Int = 0,
    searchQuery: String = "",
    searchResults: SearchResponse? = nil,
    suttaReference: String = "",
    mlDoc: MLDocument? = nil
  ) {
    createdAt = Date()
    self.cardType = cardType
    self.typeId = typeId
    self.searchQuery = searchQuery
    self.searchResults = searchResults
    self.suttaReference = suttaReference
    self.mlDoc = mlDoc
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case uuid
    case createdAt
    case cardType
    case typeId
    case searchQuery
    case searchResults
    case suttaReference
    case mlDoc
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(uuid, forKey: .uuid)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(cardType, forKey: .cardType)
    try container.encode(typeId, forKey: .typeId)
    try container.encode(searchQuery, forKey: .searchQuery)
    try container.encode(searchResults, forKey: .searchResults)
    try container.encode(suttaReference, forKey: .suttaReference)
    try container.encodeIfPresent(mlDoc, forKey: .mlDoc)
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try container.decode(UUID.self, forKey: .uuid)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    cardType = try container.decode(CardType.self, forKey: .cardType)
    typeId = try container.decode(Int.self, forKey: .typeId)
    searchQuery = try container.decode(String.self, forKey: .searchQuery)
    searchResults = try container.decodeIfPresent(
      SearchResponse.self,
      forKey: .searchResults
    )
    suttaReference = try container.decode(String.self, forKey: .suttaReference)
    mlDoc = try container.decodeIfPresent(MLDocument.self, forKey: .mlDoc)
  }

  // MARK: - Public Methods

  /// Returns the appropriate SF Symbol icon name for the card type
  func iconName() -> String {
    switch cardType {
    case .search:
      return "magnifyingglass"
    case .sutta:
      return "book"
    }
  }

  /// Returns the localized name for the card type
  @MainActor
  func localizedCardTypeName() -> String {
    switch cardType {
    case .search:
      return "card.type.search".localized
    case .sutta:
      return "card.type.sutta".localized
    }
  }

  /// Returns the display title for the card
  @MainActor
  func title() -> String {
    // Always return localized CardType + ID (don't store in name)
    return "\(localizedCardTypeName()) \(typeId)"
  }
}
