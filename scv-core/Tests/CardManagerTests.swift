import Foundation
@testable import scvCore
import SwiftData
import Testing

@Suite
struct CardManagerTests {
  // MARK: - Initialization Tests

  @Test
  @MainActor
  func cardManagerInitializesWithDefaultCard() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    #expect(manager.allCards.count == 1)
    #expect(manager.selectedCard != nil)
    #expect(manager.selectedCard?.cardType == .search)
  }

  @Test
  @MainActor
  func cardManagerSelectsFirstCardByDefault() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let firstCard = manager.allCards.first

    #expect(manager.selectedCard == firstCard)
    #expect(manager.selectedCardId == firstCard?.id)
  }

  // MARK: - Selection After Deletion Tests

  @Test
  @MainActor
  func deletingSelectedCardSelectsNextCard() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Add a second card
    let card1 = manager.allCards.first!
    let card2 = manager.addCard(type: .search)

    // Select first card and delete it
    manager.selectCard(card1)
    #expect(manager.selectedCard == card1)

    manager.removeCard(card1)

    // Should select the next card
    #expect(manager.selectedCard == card2)
    #expect(manager.selectedCard?.id == card2.id)
  }

  @Test
  @MainActor
  func deletingSelectedCardFromMiddleSelectsNext() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create three cards (reverse order: [card3, card2, card1])
    #expect(manager.allCards.count == 1)
    let card1 = manager.allCards.first! // Default card (oldest)
    let card2 = manager.addCard(type: .search)
    _ = manager.addCard(type: .sutta) // Newest

    // Select middle card and delete it
    manager.selectCard(card2)
    #expect(manager.selectedCard == card2)

    manager.removeCard(card2)

    // Should select card1 (next older card after deletion)
    #expect(manager.selectedCard == card1)
    #expect(manager.selectedCard?.id == card1.id)
  }

  @Test
  @MainActor
  func deletingSelectedCardFromEndSelectsLastRemaining() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create three cards
    #expect(manager.allCards.count == 1)
    let card2 = manager.addCard(type: .search)
    let card3 = manager.addCard(type: .sutta)

    // Select last card and delete it
    manager.selectCard(card3)
    #expect(manager.selectedCard == card3)

    manager.removeCard(card3)

    // Should select card2 (last remaining)
    #expect(manager.selectedCard == card2)
    #expect(manager.selectedCard?.id == card2.id)
  }

  @Test
  @MainActor
  func deletingLastRemainingCardKeepsSelectionNil() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let onlyCard = manager.allCards.first!

    manager.selectCard(onlyCard)
    #expect(manager.selectedCard == onlyCard)

    manager.removeCard(onlyCard)

    // After deleting the only card, selectedCard should be nil
    #expect(manager.selectedCard == nil)
    #expect(manager.allCards.isEmpty)
  }

  @Test
  @MainActor
  func deletingNonSelectedCardMaintainsSelection() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    let card1 = manager.allCards.first!
    let card2 = manager.addCard(type: .search)
    #expect(manager.allCards.count == 2)

    // Select card2
    manager.selectCard(card2)
    let selectedCardId = manager.selectedCard?.id

    // Delete card1 (not selected)
    manager.removeCard(card1)

    // Selection should remain card2
    #expect(manager.selectedCard?.id == selectedCardId)
    #expect(manager.selectedCard == card2)
  }

  // MARK: - Card Lookup Tests

  @Test
  @MainActor
  func cardFromIdReturnsExistingCard() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let card1 = manager.allCards.first!
    let card2 = manager.addCard(type: .search)

    let foundCard1 = manager.cardFromId(card1.id)
    let foundCard2 = manager.cardFromId(card2.id)

    #expect(foundCard1 == card1)
    #expect(foundCard2 == card2)
  }

  @Test
  @MainActor
  func cardFromIdReturnsNilForNonexistentId() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let card1 = manager.allCards.first!

    // Delete the card
    manager.removeCard(card1)

    // Try to find the deleted card by ID
    let foundCard = manager.cardFromId(card1.id)

    #expect(foundCard == nil)
  }

  // MARK: - Count and State Tests

  @Test
  @MainActor
  func totalCountDecrementsAfterDeletion() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let initialCard = manager.allCards.first!
    let newCard = manager.addCard(type: .search)

    #expect(manager.totalCount == 2)

    manager.removeCard(initialCard)

    #expect(manager.totalCount == 1)
    #expect(manager.selectedCard == newCard)
  }

  @Test
  @MainActor
  func countByCardTypeUpdatesAfterDeletion() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    let searchCard1 = manager.allCards.first!
    manager.addCard(type: .search)
    manager.addCard(type: .sutta)

    #expect(manager.count(for: .search) == 2)
    #expect(manager.count(for: .sutta) == 1)

    manager.removeCard(searchCard1)

    #expect(manager.count(for: .search) == 1)
    #expect(manager.count(for: .sutta) == 1)
  }

  // MARK: - Index-based Deletion Tests

  @Test
  @MainActor
  func removeCardsAtIndices() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    #expect(manager.allCards.count == 1)
    _ = manager.allCards.first! // Default card (oldest)
    let card2 = manager.addCard(type: .search)
    _ = manager.addCard(type: .sutta) // Newest

    // Reverse order: [card3, card2, card1] at indices [0, 1, 2]
    manager.selectCard(card2) // Select middle card
    let initialCount = manager.totalCount

    // Remove cards at indices 0 and 2 (card3 and card1)
    manager.removeCards(at: IndexSet([0, 2]))

    #expect(manager.totalCount == initialCount - 2)
    #expect(manager.selectedCard == card2) // card2 not deleted, still selected
  }

  @Test
  @MainActor
  func removeCardsAtIndicesWithSelectedCardDeletion() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    let card1 = manager.allCards.last! // Oldest card (last in reverse order)
    let card2 = manager.addCard(type: .search)
    _ = manager.addCard(type: .sutta) // Newest card

    manager.selectCard(card1)

    // With reverse order: allCards = [card3, card2, card1]
    // Remove card at index 2 (which is the selected card1, oldest)
    manager.removeCards(at: IndexSet([2]))

    // Should select card2 (new last item, since no older card exists)
    #expect(manager.selectedCard == card2)
    #expect(manager.totalCount == 2)
  }

  // MARK: - Concurrent Deletion Tests

  @Test
  @MainActor
  func concurrentDeletionRapidSequentialDeletes() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create 5 cards
    let card1 = manager.allCards.first!
    _ = manager.addCard(type: .search)
    let card3 = manager.addCard(type: .search)
    _ = manager.addCard(type: .sutta)
    let card5 = manager.addCard(type: .sutta)

    manager.selectCard(card1)

    // Delete cards in rapid sequence
    manager.removeCard(card1)
    manager.removeCard(card3)
    manager.removeCard(card5)

    // Should always have at least one card
    #expect(manager.totalCount >= 1)
    #expect(manager.totalCount == 2)
    // Selection should be valid and exist in remaining cards
    #expect(manager.selectedCard != nil)
    #expect(manager.allCards.contains { $0.id == manager.selectedCard?.id })
  }

  @Test
  @MainActor
  func concurrentDeletionNonContiguousCards() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create 5 cards
    let card1 = manager.allCards.first!
    _ = manager.addCard(type: .search)
    let card3 = manager.addCard(type: .search)
    _ = manager.addCard(type: .sutta)
    let card5 = manager.addCard(type: .sutta)

    manager.selectCard(card3)

    // Delete non-contiguous cards while card3 is selected
    manager.removeCard(card1)
    manager.removeCard(card5)

    // Should always have at least one card
    #expect(manager.totalCount >= 1)
    // card3 should still be selected
    #expect(manager.selectedCard == card3)
    #expect(manager.totalCount == 3)
  }

  @Test
  @MainActor
  func concurrentDeletionWithSelectionReplacement() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create 4 cards (reverse chronological: [card4, card3, card2, card1])
    let card1 = manager.allCards.first! // Default card (oldest)
    let card2 = manager.addCard(type: .search)
    let card3 = manager.addCard(type: .search)
    let card4 = manager.addCard(type: .sutta) // Newest

    manager.selectCard(card2)

    // Delete card2 - should select next older card (card1)
    manager.removeCard(card2)
    #expect(manager.selectedCard == card1)
    #expect(manager.totalCount >= 1)

    // Delete card1 - should select next newer (card3, since no older exists)
    manager.removeCard(card1)
    #expect(manager.selectedCard == card3)
    #expect(manager.totalCount >= 1)

    // Delete card3 - should select card4 (remaining, newest)
    manager.removeCard(card3)
    #expect(manager.selectedCard == card4)
    #expect(manager.totalCount == 1)
  }

  @Test
  @MainActor
  func concurrentDeletionMultipleIndicesIncludingSelected() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create 6 cards (reverse: [card6, card5, card4, card3, card2, card1])
    _ = manager.allCards.first! // Oldest
    _ = manager.addCard(type: .search)
    let card3 = manager.addCard(type: .search)
    _ = manager.addCard(type: .sutta)
    _ = manager.addCard(type: .sutta)
    _ = manager.addCard(type: .sutta) // card6, newest

    manager.selectCard(card3)

    // With reverse order: indices are [6,5,4,3,2,1] → [0,1,2,3,4,5]
    // Delete indices 0, 2, 4 (card6, card4, card2)
    manager.removeCards(at: IndexSet([0, 2, 4]))

    // Should always have at least one card
    #expect(manager.totalCount >= 1)
    // Should have 3 cards remaining (card5, card3, card1)
    #expect(manager.totalCount == 3)
    // card3 was selected and not deleted, should still be selected
    #expect(manager.selectedCard == card3)
  }

  @Test
  @MainActor
  func concurrentDeletionCountByTypeRemainsAccurate() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create 3 search and 3 sutta cards
    let searchCard1 = manager.allCards.first!
    _ = manager.addCard(type: .search)
    let searchCard3 = manager.addCard(type: .search)
    let suttaCard1 = manager.addCard(type: .sutta)
    _ = manager.addCard(type: .sutta)
    _ = manager.addCard(type: .sutta)

    #expect(manager.count(for: .search) == 3)
    #expect(manager.count(for: .sutta) == 3)

    // Delete alternating cards
    manager.removeCard(searchCard1)
    manager.removeCard(suttaCard1)
    manager.removeCard(searchCard3)

    // Should always have at least one card
    #expect(manager.totalCount >= 1)
    // Should have 1 search and 2 sutta remaining
    #expect(manager.count(for: .search) == 1)
    #expect(manager.count(for: .sutta) == 2)
    #expect(manager.totalCount == 3)
  }

  // MARK: - Rapid Addition Tests

  @Test
  @MainActor
  func rapidAdditionsMaintainSelectedInvariant() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Start with one card, then rapidly add up to 10 cards
    for _ in 0 ..< 9 {
      manager.addCard(type: .search)

      // After each add, validate invariant
      #expect(manager.selectedCard != nil)
      #expect(manager.allCards.contains { $0.id == manager.selectedCard?.id })
    }

    #expect(manager.totalCount == 10)
  }

  // MARK: - Rapid Removal Tests

  @Test
  @MainActor
  func rapidRemovalsMaintainSelectedInvariant() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create 10 cards
    for _ in 0 ..< 9 {
      manager.addCard(type: .search)
    }
    #expect(manager.totalCount == 10)

    // Rapidly remove cards until one remains
    while manager.allCards.count > 1 {
      let cardToRemove = manager.allCards.first!
      manager.removeCard(cardToRemove)

      // After each removal, validate invariant
      #expect(manager.selectedCard != nil)
      #expect(manager.allCards.contains { $0.id == manager.selectedCard?.id })
    }

    #expect(manager.totalCount == 1)
    #expect(manager.selectedCard != nil)
  }

  // MARK: - Mixed Operations Tests

  @Test
  @MainActor
  func mixedRapidAddRemoveOperationsMaintainInvariant() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Mix of rapid adds and removes
    // Add 5 cards
    for _ in 0 ..< 5 {
      manager.addCard(type: .search)
      #expect(manager.selectedCard != nil)
      #expect(manager.allCards.contains { $0.id == manager.selectedCard?.id })
    }
    #expect(manager.totalCount == 6) // 1 initial + 5 added

    // Remove 2 cards
    manager.removeCard(manager.allCards[0])
    #expect(manager.selectedCard != nil)
    #expect(manager.allCards.contains { $0.id == manager.selectedCard?.id })

    manager.removeCard(manager.allCards[0])
    #expect(manager.selectedCard != nil)
    #expect(manager.allCards.contains { $0.id == manager.selectedCard?.id })

    #expect(manager.totalCount == 4)

    // Add 3 more cards
    for _ in 0 ..< 3 {
      manager.addCard(type: .sutta)
      #expect(manager.selectedCard != nil)
      #expect(manager.allCards.contains { $0.id == manager.selectedCard?.id })
    }
    #expect(manager.totalCount == 7)

    // Remove 5 cards
    for _ in 0 ..< 5 {
      manager.removeCard(manager.allCards[0])
      #expect(manager.selectedCard != nil)
      #expect(manager.allCards.contains { $0.id == manager.selectedCard?.id })
    }

    #expect(manager.totalCount == 2)
  }

  // MARK: - Binding Tests

  @Test
  @MainActor
  func bindCardReturnsBindingForExistingCard() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let card = manager.allCards.first!

    let binding = manager.bindCard(id: card.id)

    #expect(binding != nil)
    #expect(binding?.wrappedValue.id == card.id)
  }

  @Test
  @MainActor
  func bindCardReturnsNilForNonexistentCard() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let card = manager.allCards.first!
    manager.removeCard(card)

    let binding = manager.bindCard(id: card.id)

    #expect(binding == nil)
  }

  @Test
  @MainActor
  func bindCardGetterReturnsCurrentCardState() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let card = manager.allCards.first!
    let binding = manager.bindCard(id: card.id)!

    #expect(binding.wrappedValue.searchQuery == "")

    // Modify card directly
    card.searchQuery = "test query"

    // Binding getter should reflect change
    #expect(binding.wrappedValue.searchQuery == "test query")
  }

  @Test
  @MainActor
  func bindCardSetterUpdatesCard() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let card = manager.allCards.first!
    let binding = manager.bindCard(id: card.id)!

    // Modify via binding
    binding.wrappedValue.searchQuery = "modified"

    // Verify change persists
    #expect(card.searchQuery == "modified")
    #expect(manager.cardFromId(card.id)?.searchQuery == "modified")
  }

  @Test
  @MainActor
  func bindCardUpdatesReflectedInAllCards() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let card = manager.allCards.first!
    let binding = manager.bindCard(id: card.id)!

    binding.wrappedValue.searchQuery = "updated query"

    let updatedCard = manager.allCards.first { $0.id == card.id }
    #expect(updatedCard?.searchQuery == "updated query")
  }

  @Test
  @MainActor
  func cardFromIdReturnsConsistentReference() throws {
    // BUG: cardFromId() calls allCards.fetch() which creates NEW instances
    // This test exposes that different calls to cardFromId() return different
    // objects
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let cardId = manager.allCards.first!.id

    // Get first reference
    let card1 = manager.cardFromId(cardId)!
    card1.searchQuery = "test query"

    // Get second reference - should be SAME object, not a fresh copy
    let card2 = manager.cardFromId(cardId)!

    // This test FAILS because card2 is a different instance with empty
    // searchQuery
    // CardManager is NOT the source of truth - SwiftData fetch creates new
    // instances
    #expect(card2.searchQuery == "test query")
    #expect(card1 === card2) // Same object identity
  }

  // MARK: - SuttaRef Card Tests

  @Test
  @MainActor
  func suttaCardForRefCreatesNewCardWhenNotFound() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let initialCount = manager.totalCount

    let suttaRef = SuttaRef.create("mn1/en/sujato")!
    let card = await manager.suttaCardForRef(suttaRef)

    #expect(manager.totalCount == initialCount + 1)
    #expect(card.cardType == .sutta)
    #expect(card.suttaReference == suttaRef.toString())
    #expect(card.mlDoc != nil)
  }

  @Test
  @MainActor
  func suttaCardForRefReusesExistingCard() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let suttaRef = SuttaRef.create("mn1/en/sujato")!

    // Create first card
    let card1 = await manager.suttaCardForRef(suttaRef)
    let countAfterFirst = manager.totalCount

    // Request same suttaRef again
    let card2 = await manager.suttaCardForRef(suttaRef)

    #expect(manager.totalCount == countAfterFirst)
    #expect(card1.id == card2.id)
    #expect(card1 === card2)
  }
}
