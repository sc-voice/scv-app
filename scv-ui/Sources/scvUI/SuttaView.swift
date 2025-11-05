import SwiftUI
import scvCore

// MARK: - Highlighted Span Parsing
private struct HighlightedSpan {
  let text: String
  let isMatched: Bool
}

private func parseMatchedSpans(_ html: String) -> [HighlightedSpan] {
  var spans: [HighlightedSpan] = []
  let pattern = #"<span class="scv-matched">([^<]*)</span>|([^<]+)"#
  guard let regex = try? NSRegularExpression(pattern: pattern) else { return [.init(text: html, isMatched: false)] }

  let nsString = html as NSString
  regex.enumerateMatches(in: html, range: NSRange(location: 0, length: nsString.length)) { match, _, _ in
    guard let match = match else { return }
    if let range = Range(match.range(at: 1), in: html) {
      spans.append(.init(text: String(html[range]), isMatched: true))
    } else if let range = Range(match.range(at: 2), in: html) {
      spans.append(.init(text: String(html[range]), isMatched: false))
    }
  }
  return spans.isEmpty ? [.init(text: html, isMatched: false)] : spans
}

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

              highlightedSegmentView(getSegmentText(segment, field: "doc"))
                .font(.body)
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

  private func getSegmentText(_ segment: Segment, field: String = "doc") -> String {
    let EMPTY_SET = "∅"
    let value: String?
    switch field.lowercased() {
    case "doc":
      value = segment.doc
    case "pli":
      value = segment.pli
    case "ref":
      value = segment.ref
    default:
      value = nil
    }
    return value?.isEmpty ?? true ? EMPTY_SET : value!
  }

  @ViewBuilder
  private func highlightedSegmentView(_ html: String) -> some View {
    let spans = parseMatchedSpans(html)
    HStack(spacing: 0) {
      ForEach(spans.indices, id: \.self) { index in
        let span = spans[index]
        if span.isMatched {
          Text(span.text)
            .foregroundColor(.accentColor)
            .contextMenu {
              Button("Copy Matched") {
                UIPasteboard.general.string = span.text
              }
              Button("Copy As Pali") {
                // TODO: Implement copy as Pali
              }
            }
        } else {
        }
      }
    }
  }
}

#Preview {
  if let mockResponse = SearchResponse.createMockResponse(), let mlDoc = mockResponse.mlDocs.first {
    SuttaView(mlDoc: mlDoc, player: .shared)
  }
}
