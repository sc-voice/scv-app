//
//  App.swift
//  scv-ios
//
//  Created by Claude on 2025-11-19.
//

import AppIntents
import scvCore
import scvUI
import SwiftData
import SwiftUI

@main
struct SCVApp: App {
  @StateObject private var player = SuttaPlayer.shared
  @StateObject private var themeProvider = ThemeProvider()

  let modelContainer: ModelContainer
  let cardManager: CardManager

  init() {
    // Initialize SwiftData ModelContainer
    let config = ModelConfiguration(isStoredInMemoryOnly: false)
    do {
      modelContainer = try ModelContainer(
        for: Card.self,
        configurations: config,
      )
    } catch {
      fatalError("Could not initialize ModelContainer: \(error)")
    }

    // Initialize CardManager with ModelContext
    let context = ModelContext(modelContainer)
    cardManager = CardManager(modelContext: context)

    // Initialize app controller for URL scheme handling
    AppController.shared.initialize()
  }

  var body: some Scene {
    WindowGroup {
      let cc = ColorConsole(#file, "SCVApp", dbg.SCVApp.other)

      AppRootView(cardManager: cardManager)
        .environmentObject(player)
        .environmentObject(themeProvider)
        .onAppear {
          cc.ok1(
            #line,
            "SCVApp started with \(cardManager.allCards.count) card(s)",
          )
        }
        .onOpenURL { url in
          AppController.shared.handleSearchUrl(url: url)
        }
    }
  }
}

// MARK: - App Shortcuts

@available(iOS 16.0, macOS 13.0, *)
struct SCVAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchSuttasIntent(),
      phrases: [
        "Search \(.applicationName)",
      ],
      shortTitle: "Search Suttas",
      systemImageName: "magnifyingglass",
    )
  }

  static var shortcutTileColor: ShortcutTileColor = .blue
}
