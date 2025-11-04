//
//  ContentView.swift
//  scv-demo-ios
//
//  Created by Visakha on 03/11/2025.
//

import SwiftUI
import scvUI

struct ContentView: View {
    @EnvironmentObject var player: SuttaPlayer
    @State private var searchResponse: SearchResponse?

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    var body: some View {
        VStack {
            HStack {
                Text("SuttaView - sn42.11")
                    .font(.title)
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
                Spacer()
                Text("Build: \(buildNumber)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing)
            }
            .padding()

            if let searchResponse = searchResponse,
               let mlDoc = searchResponse.mlDocs.first {
                SuttaView(mlDoc: mlDoc, player: player)
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
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        .onAppear {
            print("DEBUG: ContentView.onAppear called")
            let response = SearchResponse.createMockResponse()
            print("DEBUG: createMockResponse returned: \(response != nil ? "not nil" : "nil")")
            if let response = response {
                print("DEBUG: mlDocs count: \(response.mlDocs.count)")
            }
            searchResponse = response
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SuttaPlayer.shared)
}
