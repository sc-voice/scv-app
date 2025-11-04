import Foundation
import AVFoundation
import scvCore

@MainActor
public final class SuttaPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = SuttaPlayer()

    @Published public var isPlaying = false
    @Published public var currentSutta: MLDocument?
    @Published public var currentSegmentIndex = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var segments: [(key: String, value: Segment)] = []

    override init() {
        super.init()
        configureAudioSession()
        synthesizer.delegate = self
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance()
                .setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
    }

    public func load(_ sutta: MLDocument) {
        synthesizer.stopSpeaking(at: .immediate)
        currentSutta = sutta
        segments = sutta.segments()
        currentSegmentIndex = 0
        isPlaying = false
    }

    public func togglePlayback() {
        guard currentSutta != nil else { return }

        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard currentSutta != nil else { return }
        isPlaying = true
        playSegment(at: currentSegmentIndex)
    }

    public func pause() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
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

        guard !text.isEmpty else {
            // Skip segment, advance to next
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.playSegment(at: index + 1)
            }
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        synthesizer.speak(utterance)
    }

    private func getSegmentText(_ segment: Segment) -> String {
        // Query settings at point of need
        let playPali = UserDefaults.standard.bool(forKey: "playPali")
        let playEnglish = UserDefaults.standard.bool(forKey: "playEnglish")

        if playPali, !segment.pli.isEmpty {
            return segment.pli
        }
        if playEnglish, !segment.en.isEmpty {
            return segment.en
        }

        // Fallback to English
        return segment.en.isEmpty ? segment.pli : segment.en
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            if self.isPlaying {
                self.playSegment(at: self.currentSegmentIndex + 1)
            }
        }
    }
}
