//
//  CardManager.swift
//  scv-apple
//
//  Created by Visakha on 31/10/2025.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - ICardManager Protocol

/// Card manager interface - defines contract for managing cards
@MainActor
public protocol ICardManager: Observable {
  associatedtype ManagedCard: ICard

  var allCards: [ManagedCard] { get }
  var selectedCardId: ManagedCard.ID? { get set }

  func selectCard(_ card: ManagedCard)
  func selectCardId(_ id: ManagedCard.ID?)
  func removeCards(at indices: IndexSet)
  func cardFromId(_ id: ManagedCard.ID) -> ManagedCard?
  func bindCard(id: ManagedCard.ID) -> Binding<ManagedCard>?
  @discardableResult
  func addCard(type: scvCore.CardType) -> ManagedCard
  func saveCard(_ card: ManagedCard)
  func suttaCardForRef(_ suttaRef: SuttaRef, searchQuery: String?) async
    -> ManagedCard
  func suttaCardForRef(_ suttaRef: SuttaRef) async -> ManagedCard
}

// MARK: - ICardManager Default Implementation

public extension ICardManager {
  func suttaCardForRef(_ suttaRef: SuttaRef) async -> ManagedCard {
    await suttaCardForRef(suttaRef, searchQuery: nil)
  }
}

// MARK: - CardManager

/// Instance-based manager for Card instances with ModelContext integration
@Observable
public class CardManager: ICardManager {
  public typealias ManagedCard = Card
  let cc = ColorConsole(#file, #function, dbg.CardManager.other)

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

  /// Returns all cards sorted by createdAt in descending order (latest first)
  public var allCards: [Card] {
    let fetchDescriptor = FetchDescriptor<Card>(sortBy: [
      SortDescriptor(\.createdAt, order: .reverse),
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

  /// Returns a card by its PersistentIdentifier, or nil if not found
  public func cardFromId(_ id: Card.ID) -> Card? {
    allCards.first { $0.id == id }
  }

  /// Returns a binding to a card by its ID, or nil if not found
  public func bindCard(id: Card.ID) -> Binding<Card>? {
    guard let card = cardFromId(id) else {
      cc.bad1(#line, "bindCard: card not found for id:", id)
      return nil
    }

    // Serialize card to JSON so we can deserialize it later if card is deleted
    // This avoids holding references to detached SwiftData objects
    var ghostCardJSON: String?
    do {
      let encoder = JSONEncoder()
      let data = try encoder.encode(card)
      ghostCardJSON = String(data: data, encoding: .utf8)
      cc.ok2(#line, "bindCard: created binding for card:", card.name)
    } catch {
      cc.bad1(#line, "bindCard: failed to serialize card:", error.localizedDescription)
      return nil
    }

    return Binding(
      get: {
        // If card was deleted after binding was created, deserialize from JSON
        // to get a fresh Card object. The view will be torn down when selectedCardId updates.
        if let foundCard = self.cardFromId(id) {
          return foundCard
        } else {
          if let jsonData = ghostCardJSON,
             let data = jsonData.data(using: .utf8) {
            do {
              let decoder = JSONDecoder()
              let ghostCard = try decoder.decode(Card.self, from: data)
              self.cc.ok1(#line, "bindCard.get: card was deleted, returning happy ghost:", ghostCard.name)
              return ghostCard
            } catch {
              self.cc.bad1(#line, "bindCard.get: failed to deserialize ghost card:", error.localizedDescription)
              // Return a minimal placeholder card to avoid crashing
              return Card(cardType: .help, typeId: 0)
            }
          } else {
            self.cc.bad1(#line, "bindCard.get: ghost JSON missing, returning placeholder")
            return Card(cardType: .help, typeId: 0)
          }
        }
      },
      set: { newCard in
        // Update the card's mutable properties
        // This allows nested bindings like cardBinding.searchQuery to work
        // correctly
        if let existingCard = self.cardFromId(id) {
          existingCard.searchQuery = newCard.searchQuery
          existingCard.suttaReference = newCard.suttaReference
          existingCard.mlDoc = newCard.mlDoc
          existingCard.searchResults = newCard.searchResults
        } else {
          // Extract card name from ghost JSON for logging
          var ghostCardName = "unknown"
          if let jsonData = ghostCardJSON,
             let data = jsonData.data(using: .utf8) {
            do {
              let decoder = JSONDecoder()
              let ghostCard = try decoder.decode(Card.self, from: data)
              ghostCardName = ghostCard.name
            } catch {
              // Silent catch - just use "unknown"
            }
          }
          self.cc.ok1(#line, "bindCard.set: card was deleted, ghost save denied:", ghostCardName)
        }
      },
    )
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

  /// Returns existing sutta card for given SuttaRef, or creates a new one
  public func suttaCardForRef(_ suttaRef: SuttaRef,
                              searchQuery: String?) async -> Card
  {
    let refString = suttaRef.toString()

    // Search for existing sutta card with this reference
    if let existingCard = allCards.first(where: {
      $0.cardType == .sutta && $0.suttaReference == refString
    }) {
      cc.ok1(#line, "Reusing existing sutta card for \(refString)")
      return existingCard
    }

    // Not found - create new sutta card
    let newCard = addCard(type: .sutta)
    newCard.suttaReference = refString
    if let searchQuery {
      newCard.searchQuery = searchQuery
    }
    newCard.mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)

    // Save the updated card properties
    do {
      try modelContext.save()
      cc.ok1(#line, "Created new sutta card for \(refString)")
    } catch {
      cc.bad1(#line, "Failed to save sutta card: \(error)")
    }

    return newCard
  }

  /// Selects a card (ensures a card is always selected)
  public func selectCard(_ card: Card) {
    selectedCardId = card.id
  }

  /// Selects a card by ID, or clears selection if nil
  public func selectCardId(_ id: Card.ID?) {
    if let id, let card = cardFromId(id) {
      selectedCardId = card.id
    } else {
      selectedCardId = nil
    }
  }

  /// Removes a card and updates selection if necessary
  func removeCard(_ card: Card) {
    // Force-resolve cardType attribute to avoid SwiftData fault crash
    // when SwiftUI tries to access deleted card during view update
    _ = card.cardType

    // If the deleted card was selected, find the next card to select
    if selectedCardId == card.id {
      let remainingCards = allCards.filter { $0.id != card.id }

      // Find the next card to select
      if let nextCard = findNextCard(after: card, in: remainingCards) {
        selectedCardId = nextCard.id
        cc.ok1(#line, "Selected next card after deletion:", nextCard.name)
      } else {
        // No remaining cards, create a help card to maintain invariant
        let helpCard = addCard(type: .help)
        selectedCardId = helpCard.id
        cc.ok1(#line, "No remaining cards, auto-created help card")
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
  /// With reverse chronological order, selects the next older card (or newer if
  /// none older)
  private func findNextCard(after deletedCard: Card,
                            in remainingCards: [Card]) -> Card?
  {
    guard !remainingCards.isEmpty else { return nil }

    // Sort cards by creation date (newest first, matching UI order)
    let sortedCards = remainingCards.sorted { $0.createdAt > $1.createdAt }

    // Find the first card older than the deleted card (appears next in list)
    if let nextIndex = sortedCards
      .firstIndex(where: { $0.createdAt < deletedCard.createdAt })
    {
      return sortedCards[nextIndex]
    }

    // If no older card exists, select the last card (next newest/new last item)
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

  /// Saves a card to persistent storage
  /// Future implementation may queue commands for atomic batching and debounced
  /// disk flushes
  /// Currently executes synchronously
  public func saveCard(_ card: Card) {
    serializeCard(card)
  }

  /// Private method that handles card serialization and disk persistence
  private func serializeCard(_ card: Card) {
    do {
      try modelContext.save()
      cc.ok1(#line, "Card saved:", card.name)
    } catch {
      cc.bad1(#line, "Failed to save card:", error.localizedDescription)
    }
  }
}
