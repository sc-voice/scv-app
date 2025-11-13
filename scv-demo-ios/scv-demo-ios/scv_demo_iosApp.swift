//
//  scv_demo_iosApp.swift
//  scv-demo-ios
//
//  Created by Visakha on 03/11/2025.
//

import AppIntents
import scvUI
import SwiftUI

@main
struct scv_demo_iosApp: App {
  @StateObject private var player = SuttaPlayer.shared

  init() {
    AppLaunch.initialize()
  }

  var body: some Scene {
    let cc = ColorConsole(path: #file, method: #function)
    WindowGroup {
      ContentView()
        .environmentObject(player)
        .onAppear {
          _ = cc.ok1(#line, "WindowGroup appeared!")
        }
    }
  }
}

// MARK: - App Shortcuts

@available(iOS 16.0, macOS 13.0, *)
struct scv_demo_iosAppShortcuts: AppShortcutsProvider {
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
