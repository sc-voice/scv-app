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
  var recentCardId: ManagedCard.ID? { get set }

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
  public var recentCardId: Card.ID?

  // MARK: - Initialization

  public init(modelContext: ModelContext) {
    self.modelContext = modelContext

    // Clean up detached cards from previous sessions
    deleteDetachedCards()

    // Ensure at least one card exists
    if allCards.isEmpty {
      addCard(type: .about)
    }

    // Ensure a card is always selected
    if selectedCardId == nil {
      let first = allCards.first
      selectedCardId = first?.id
      recentCardId = first?.id
      cc.ok1(#line, #function, "selectedCard:", first?.name ?? "nil")
    }
  }

  // MARK: - Public Properties

  /// Returns all cards sorted by createdAt in descending order (latest first)
  /// Excludes detached cards to prevent SwiftData fault crashes
  public var allCards: [Card] {
    let fetchDescriptor = FetchDescriptor<Card>(sortBy: [
      SortDescriptor(\.createdAt, order: .reverse),
    ])
    do {
      return try modelContext.fetch(fetchDescriptor).filter { !$0.isDetached }
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
      cc.ok2(#line, #function, card.name)
    } catch {
      cc.bad1(#line, #function, error.localizedDescription)
      return nil
    }

    return Binding(
      get: {
        // If card was deleted after binding was created, deserialize from JSON
        // to get a fresh Card object. The view will be torn down when
        // selectedCardId updates.
        if let foundCard = self.cardFromId(id), !foundCard.isDetached {
          return foundCard
        } else {
          if let jsonData = ghostCardJSON,
             let data = jsonData.data(using: .utf8)
          {
            do {
              let decoder = JSONDecoder()
              let ghostCard = try decoder.decode(Card.self, from: data)
              self.cc.ok1(#line, #function, "ghost:", ghostCard.name)
              return ghostCard
            } catch {
              self.cc.bad1(#line, #function, error.localizedDescription)
              // Return a minimal placeholder card to avoid crashing
              return Card(cardType: .about)
            }
          } else {
            self.cc.bad1(#line, #function, "ghostCardJson?")
            return Card(cardType: .about)
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
             let data = jsonData.data(using: .utf8)
          {
            do {
              let decoder = JSONDecoder()
              let ghostCard = try decoder.decode(Card.self, from: data)
              ghostCardName = ghostCard.name
              self.cc.ok1(#line, #function, "existingCard?", ghostCardName)
            } catch {
              self.cc.ok1(#line, #function, "existingCard?", ghostCardName)
            }
          } else {
            self.cc.ok1(#line, #function, "existingCard?", ghostCardName)
          }
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
      cc.ok1(#line, #function, newCard.name)
    } catch {
      cc.bad1(#line, #function, error)
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
      cc.ok1(#line, #function, "existingCard:", existingCard.name, refString)
      return existingCard
    }

    // Not found - create new sutta card
    let newCard = addCard(type: .sutta)
    newCard.suttaReference = refString
    if let searchQuery {
      newCard.searchQuery = searchQuery
    }
    cc.ok2(#line, #function, "getMLDocument...")
    newCard.mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)

    // Save the updated card properties
    do {
      try modelContext.save()
      cc.ok1(#line, #function, refString)
    } catch {
      cc.bad1(#line, #function, error)
    }

    return newCard
  }

  /// Selects a card (ensures a card is always selected)
  public func selectCard(_ card: Card) {
    selectedCardId = card.id
    recentCardId = card.id
    cc.ok1(#line, #function, "selectedCard:", card.name)
  }

  /// Selects a card by ID, or clears selection if nil
  public func selectCardId(_ id: Card.ID?) {
    if let id, let card = cardFromId(id) {
      selectedCardId = card.id
      recentCardId = card.id
      cc.ok1(#line, #function, "selectedCard:", card.name)
    } else {
      selectedCardId = nil
      cc.ok1(#line, #function, "selectedCard:", id ?? "nil")
    }
  }

  /// Removes a card and updates selection if necessary
  func removeCard(_ card: Card) {
    // Mark card as detached before deletion to prevent SwiftData fault crashes
    // when views try to access the card during teardown
    card.isDetached = true

    // If the deleted card was selected, find the next card to select
    if selectedCardId == card.id {
      let remainingCards = allCards.filter { $0.id != card.id }

      // Find the next card to select
      if let nextCard = findNextCard(after: card, in: remainingCards) {
        selectedCardId = nextCard.id
        recentCardId = nextCard.id
        cc.ok2(#line, #function, "selectedCard:", nextCard.name)
      }
    }

    if totalCount < 1 {
      // No remaining cards, create an about card to maintain invariant
      cc.ok2(#line, #function, "No cards")
      let aboutCard = addCard(type: .about)
      selectedCardId = aboutCard.id
      recentCardId = aboutCard.id
      cc.ok2(#line, #function, "selectedCard:", aboutCard.name)
    }

    // Cards are deleted at launch to prevent SwiftUI race conditions
    // The following line caused many crashes.
    // modelContext.delete(card)

    do {
      try modelContext.save()
      cc.ok1(#line, #function, card.name)
    } catch {
      cc.bad1(#line, #function, error)
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

  /// Deletes detached cards from previous sessions
  /// Called at app launch to clean up orphaned cards
  private func deleteDetachedCards() {
    let fetchDescriptor = FetchDescriptor<Card>()
    do {
      let allStoredCards = try modelContext.fetch(fetchDescriptor)
      let detachedCards = allStoredCards.filter(\.isDetached)
      for card in detachedCards {
        cc.ok2(#line, #function, card.name)
        modelContext.delete(card)
      }
      if !detachedCards.isEmpty {
        try modelContext.save()
      }
    } catch {
      cc.bad1(#line, #function, error)
    }
  }
}
