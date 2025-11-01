import SwiftUI
import scvUI

@main
struct ScvDemoApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("MockResponseView")
                    .font(.title)
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
                    .padding()

                if let mockResponse = SearchResponse.createMockResponse() {
                    SearchCardJSONView(searchResponse: mockResponse)
                } else {
                    Text("Failed to load mock response")
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        }
    }
}
