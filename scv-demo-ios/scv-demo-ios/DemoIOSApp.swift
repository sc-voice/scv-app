//
//  DemoIOSApp.swift
//  scv-demo-ios
//
//  Created by Visakha on 03/11/2025.
//

import AppIntents
import scvUI
import SwiftUI

@main
struct DemoIOSApp: App {
  @StateObject private var player = SuttaPlayer.shared

  init() {
    AppController.shared.initialize()
  }

  var body: some Scene {
    WindowGroup {
      let cc = ColorConsole(#file, "ContentView", dbg.DemoIOSApp.other)
      ContentView()
        .environmentObject(player)
        .onAppear {
          cc.ok1(#line, ".onAppear")
        }
        .onOpenURL { url in
          AppController.shared.handleSearchUrl(url: url)
        }
    }
  }
}

// MARK: - App Shortcuts

@available(iOS 16.0, macOS 13.0, *)
struct DemoIOSAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchSuttasIntent(),
      phrases: [
        // AppShortcuts do support parameters with enumarable values.
        // However, AppShortcuts do NOT support open-ended parameter values.
        // Arbitrary queries are open-ended parameters, so we need
        // to use recognizable shortcut phrases for Siri.
        // In addition, the application name MUST be in the shortcut
        "Search \(.applicationName)", // app-specific shortcut
      ],
      shortTitle: "Search Suttas",
      systemImageName: "magnifyingglass",
    )
  }

  static var shortcutTileColor: ShortcutTileColor = .blue
}
