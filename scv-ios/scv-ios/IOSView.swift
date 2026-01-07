//
//  IOSView.swift
//  scv-ios
//
//  Created by Claude on 2025-11-20.
//

import scvCore
import scvUI
import SwiftUI

struct IOSView<Manager: ICardManager>: View {
  var cardManager: Manager
  @EnvironmentObject var player: SuttaPlayer
  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var showSettings = false
  @State private var settingsController = SettingsModalController(from: Settings
    .shared)
  let cc = ColorConsole(#file, #function, dbg.IOSView.other)

  var body: some View {
    let appIcon = Bundle.main.appIcon.map { Image(uiImage: $0) }

    VStack(spacing: 0) {
      AppRootView(cardManager: cardManager, appIcon: appIcon)
        .environmentObject(player)
        .environmentObject(themeProvider)
        .onAppear {
          cc.ok1(
            #line,
            "IOSView started with \(cardManager.allCards.count) card(s)",
          )
        }
    } // VStack
    .ignoresSafeArea()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.pink) // Should never be seen
  }
}

// MARK: - Preview

#Preview("IOSView") {
  @Previewable @State var selectedCardId: UUID?

  let card1 = PreviewCard(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )
  let manager = PreviewCardManager(
    cards: [card1],
    selectedCardId: card1.id,
  )

  IOSView(cardManager: manager)
    .environmentObject(SuttaPlayer.shared)
    .environmentObject(ThemeProvider())
}
