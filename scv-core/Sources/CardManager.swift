//
//  CardManager.swift
//  scv-apple
//
//  Created by Visakha on 31/10/2025.
//

import Foundation
import SwiftData

// MARK: - ICardManager Protocol

/// Card manager interface - defines contract for managing cards
public protocol ICardManager: Observable {
  associatedtype ManagedCard: ICard

  var allCards: [ManagedCard] { get }
  var selectedCardId: ManagedCard.ID? { get set }

  func selectCard(_ card: ManagedCard)
  func removeCards(at indices: IndexSet)
  @discardableResult
  func addCard(type: scvCore.CardType) -> ManagedCard
}

// MARK: - CardManager

/// Instance-based manager for Card instances with ModelContext integration
@Observable
public class CardManager: ICardManager {
  public typealias ManagedCard = Card
  let cc = ColorConsole(#file, #function)

  // MARK: - Properties

  private let modelContext: ModelContext
  public var selectedCardId: Card.ID?

  // MARK: - Initialization

  public init(modelContext: ModelContext) {
    self.modelContext = modelContext

    // Ensure at least one card exists
    if allCards.isEmpty {
      addCard(type: .search)
    }

    // Ensure a card is always selected
    if selectedCardId == nil {
      selectedCardId = allCards.first?.id
    }
  }

  // MARK: - Public Properties

  /// Returns all cards sorted by createdAt in ascending order
  public var allCards: [Card] {
    let fetchDescriptor = FetchDescriptor<Card>(sortBy: [
      SortDescriptor(\.createdAt, order: .forward),
    ])
    do {
      return try modelContext.fetch(fetchDescriptor)
    } catch {
      cc.bad1(#line, "Failed to fetch cards: \(error)")
      return []
    }
  }

  /// Returns total count of all cards
  var totalCount: Int {
    allCards.count
  }

  /// Returns the currently selected card
  var selectedCard: Card? {
    guard let selectedCardId else { return nil }
    return allCards.first { $0.id == selectedCardId }
  }

  // MARK: - Public Methods

  /// Returns count for a specific card type
  func count(for cardType: CardType) -> Int {
    allCards.count(where: { $0.cardType == cardType })
  }

  /// Returns the largest ID for a specific card type, or 0 if no cards exist
  func largestId(for cardType: CardType) -> Int {
    let cardsOfType = allCards.filter { $0.cardType == cardType }
    return cardsOfType.map(\.typeId).max() ?? 0
  }

  /// Adds a new card and returns the card with the assigned ID
  @discardableResult
  public func addCard(type cardType: CardType = .search) -> Card {
    // Create a new card with the correct ID
    let newCard = Card(
      cardType: cardType,
      typeId: largestId(for: cardType) + 1,
    )

    modelContext.insert(newCard)

    do {
      try modelContext.save()
    } catch {
      cc.bad1(#line, "Failed to save card: \(error)")
    }

    return newCard
  }

  /// Selects a card (ensures a card is always selected)
  public func selectCard(_ card: Card) {
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
      cc.bad1(#line, "Failed to delete card: \(error)")
    }
  }

  /// Finds the next card to select after deleting a card
  private func findNextCard(after deletedCard: Card,
                            in remainingCards: [Card]) -> Card?
  {
    guard !remainingCards.isEmpty else { return nil }

    // Sort cards by creation date
    let sortedCards = remainingCards.sorted { $0.createdAt < $1.createdAt }

    // Find the card created after the deleted card
    if let nextIndex = sortedCards
      .firstIndex(where: { $0.createdAt > deletedCard.createdAt })
    {
      return sortedCards[nextIndex]
    }

    // If no card was created after, select the last card
    return sortedCards.last
  }

  /// Removes cards at specified indices
  public func removeCards(at indices: IndexSet) {
    let cards = allCards
    for index in indices {
      if index < cards.count {
        let card = cards[index]
        removeCard(card)
      }
    }
  }
}
