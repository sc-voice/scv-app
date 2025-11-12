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
    let card2 = manager.addCard(cardType: .search)

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

    // Create three cards
    #expect(manager.allCards.count == 1)
    let card2 = manager.addCard(cardType: .search)
    let card3 = manager.addCard(cardType: .sutta)

    // Select middle card and delete it
    manager.selectCard(card2)
    #expect(manager.selectedCard == card2)

    manager.removeCard(card2)

    // Should select card3 (next card after deletion)
    #expect(manager.selectedCard == card3)
    #expect(manager.selectedCard?.id == card3.id)
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
    let card2 = manager.addCard(cardType: .search)
    let card3 = manager.addCard(cardType: .sutta)

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
    let card2 = manager.addCard(cardType: .search)
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

  // MARK: - Count and State Tests

  @Test
  @MainActor
  func totalCountDecrementsAfterDeletion() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)
    let initialCard = manager.allCards.first!
    let newCard = manager.addCard(cardType: .search)

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
    manager.addCard(cardType: .search)
    manager.addCard(cardType: .sutta)

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
    manager.addCard(cardType: .search)
    let card3 = manager.addCard(cardType: .sutta)

    manager.selectCard(card3)
    let initialCount = manager.totalCount

    // Remove cards at indices 0 and 1
    manager.removeCards(at: IndexSet([0, 1]))

    #expect(manager.totalCount == initialCount - 2)
    #expect(manager.selectedCard == card3)
  }

  @Test
  @MainActor
  func removeCardsAtIndicesWithSelectedCardDeletion() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    let card1 = manager.allCards.first!
    let card2 = manager.addCard(cardType: .search)
    manager.addCard(cardType: .sutta)

    manager.selectCard(card1)

    // Remove card at index 0 (which is the selected card1)
    manager.removeCards(at: IndexSet([0]))

    // Should select card2 (next card)
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
    _ = manager.addCard(cardType: .search)
    let card3 = manager.addCard(cardType: .search)
    _ = manager.addCard(cardType: .sutta)
    let card5 = manager.addCard(cardType: .sutta)

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
    _ = manager.addCard(cardType: .search)
    let card3 = manager.addCard(cardType: .search)
    _ = manager.addCard(cardType: .sutta)
    let card5 = manager.addCard(cardType: .sutta)

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

    // Create 4 cards
    let card1 = manager.allCards.first!
    let card2 = manager.addCard(cardType: .search)
    let card3 = manager.addCard(cardType: .search)
    let card4 = manager.addCard(cardType: .sutta)

    manager.selectCard(card2)

    // Delete selected card - should select next (card3)
    manager.removeCard(card2)
    #expect(manager.selectedCard == card3)
    #expect(manager.totalCount >= 1)

    // Delete the new selection - should select next (card4)
    manager.removeCard(card3)
    #expect(manager.selectedCard == card4)
    #expect(manager.totalCount >= 1)

    // Delete card4 - should select card1 (remaining)
    manager.removeCard(card4)
    #expect(manager.selectedCard == card1)
    #expect(manager.totalCount == 1)
  }

  @Test
  @MainActor
  func concurrentDeletionMultipleIndicesIncludingSelected() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Card.self, configurations: config)
    let context = ModelContext(container)

    let manager = CardManager(modelContext: context)

    // Create 6 cards
    _ = manager.allCards.first!
    _ = manager.addCard(cardType: .search)
    let card3 = manager.addCard(cardType: .search)
    let card4 = manager.addCard(cardType: .sutta)
    _ = manager.addCard(cardType: .sutta)
    _ = manager.addCard(cardType: .sutta)

    manager.selectCard(card3)

    // Delete indices 0, 2, 5 (cards 1, 3, 6) - card3 is at index 2
    manager.removeCards(at: IndexSet([0, 2, 5]))

    // Should always have at least one card
    #expect(manager.totalCount >= 1)
    // Should have 3 cards remaining (cards 2, 4, 5)
    #expect(manager.totalCount == 3)
    // Selection should have moved from card3
    #expect(manager.selectedCard == card4)
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
    _ = manager.addCard(cardType: .search)
    let searchCard3 = manager.addCard(cardType: .search)
    let suttaCard1 = manager.addCard(cardType: .sutta)
    _ = manager.addCard(cardType: .sutta)
    _ = manager.addCard(cardType: .sutta)

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
      manager.addCard(cardType: .search)

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
      manager.addCard(cardType: .search)
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
      manager.addCard(cardType: .search)
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
      manager.addCard(cardType: .sutta)
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
}
