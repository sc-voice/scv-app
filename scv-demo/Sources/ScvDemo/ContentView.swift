import SwiftUI
import scvUI

struct ContentView: View {
    @State private var searchResponse: SearchResponse?

    var body: some View {
        VStack {
            Text("SuttaView - sn42.11")
                .font(.title)
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
                .padding()

            if let searchResponse = searchResponse,
               let mlDoc = searchResponse.mlDocs.first {
                SuttaView(mlDoc: mlDoc)
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
            searchResponse = SearchResponse.createMockResponse()
        }
    }
}

#Preview {
    ContentView()
}
