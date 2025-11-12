//
//  ContentView.swift
//  scv-demo-ios
//
//  Created by Visakha on 03/11/2025.
//

import Combine
import scvCore
import scvUI
import SwiftUI

struct ContentView: View {
  @EnvironmentObject var player: SuttaPlayer
  @StateObject private var themeProvider = ThemeProvider()
  @State private var searchResponse: SearchResponse?
  @State private var showSettings = false
  @StateObject private var settingsController =
    SettingsModalController(from: Settings.shared)
  @State private var searchIntentRequest: SearchIntentRequest?
  @State private var showIntentConfirmation = false
  @State private var searchResults: [String] = []
  @State private var searchIntentResults: SearchIntentResults?
  @State private var showResultsDialog = false
  @State private var lastResultsCheckTime: Date = .init()

  private func loadMockResponse() {
    let language = Settings.shared.docLang.code
    let response = SearchResponse.createMockResponse(language: language)
    print(
      "DEBUG: createMockResponse(language: \(language)) returned: \(response != nil ? "not nil" : "nil")",
    )
    if let response {
      print("DEBUG: mlDocs count: \(response.mlDocs.count)")
    }
    searchResponse = response
  }

  private func loadSearchIntentRequest() {
    if let data = UserDefaults.standard
      .data(forKey: "com.scv.searchIntentRequest")
    {
      if let request = try? JSONDecoder().decode(
        SearchIntentRequest.self,
        from: data,
      ) {
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
        query: request.query,
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

  private func loadSearchIntentResults() {
    // First try app groups (for inter-process communication with App Intent)
    let defaults = UserDefaults(suiteName: "group.sc-voice.scv-app") ??
      UserDefaults.standard

    if let data = defaults.data(forKey: "SearchSuttasIntentResults") {
      // print(
      // "DEBUG: Found SearchSuttasIntentResults in UserDefaults (size: \(data.count) bytes)",
      // )
      if let results = try? JSONDecoder().decode(
        SearchIntentResults.self,
        from: data,
      ) {
        // print(
        // "DEBUG: Decoded results: \(results.query), \(results.results.count) suttas",
        // )
        // If results changed, dismiss old sheet and show new results
        if searchIntentResults?.query != results.query {
          print("DEBUG: New search detected, dismissing old sheet")
          showResultsDialog = false
          // Update results immediately, then show sheet after animation
          searchIntentResults = results
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showResultsDialog = true
          }
        } else {
          // Same query, just update
          searchIntentResults = results
          showResultsDialog = true
        }
      } else {
        print("DEBUG: Failed to decode SearchIntentResults")
      }
    }
  }

  private func clearSearchIntentResults() {
    let defaults = UserDefaults(suiteName: "group.sc-voice.scv-app") ??
      UserDefaults.standard
    defaults.removeObject(forKey: "SearchSuttasIntentResults")
    searchIntentResults = nil
    showResultsDialog = false
  }

  var body: some View {
    VStack {
      HStack {
        Text("SN24.11")
          .font(.title)
          .foregroundStyle(themeProvider.theme.textColor)
        Spacer()
        Button(action: { showSettings = true }) {
          Image(systemName: "gearshape")
            .font(.title2)
            .foregroundColor(themeProvider.theme.textColor)
        }
        .disabled(player.isPlaying)
        .padding(.trailing)
      }
      .padding()
      .background(themeProvider.theme.toolbarColor)

      if let searchResponse,
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
      loadSearchIntentResults()
    }
    .onChange(of: settingsController.docLang) {
      loadMockResponse()
    }
    .onReceive(Timer.publish(every: 0.5, on: .main, in: .common)
      .autoconnect())
    { _ in
      // Poll for app group UserDefaults changes since didChangeNotification
      // doesn't work for app groups
      loadSearchIntentResults()
    }
    .alert("Confirm Search", isPresented: $showIntentConfirmation) {
      Button("Cancel") {
        clearIntentRequest()
      }
      Button("Search", action: performIntentSearch)
    } message: {
      if let request = searchIntentRequest {
        Text(
          "Search \(request.language) (\(request.author)) for:\n\(request.query)",
        )
      }
    }
    .popover(
      isPresented: $showSettings,
      attachmentAnchor: .point(.topTrailing),
    ) {
      SettingsView(controller: settingsController)
        .environmentObject(themeProvider)
        .frame(maxWidth: 400, maxHeight: .infinity)
    }
    .sheet(isPresented: $showResultsDialog) {
      if let results = searchIntentResults {
        NavigationStack {
          SearchResultsView(
            results: results.results,
            query: results.query,
            language: results.language,
            author: results.author,
          )
          .environmentObject(themeProvider)
          .onAppear {
            print(
              "DEBUG ContentView sheet: Showing results. query='\(results.query)', results count=\(results.results.count)",
            )
          }
          .navigationTitle("Search Results")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Done") {
                clearSearchIntentResults()
              }
            }
          }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onDisappear {
          clearSearchIntentResults()
        }
      } else {
        VStack {
          Text("No results")
            .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
      }
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(SuttaPlayer.shared)
}
