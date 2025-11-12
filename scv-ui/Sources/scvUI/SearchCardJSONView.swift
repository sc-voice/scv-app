import SwiftUI

public struct SearchCardJSONView: View {
    let searchResponse: SearchResponse
    @State private var jsonString: String = ""

    public init(searchResponse: SearchResponse) {
        self.searchResponse = searchResponse
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("SearchResponse JSON")
                    .font(.headline)
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))

                HStack(spacing: 12) {
                    Label("\(searchResponse.mlDocs.count) documents", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.8, green: 0.65, blue: 0.0))

                    Label("\(searchResponse.segsMatched) matches", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.8, green: 0.65, blue: 0.0))
                }
            }
            .padding()
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .border(Color(red: 0.25, green: 0.25, blue: 0.25), width: 0.5)

            // JSON Content
            ScrollView([.horizontal, .vertical]) {
                Text(jsonString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        }
        .onAppear {
            jsonString = formatJSON()
        }
    }

    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        if let data = try? encoder.encode(searchResponse),
           let json = String(data: data, encoding: .utf8)
        {
            return json
        }

        return "Failed to encode SearchResponse to JSON"
    }
}

#Preview {
    if let mockResponse = SearchResponse.createMockResponse() {
        SearchCardJSONView(searchResponse: mockResponse)
    }
}
