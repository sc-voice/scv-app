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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
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
                // AppShortcuts do support parameters with clearly defined, recognized values.
                // However, AppShortcuts do NOT support open-ended parameter values.
                // Arbitrary queries are open-ended parameters, so we need
                // to use recognizable shortcut phrases for Siri
                "Search Buddhist Suttas", // generic shortcut
                "Search \(.applicationName)", // app-specific shortcut
            ],
            shortTitle: "Search Suttas",
            systemImageName: "magnifyingglass"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .blue
}
