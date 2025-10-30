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
  case search = "search"
  case sutta = "sutta"
}

// MARK: - Card Model

@Model
final class Card {
  // MARK: - Properties

  private(set) var createdAt: Date
  private(set) var cardType: CardType
  var name: String {
    return "\(localizedCardTypeName()) \(typeId)"
  }
  private(set) var typeId: Int
  
  // Search card properties
  var searchQuery: String = ""
  var searchResults: SearchResponse?
  
  // Sutta card properties
  var suttaReference: String = ""

  // MARK: - Initialization

  init(
    cardType: CardType = .search,
    typeId: Int = 0,
    searchQuery: String = "",
    searchResults: SearchResponse? = nil,
    suttaReference: String = ""
  ) {
    self.createdAt = Date()
    self.cardType = cardType
    self.typeId = typeId
    self.searchQuery = searchQuery
    self.searchResults = searchResults
    self.suttaReference = suttaReference
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
  func localizedCardTypeName() -> String {
    switch cardType {
    case .search:
      return "card.type.search".localized
    case .sutta:
      return "card.type.sutta".localized
    }
  }

  /// Returns the display title for the card
  func title() -> String {
    // Always return localized CardType + ID (don't store in name)
    return "\(localizedCardTypeName()) \(typeId)"
  }

}

// MARK: - CardManager

/// Instance-based manager for Card instances with ModelContext integration
@Observable
class CardManager {
  // MARK: - Properties

  private let modelContext: ModelContext
  var selectedCardId: Card.ID?

  // MARK: - Initialization

  init(modelContext: ModelContext) {
    self.modelContext = modelContext

    // Ensure at least one card exists
    if allCards.isEmpty {
      addCard(cardType: .search)
    }

    // Ensure a card is always selected
    if selectedCardId == nil {
      selectedCardId = allCards.first?.id
    }
  }

  // MARK: - Public Properties

  /// Returns all cards sorted by createdAt in ascending order
  var allCards: [Card] {
    let fetchDescriptor = FetchDescriptor<Card>(sortBy: [
      SortDescriptor(\.createdAt, order: .forward)
    ])
    do {
      return try modelContext.fetch(fetchDescriptor)
    } catch {
      print("Failed to fetch cards: \(error)")
      return []
    }
  }

  /// Returns total count of all cards
  var totalCount: Int {
    return allCards.count
  }

  /// Returns the currently selected card
  var selectedCard: Card? {
    guard let selectedCardId = selectedCardId else { return nil }
    return allCards.first { $0.id == selectedCardId }
  }

  // MARK: - Public Methods

  /// Returns count for a specific card type
  func count(for cardType: CardType) -> Int {
    return allCards.filter { $0.cardType == cardType }.count
  }

  /// Returns the largest ID for a specific card type, or 0 if no cards exist
  func largestId(for cardType: CardType) -> Int {
    let cardsOfType = allCards.filter { $0.cardType == cardType }
    return cardsOfType.map { $0.typeId }.max() ?? 0
  }

  /// Adds a new card and returns the card with the assigned ID
  @discardableResult
  func addCard(cardType: CardType = .search) -> Card {
    // Create a new card with the correct ID
    let newCard = Card(
      cardType: cardType,
      typeId: largestId(for: cardType) + 1
    )

    modelContext.insert(newCard)

    do {
      try modelContext.save()
    } catch {
      print("Failed to save card: \(error)")
    }

    return newCard
  }

  /// Selects a card (ensures a card is always selected)
  func selectCard(_ card: Card) {
    selectedCardId = card.id
  }

  /// Removes a card and updates selection if necessary
  func removeCard(_ card: Card) {
    // If the deleted card was selected, find the next card to select
    if selectedCardId == card.id {
      let remainingCards = allCards.filter { $0.id != card.id }

      // Find the next card to select
      if let nextCard = findNextCard(after: card, in: remainingCards) {
        selectedCardId = nextCard.id
      }
    }

    modelContext.delete(card)

    do {
      try modelContext.save()
    } catch {
      print("Failed to delete card: \(error)")
    }
  }

  /// Finds the next card to select after deleting a card
  private func findNextCard(after deletedCard: Card, in remainingCards: [Card]) -> Card? {
    guard !remainingCards.isEmpty else { return nil }

    // Sort cards by creation date
    let sortedCards = remainingCards.sorted { $0.createdAt < $1.createdAt }

    // Find the card created after the deleted card
    if let nextIndex = sortedCards.firstIndex(where: { $0.createdAt > deletedCard.createdAt }) {
      return sortedCards[nextIndex]
    }

    // If no card was created after, select the last card
    return sortedCards.last
  }

  /// Removes cards at specified indices
  func removeCards(at indices: IndexSet) {
    let cards = allCards
    for index in indices {
      if index < cards.count {
        let card = cards[index]
        removeCard(card)
      }
    }
  }
}

// MARK: - String Extension

extension String {
  var localized: String {
    NSLocalizedString(self, bundle: .module, comment: "")
  }
}
