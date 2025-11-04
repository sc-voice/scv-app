import SwiftUI
import scvUI

@main
struct ScvDemoApp: App {
    @StateObject private var player = SuttaPlayer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
        }
    }
}
