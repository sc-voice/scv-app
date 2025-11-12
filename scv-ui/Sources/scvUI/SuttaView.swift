import scvCore
import SwiftUI

public struct SuttaView: View {
    let initialDoc: MLDocument
    @State private var mlDoc: MLDocument
    @ObservedObject var player: SuttaPlayer
    @EnvironmentObject var themeProvider: ThemeProvider
    @State private var segments: [(key: String, value: Segment)] = []

    public init(mlDoc: MLDocument, player: SuttaPlayer = .shared) {
        initialDoc = mlDoc
        _mlDoc = State(initialValue: mlDoc)
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

                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .foregroundColor(themeProvider.theme.textColor)
                            Text(mlDoc.docAuthorName)
                                .foregroundColor(themeProvider.theme.textColor)
                        }
                        .font(.caption)
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
                        .background(shouldHighlight(scid) ? themeProvider.theme.accentColor.opacity(0.2) : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    isSegmentSelected(scid) ? themeProvider.theme.accentColor : .clear,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .butt, lineJoin: .bevel, dash: [4, 3])
                                )
                        )
                        .onTapGesture {
                            mlDoc.currentScid = scid
                            if isCurrentlyPlaying && player.isPlaying {
                                player.jumpToSegment(scid: scid)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(themeProvider.theme.backgroundColor)
        }
        .onAppear {
            segments = mlDoc.segments()
            // Initialize currentScid to first segment if nil
            if mlDoc.currentScid == nil, let firstSegment = segments.first {
                mlDoc.currentScid = firstSegment.key
            }
        }
    }

    private var isCurrentlyPlaying: Bool {
        player.currentSutta?.sutta_uid == mlDoc.sutta_uid
    }

    private func shouldHighlight(_ scid: String) -> Bool {
        isCurrentlyPlaying && player.isPlaying && scid == mlDoc.currentScid
    }

    private func isSegmentSelected(_ scid: String) -> Bool {
        mlDoc.currentScid == scid
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

    private func buildAttributedString(_ parseResult: HTMLParseResult) -> AttributedString {
        var attributedString = AttributedString("")

        for span in parseResult.spans {
            var spanAttr = AttributedString(span.text)
            if span.isMatched {
                spanAttr.foregroundColor = themeProvider.theme.accentColor
            } else {
                spanAttr.foregroundColor = themeProvider.theme.textColor
            }
            attributedString.append(spanAttr)
        }

        return attributedString
    }

    @ViewBuilder
    private func highlightedSegmentView(_ html: String) -> some View {
        let parseResult = HTMLParser.parse(htmlString: html)
        let attributedString = buildAttributedString(parseResult)

        Text(attributedString)
            .contextMenu {
                Button("Copy Matched") {
                    let matched = parseResult.spans
                        .filter { $0.isMatched }
                        .map { $0.text }
                        .joined()
                    UIPasteboard.general.string = matched
                }
                Button("Copy As Pali") {
                    // TODO: Implement copy as Pali
                }
            }
    }
}

#Preview {
    if let mockResponse = SearchResponse.createMockResponse(), let mlDoc = mockResponse.mlDocs.first {
        SuttaView(mlDoc: mlDoc, player: .shared)
    }
}
