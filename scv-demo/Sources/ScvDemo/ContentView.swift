import SwiftUI
import scvUI

struct ContentView: View {
    @State private var searchResponse: SearchResponse?

    var body: some View {
        VStack {
            if let searchResponse = searchResponse {
                SearchCardJSONView(searchResponse: searchResponse)
            } else {
                VStack(spacing: 16) {
                    Text("ScvDemo")
                        .font(.title)
                    Text("Loading mock search response...")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            searchResponse = SearchResponse.createMockResponse()
        }
    }
}

#Preview {
    ContentView()
}
