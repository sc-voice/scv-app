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
    VStack(spacing: 0) {
      AppRootView(cardManager: cardManager)
        .environmentObject(player)
        .environmentObject(themeProvider)
        .onAppear {
          cc.ok1(
            #line,
            "IOSView started with \(cardManager.allCards.count) card(s)",
          )
        }

      // iOS bottom toolbar
      #if os(iOS)
        iosBottomToolbar
      #endif
    }
    .ignoresSafeArea()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.green.opacity(0.3))
  }

  @ViewBuilder
  private var iosBottomToolbar: some View {
    let cc = ColorConsole(#file, "iosBottomToolbar", dbg.Settings.other)
    HStack(spacing: 0) {
      Spacer()
      Button(action: {
        cc.ok1(#line, "Settings gear button pressed")
        showSettings = true
      }) {
        Image(systemName: "gearshape")
          .font(.system(size: 30))
          .foregroundStyle(themeProvider.theme.textColor)
      }
      Spacer()
    }
    .ignoresSafeArea(edges: .bottom)
    .frame(maxHeight: 60)
    // .background(themeProvider.theme.toolbarColor)
    .sheet(isPresented: $showSettings) {
      SettingsView(controller: settingsController)
        .environmentObject(themeProvider)
    }
  }
}

// MARK: - Preview

#Preview("IOSView") {
  @Previewable @State var selectedCardId: UUID?

  let card1 = MockCard(cardType: .search, typeId: 1, searchQuery: "mindfulness")
  let manager = MockCardManager(
    cards: [card1],
    selectedCardId: card1.id,
  )

  IOSView(cardManager: manager)
    .environmentObject(SuttaPlayer.shared)
    .environmentObject(ThemeProvider())
}
