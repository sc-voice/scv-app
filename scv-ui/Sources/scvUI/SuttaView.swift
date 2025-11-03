import SwiftUI
import AVFoundation
import scvCore

public struct SuttaView: View {
    let mlDoc: MLDocument
    @State private var synthesizer = PlaybackSynthesizer()
    @State private var isPlaying = false
    @State private var currentSegmentIndex = 0
    @State private var segments: [(key: String, value: Segment)] = []

    public init(mlDoc: MLDocument) {
        self.mlDoc = mlDoc
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

                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
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
                                .foregroundColor(index == currentSegmentIndex && isPlaying ? Color(red: 1.0, green: 0.85, blue: 0.0) : .primary)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(index == currentSegmentIndex && isPlaying ? Color(red: 0.15, green: 0.15, blue: 0.15) : .clear)
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

    private func togglePlayback() {
        if isPlaying {
            synthesizer.stopSpeaking()
            isPlaying = false
        } else {
            isPlaying = true
            playSegment(at: currentSegmentIndex)
        }
    }

    private func playSegment(at index: Int) {
        guard index < segments.count else {
            isPlaying = false
            currentSegmentIndex = 0
            return
        }

        currentSegmentIndex = index
        let (_, segment) = segments[index]
        let text = getSegmentText(segment)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let nextIndex = index + 1
        let hasNextSegment = nextIndex < segments.count

        synthesizer.speak(utterance, onFinish: { [self] in
            DispatchQueue.main.async {
                if hasNextSegment && isPlaying {
                    playSegment(at: nextIndex)
                } else {
                    isPlaying = false
                    currentSegmentIndex = 0
                }
            }
        })
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

// MARK: - Playback Synthesizer

final class PlaybackSynthesizer: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?
    private let queue = DispatchQueue(label: "com.scv.playback")

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ utterance: AVSpeechUtterance, onFinish: @escaping () -> Void) {
        queue.async {
            self.onFinish = onFinish
            self.synthesizer.speak(utterance)
        }
    }

    func stopSpeaking() {
        queue.async {
            self.synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
}

#Preview {
    if let mockResponse = SearchResponse.createMockResponse(), let mlDoc = mockResponse.mlDocs.first {
        SuttaView(mlDoc: mlDoc)
    }
}
