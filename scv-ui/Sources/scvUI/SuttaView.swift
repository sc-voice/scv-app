import SwiftUI
import scvCore

public struct SuttaView: View {
    let mlDoc: MLDocument

    public init(mlDoc: MLDocument) {
        self.mlDoc = mlDoc
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title Header
            VStack(alignment: .leading, spacing: 8) {
                Text(mlDoc.title)
                    .font(.headline)
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
                    .lineLimit(nil)

                HStack(spacing: 12) {
                    Label(mlDoc.docAuthorName, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.8, green: 0.65, blue: 0.0))

                    Label("Score: \(String(format: "%.2f", mlDoc.score))", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.8, green: 0.65, blue: 0.0))
                }
            }
            .padding()
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .border(Color(red: 0.25, green: 0.25, blue: 0.25), width: 0.5)

            // Segments Content
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(mlDoc.segments(), id: \.key) { scid, segment in
                        HStack(alignment: .top, spacing: 8) {
                            Text(scid)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)

                            Text(getSegmentText(segment))
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        }
    }

    private func getSegmentText(_ segment: Segment) -> String {
        switch mlDoc.docLang.lowercased() {
        case "pli":
            return segment.pli.isEmpty ? segment.en : segment.pli
        case "ref":
            return segment.ref.isEmpty ? segment.en : segment.ref
        default: // "en" and others default to English
            return segment.en
        }
    }
}

#Preview {
    if let mockResponse = SearchResponse.createMockResponse(), let mlDoc = mockResponse.mlDocs.first {
        SuttaView(mlDoc: mlDoc)
    }
}
