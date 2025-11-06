//
//  ContentView.swift
//  scv-demo-ios
//
//  Created by Visakha on 03/11/2025.
//

import SwiftUI
import scvUI
import scvCore

struct ContentView: View {
    @EnvironmentObject var player: SuttaPlayer
    @StateObject private var themeProvider = ThemeProvider()
    @State private var searchResponse: SearchResponse?
    @State private var showSettings = false
    @StateObject private var settingsController = SettingsModalController(from: Settings.shared)

    private func loadMockResponse() {
        let language = Settings.shared.docLang.code
        let response = SearchResponse.createMockResponse(language: language)
        print("DEBUG: createMockResponse(language: \(language)) returned: \(response != nil ? "not nil" : "nil")")
        if let response = response {
            print("DEBUG: mlDocs count: \(response.mlDocs.count)")
        }
        searchResponse = response
    }

    var body: some View {
        VStack {
            HStack {
                Text("SuttaView - sn42.11")
                    .font(.title)
                    .foregroundStyle(themeProvider.theme.textColor)
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(themeProvider.theme.textColor)
                }
                .padding(.trailing)
            }
            .padding()

            if let searchResponse = searchResponse,
               let mlDoc = searchResponse.mlDocs.first {
                SuttaView(mlDoc: mlDoc, player: player)
                    .environmentObject(themeProvider)
            } else {
                VStack(spacing: 16) {
                    Text("ScvDemo")
                        .font(.title)
                    Text("Loading mock search response...")
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeProvider.theme.cardBackground)
        .onAppear {
            print("DEBUG: ContentView.onAppear called")
            loadMockResponse()
        }
        .onChange(of: settingsController.docLang) {
            loadMockResponse()
        }
        .popover(isPresented: $showSettings, attachmentAnchor: .point(.topTrailing)) {
            SettingsView(controller: settingsController)
                .environmentObject(themeProvider)
                .frame(maxWidth: 400, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SuttaPlayer.shared)
}
