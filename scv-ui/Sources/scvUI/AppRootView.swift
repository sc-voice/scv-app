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
  @State private var isSearchFocused: Bool = true
  @State private var showSettings = false
  @State private var settingsController = SettingsModalController(from: Settings
    .shared)
  let cc = ColorConsole(#file, #function, dbg.AppRootView.other)

  public init(cardManager: Manager) {
    self.cardManager = cardManager
  }

  public var body: some View {
    VStack(spacing: 0) {
      Text("v\(appVersion)")
        .foregroundStyle(themeProvider.theme.debugForeground)
      NavigationSplitView {
        // Sidebar with card list
        CardSidebarView(
          cardManager: cardManager,
          selectedCardId: Binding(
            get: { cardManager.selectedCardId },
            set: { newValue in
              cc.ok2(
                #line,
                "selectCardId:",
                newValue.map { String(describing: $0) } ?? "nil",
              )
              cardManager.selectCardId(newValue)
            },
          ),
          onSettingsTap: {
            cc.ok1(#line, "Settings gear button pressed from sidebar")
            showSettings = true
          },
        )
      } detail: {
        // Detail view based on selected card
        if let selectedCardId = cardManager.selectedCardId,
           let cardBinding = cardManager.bindCard(id: selectedCardId)
        {
          detailView(for: selectedCardId)
            .searchable(
              text: cardBinding.searchQuery,
              isPresented: $isSearchFocused,
              placement: {
                #if os(iOS)
                  return .navigationBarDrawer(displayMode: .always)
                #else
                  return .toolbar
                #endif
              }(),
              prompt: "Search",
            )
            .onSubmit(of: .search) {
              if let card = cardManager.cardFromId(selectedCardId) {
                SearchCardView.searchSubmitHandler(
                  card,
                  cardManager: cardManager,
                  searchQueryBinding: cardBinding.searchQuery,
                )
                isSearchFocused = false
              }
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
      .sheet(isPresented: $showSettings) {
        SettingsView(controller: settingsController)
          .environmentObject(themeProvider)
      }
    }
  }

  @ViewBuilder
  private func detailView(for cardId: Manager.ManagedCard.ID) -> some View {
    if let selectedCard = cardManager.allCards
      .first(where: { $0.id == cardId })
    {
      switch selectedCard.cardType {
      case .search:
        if let binding = cardManager.bindCard(id: cardId) {
          SearchCardView(card: binding, cardManager: cardManager)
            .environmentObject(themeProvider)
        } else {
          Text("Card not found")
            .foregroundStyle(.secondary)
        }

      case .sutta:
        Text("Sutta view coming soon")
          .font(.headline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(themeProvider.theme.cardBackground)
      }
    } else {
      Text("Card not found")
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Preview

#Preview("AppRootView with 1 card", traits: .portrait) {
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
  Text("AppRootView preview")
    .font(.caption)
    .foregroundStyle(themeProvider.theme.debugForeground)
    .ignoresSafeArea()
}
