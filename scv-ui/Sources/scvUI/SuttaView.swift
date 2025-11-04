import SwiftUI
import scvCore

public struct SuttaView: View {
    let mlDoc: MLDocument
    @ObservedObject var player: SuttaPlayer
    @State private var segments: [(key: String, value: Segment)] = []

    public init(mlDoc: MLDocument, player: SuttaPlayer = .shared) {
        self.mlDoc = mlDoc
        self.player = player
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
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

                    Spacer()

                    Button(action: {
                        if player.currentSutta?.sutta_uid != mlDoc.sutta_uid {
                            player.load(mlDoc)
                        }
                        player.togglePlayback()
                    }) {
                        Image(systemName: isCurrentlyPlaying && player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0))
                            .padding()
                    }
                }
            }
            .padding()
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .border(Color(red: 0.25, green: 0.25, blue: 0.25), width: 0.5)

            // Segments Content
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(segments.indices, id: \.self) { index in
                        let (scid, segment) = segments[index]
                        HStack(alignment: .top, spacing: 8) {
                            Text(scid)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)

                            Text(getSegmentText(segment))
                                .font(.body)
                                .foregroundColor(shouldHighlight(index) ? Color(red: 1.0, green: 0.85, blue: 0.0) : .primary)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(shouldHighlight(index) ? Color(red: 0.15, green: 0.15, blue: 0.15) : .clear)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        }
        .onAppear {
            segments = mlDoc.segments()
        }
    }

    private var isCurrentlyPlaying: Bool {
        player.currentSutta?.sutta_uid == mlDoc.sutta_uid
    }

    private func shouldHighlight(_ index: Int) -> Bool {
        isCurrentlyPlaying && player.isPlaying && index == player.currentSegmentIndex
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
        SuttaView(mlDoc: mlDoc, player: .shared)
    }
}
