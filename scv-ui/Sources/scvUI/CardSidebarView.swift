//
//  CardSidebarView.swift
//  scv-ui
//
//  Created by Claude on 2025-11-17.
//

import scvCore
import SwiftData
import SwiftUI

public struct CardSidebarView<Manager: ICardManager>: View {
  @Binding var selectedCardId: Manager.ManagedCard.ID?
  let cardManager: Manager
  let cc = ColorConsole(#file, #function, dbg.CardSidebarView.other)
  @EnvironmentObject var themeProvider: ThemeProvider
  let onSettingsTap: (() -> Void)?
  @State private var titleOpacity: Double = 1.0
  @State private var titleScale: Double = 1.0
  @State private var titleColor: Color?

  public init(
    cardManager: Manager,
    selectedCardId: Binding<Manager.ManagedCard.ID?>,
    onSettingsTap: (() -> Void)? = nil,
  ) {
    self.cardManager = cardManager
    _selectedCardId = selectedCardId
    self.onSettingsTap = onSettingsTap
  }

  public var body: some View {
    // NavigationStack {
    List(selection: $selectedCardId) {
      ForEach(cardManager.allCards) { card in
        HStack(spacing: 12) {
          Image(systemName: card.iconName())
            .foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 2) {
            #if DEBUG
              if selectedCardId == card.id {
                Text(card.name)
                  .font(.caption)
                  .foregroundStyle(themeProvider.theme.debugForeground)
              }
            #endif
            if !card.searchQuery.isEmpty {
              Text(card.searchQuery)
                .font(.headline)
                .lineLimit(1)
            } else {
              Text("card.search.placeholder".localized)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
        }
        .contentShape(Rectangle())
        .onTapGesture {
          selectedCardId = card.id
          cardManager.selectCard(card)
          cc.ok1(#line, "Selected card:", card.name)
        }
      }
      .onDelete { indices in
        cardManager.removeCards(at: indices)
        cc.ok1(#line, "Deleted card(s) at indices:", indices.debugDescription)
      }
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("scVoice")
          .font(.title2)
          .foregroundStyle(titleColor ?? themeProvider.theme.accentColor)
          .opacity(titleOpacity)
          .scaleEffect(titleScale)
      }
      #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: addNewCard) {
            Image(systemName: "plus")
              .font(.title2)
          }
          .help("Add new search card")
        }
        if let onSettingsTap {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
              withAnimation(.easeInOut(duration: 2.0)) {
                titleColor = themeProvider.theme.accentColor
              }
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 2.0)) {
                  titleColor = themeProvider.theme.secondaryTextColor
                }
              }
              onSettingsTap()
            }) {
              Image(systemName: "gearshape")
                .font(.title2)
            }
            .help("Settings")
          }
        }
      #else
        // macOS uses different toolbar placement strategy
        ToolbarItem(placement: .automatic) {
          Button(action: addNewCard) {
            Image(systemName: "magnifyingglass")
              .font(.title2)
          }
          .help("Add new search card")
        }
        if let onSettingsTap {
          ToolbarItem(placement: .automatic) {
            Button(action: {
              withAnimation(.easeInOut(duration: 2.0)) {
                titleColor = themeProvider.theme.accentColor
              }
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 2.0)) {
                  titleColor = themeProvider.theme.secondaryTextColor
                }
              }
              onSettingsTap()
            }) {
              Image(systemName: "gearshape")
                .font(.title2)
            }
            .help("Settings")
          }
        }
      #endif
    }
    // .toolbarBackground(themeProvider.theme.toolbarColor, for: .navigationBar)
    // .toolbarBackground(.visible, for: .navigationBar)
    .onAppear {
      if titleColor == nil {
        titleColor = themeProvider.theme.secondaryTextColor
      }
    }
    // }
  }

  private func addNewCard() {
    let newCard = cardManager.addCard(type: .search)
    cardManager.selectCard(newCard)
    cc.ok1(#line, "Added new card:", newCard.name)
  }
}

// MARK: - Mock for Preview

/// Simple mock card for preview
@Observable
public class MockCard: ICard {
  public let id: UUID
  public var cardType: CardType
  public var typeId: Int
  public var searchQuery: String

  public init(
    id: UUID = UUID(),
    cardType: CardType,
    typeId: Int,
    searchQuery: String = "",
  ) {
    self.id = id
    self.cardType = cardType
    self.typeId = typeId
    self.searchQuery = searchQuery
  }
}

/// Simple mock card manager for preview
@Observable
public class MockCardManager: ICardManager {
  public typealias ManagedCard = MockCard

  public var allCards: [MockCard]
  public var selectedCardId: UUID?

  public init(cards: [MockCard] = [], selectedCardId: UUID? = nil) {
    allCards = cards
    self.selectedCardId = selectedCardId
  }

  public func selectCard(_ card: MockCard) {
    selectedCardId = card.id
  }

  public func selectCardId(_ id: UUID?) {
    if let id, let card = cardFromId(id) {
      selectedCardId = card.id
    } else {
      selectedCardId = nil
    }
  }

  public func removeCards(at indices: IndexSet) {
    allCards.remove(atOffsets: indices)
  }

  public func cardFromId(_ id: UUID) -> MockCard? {
    allCards.first { $0.id == id }
  }

  public func bindCard(id: UUID) -> Binding<MockCard>? {
    guard cardFromId(id) != nil else {
      return nil
    }

    return Binding(
      get: { [weak self] in
        self?.cardFromId(id) ?? MockCard(cardType: .search, typeId: 0)
      },
      set: { [weak self] newValue in
        if let index = self?.allCards.firstIndex(where: { $0.id == id }) {
          self?.allCards[index] = newValue
        }
      },
    )
  }

  @discardableResult
  public func addCard(type cardType: scvCore.CardType) -> MockCard {
    let newId = (allCards.map(\.typeId).max() ?? 0) + 1
    let newCard = MockCard(cardType: cardType, typeId: newId)
    allCards.append(newCard)
    return newCard
  }
}

// MARK: - Preview

#Preview("CardSidebarView with 3 cards") {
  @Previewable @State var selectedId: UUID?

  let card1 = MockCard(cardType: .search, typeId: 1, searchQuery: "mindfulness")
  let card2 = MockCard(cardType: .sutta, typeId: 1, searchQuery: "MN44")
  let card3 = MockCard(cardType: .search, typeId: 3, searchQuery: "")

  let manager = MockCardManager(
    cards: [card1, card2, card3],
    selectedCardId: card1.id,
  )

  selectedId = card1.id

  return CardSidebarView(
    cardManager: manager,
    selectedCardId: $selectedId,
    onSettingsTap: {
      print("Settings tapped")
    },
  )
  .environmentObject(ThemeProvider())
}
