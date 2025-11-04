//
//  scv_demo_iosApp.swift
//  scv-demo-ios
//
//  Created by Visakha on 03/11/2025.
//

import SwiftUI
import scvUI

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
