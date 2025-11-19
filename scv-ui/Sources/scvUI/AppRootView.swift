//
//  AppRootView.swift
//  scv-ui
//
//  Created by Claude on 2025-11-19.
//

import scvCore
import SwiftUI

// MARK: - AppRootView

/// Root view for SCV app with card management and NavigationSplitView layout
public struct AppRootView<Manager: ICardManager>: View {
  var cardManager: Manager
  @EnvironmentObject var themeProvider: ThemeProvider
  let cc = ColorConsole(#file, #function, dbg.AppRootView.other)

  public init(cardManager: Manager) {
    self.cardManager = cardManager
  }

  public var body: some View {
    NavigationSplitView {
      // Sidebar with card list
      CardSidebarView(
        cardManager: cardManager,
        selectedCardId: Binding(
          get: { cardManager.selectedCardId },
          set: { newValue in
            cc.ok2(#line, "selectCardId:", newValue.map { String(describing: $0) } ?? "nil")
            cardManager.selectCardId(newValue)
          },
        ),
        onSettingsTap: nil,
      )
    } detail: {
      // Detail view based on selected card
      if let selectedCardId = cardManager.selectedCardId {
        if let selectedCard = cardManager.allCards
          .first(where: { $0.id == selectedCardId })
        {
          detailView(for: selectedCard)
        } else {
          Text("Card not found")
            .foregroundStyle(.secondary)
        }
      } else {
        VStack(spacing: 16) {
          Image(systemName: "square.3.layers.3d")
            .font(.system(size: 48))
            .foregroundStyle(.secondary)
          Text("No card selected")
            .font(.headline)
          Text("Select a card from the sidebar")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeProvider.theme.cardBackground)
      }
    }
    .onAppear {
      cc.ok1(
        #line,
        "AppRootView initialized with",
        cardManager.allCards.count,
        "cards",
      )
    }
    .onChange(of: cardManager.selectedCardId) {
      let idString = cardManager.selectedCardId
        .map { String(describing: $0) } ?? "nil"
      cc.ok2(#line, "selectedCardId:", idString)
    }
  }

  @ViewBuilder
  private func detailView(for card: Manager.ManagedCard) -> some View {
    switch card.cardType {
    case .search:
      SearchCardDetailView(card: card)
        .environmentObject(themeProvider)

    case .sutta:
      Text("Sutta view coming soon")
        .font(.headline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeProvider.theme.cardBackground)
    }
  }
}

// MARK: - SearchCardDetailView

/// Wrapper to display search card details
struct SearchCardDetailView<Card: ICard>: View {
  let card: Card
  @EnvironmentObject var themeProvider: ThemeProvider
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Search: \(card.searchQuery.isEmpty ? "(empty)" : card.searchQuery)")
        .font(.body)
        .foregroundStyle(themeProvider.theme.secondaryTextColor)

      Spacer()
    }
    .padding()
    .background(themeProvider.theme.cardBackground)
  }
}

// MARK: - Preview

#Preview("AppRootView with 1 card") {
  let card1 = MockCard(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )

  let manager = MockCardManager(
    cards: [card1],
    selectedCardId: card1.id,
  )

  let themeProvider = ThemeProvider()

  AppRootView(cardManager: manager)
  .environmentObject(themeProvider)
  .previewDevice(.init(rawValue: "iPhone 15"))
  .previewInterfaceOrientation(.portrait)
}
