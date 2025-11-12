//
//  ContentView.swift
//  scv-demo-ios
//
//  Created by Visakha on 03/11/2025.
//

import scvCore
import scvUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: SuttaPlayer
    @StateObject private var themeProvider = ThemeProvider()
    @State private var searchResponse: SearchResponse?
    @State private var showSettings = false
    @StateObject private var settingsController = SettingsModalController(from: Settings.shared)
    @State private var searchIntentRequest: SearchIntentRequest?
    @State private var showIntentConfirmation = false
    @State private var searchResults: [String] = []

    private func loadMockResponse() {
        let language = Settings.shared.docLang.code
        let response = SearchResponse.createMockResponse(language: language)
        print("DEBUG: createMockResponse(language: \(language)) returned: \(response != nil ? "not nil" : "nil")")
        if let response = response {
            print("DEBUG: mlDocs count: \(response.mlDocs.count)")
        }
        searchResponse = response
    }

    private func loadSearchIntentRequest() {
        if let data = UserDefaults.standard.data(forKey: "com.scv.searchIntentRequest") {
            if let request = try? JSONDecoder().decode(SearchIntentRequest.self, from: data) {
                searchIntentRequest = request
                showIntentConfirmation = true
            }
        }
    }

    private func performIntentSearch() {
        guard let request = searchIntentRequest else { return }
        Task {
            let results = await EbtData.shared.searchKeywords(
                lang: request.language,
                author: request.author,
                query: request.query
            )
            searchResults = results
        }
    }

    private func clearIntentRequest() {
        UserDefaults.standard.removeObject(forKey: "com.scv.searchIntentRequest")
        searchIntentRequest = nil
        showIntentConfirmation = false
        searchResults = []
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
                .disabled(player.isPlaying)
                .padding(.trailing)
            }
            .padding()

            if let searchResponse = searchResponse,
               let mlDoc = searchResponse.mlDocs.first
            {
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
            loadSearchIntentRequest()
        }
        .onChange(of: settingsController.docLang) {
            loadMockResponse()
        }
        .alert("Confirm Search", isPresented: $showIntentConfirmation) {
            Button("Cancel") {
                clearIntentRequest()
            }
            Button("Search", action: performIntentSearch)
        } message: {
            if let request = searchIntentRequest {
                Text("Search \(request.language) (\(request.author)) for:\n\(request.query)")
            }
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
