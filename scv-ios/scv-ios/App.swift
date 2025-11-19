//
//  App.swift
//  scv-ios
//
//  Created by Claude on 2025-11-19.
//

import AppIntents
import Foundation
import scvCore
import scvUI
import SwiftData
import SwiftUI

@main
struct SCVApp: App {
  @StateObject private var player = SuttaPlayer.shared
  @StateObject private var themeProvider: ThemeProvider
  @State private var isReady = false
  let cc = ColorConsole(#file, #function, dbg.App.other)

  let modelContainer: ModelContainer
  let cardManager: CardManager

  init() {
    // Initialize SwiftData ModelContainer with App Group container for intent
    // sharing
    let appGroupURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.sc-voice.scv-app",
    )?.appendingPathComponent("default.store")
    cc.ok2(#line, "appGroupURL:", appGroupURL?.absoluteString ?? "nil");
    let config = ModelConfiguration(
      schema: Schema([Card.self]),
      url: appGroupURL ?? URL(fileURLWithPath: "/dev/null"),
    )
    do {
      modelContainer = try ModelContainer(
        for: Card.self,
        configurations: config,
      )
      cc.ok2(#line, "modelContainer");
    } catch {
      let msg = "Could not initialize ModelContainer: \(error)"
      cc.bad1(#line, msg)
      fatalError(msg)
    }

    // Initialize CardManager with ModelContext
    let context = ModelContext(modelContainer)
    cardManager = CardManager(modelContext: context)
    cc.ok2(#line, "cardManager")

    // Initialize ThemeProvider synchronously before any views render
    _themeProvider = StateObject(wrappedValue: ThemeProvider())
    cc.ok2(#line, "_themeProvider")

    // Initialize app controller for URL scheme handling
    AppController.shared.initialize()
    cc.ok1(#line, "init OK")
  }

  var body: some Scene {
    WindowGroup {
      let cc = ColorConsole(#file, "SCVApp", dbg.SCVApp.other)

      ZStack {
        if isReady {
          AppRootView(cardManager: cardManager)
            .environmentObject(player)
            .environmentObject(themeProvider)
            .onAppear {
              cc.ok1(
                #line,
                "SCVApp started with \(cardManager.allCards.count) card(s)",
              )
            }
        } else {
          VStack(spacing: 16) {
            ProgressView()
            Text("Coming soon...")
              .font(.headline)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .task {
        cc.ok2(#line, "task started, delaying for view hierarchy setup")
        try? await Task.sleep(nanoseconds: 100_000_000)
        isReady = true
        cc.ok2(#line, "isReady = true")
      }
      .onOpenURL { url in
        cc.ok2(#line, "openURL", url.absoluteString)
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
