import SwiftUI
import scvCore

public struct SuttaView: View {
  let mlDoc: MLDocument
  @ObservedObject var player: SuttaPlayer
  @EnvironmentObject var themeProvider: ThemeProvider
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
              .foregroundStyle(themeProvider.theme.textColor)
              .lineLimit(nil)

            HStack(spacing: 12) {
              HStack(spacing: 4) {
                Image(systemName: "person.fill")
                  .foregroundColor(themeProvider.theme.textColor)
                Text(mlDoc.docAuthorName)
                  .foregroundColor(themeProvider.theme.textColor)
              }
              .font(.caption)

              HStack(spacing: 4) {
                Image(systemName: "star.fill")
                  .foregroundColor(themeProvider.theme.textColor)
                Text("Score: \(String(format: "%.2f", mlDoc.score))")
                  .foregroundColor(themeProvider.theme.textColor)
              }
              .font(.caption)
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
              .foregroundColor(themeProvider.theme.textColor)
              .padding()
          }
        }
      }
      .padding()
      .background(themeProvider.theme.cardBackground)
      .border(themeProvider.theme.borderColor, width: 0.5)

      // Segments Content
      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(segments.indices, id: \.self) { index in
            let (scid, segment) = segments[index]
            HStack(alignment: .top, spacing: 8) {
              Text(scid)
                .font(.caption)
                .foregroundColor(themeProvider.theme.secondaryTextColor)
                .lineLimit(1)

              Text(getSegmentText(segment))
                .font(.body)
                .foregroundColor(themeProvider.theme.textColor)
                .lineLimit(nil)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(shouldHighlight(index) ? Color(red: 0.15, green: 0.15, blue: 0.15) : .clear)
          }
        }
        .padding(.vertical)
      }
      .background(themeProvider.theme.backgroundColor)
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
