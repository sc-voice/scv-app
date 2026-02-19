import AVFoundation
import Foundation
import scvCore

/// Request to synthesize text and optionally play the result.
/// url is the cache file path (computed from text + audioContext).
struct SynthesisRequest {
  let text: String
  let audioContext: AudioContext
  let url: URL // from audioStore.audioUrl(forceUrl: true)
  var playback: Bool // true: play after synthesis, false: just cache
}

/// Concrete implementation of ISpeechSynthesizer wrapping AVAudioPlayer for
/// cached audio playback.
/// Translates AVAudioPlayerDelegate callbacks to IPlaybackDelegate events.
/// Uses AudioStore to retrieve cached/synthesized audio files for playback.
///
/// IMPORTANT: @MainActor on class enforces playback lifecycle coordination with
/// AudioStore.
/// AudioStore contract: URLs are stable until next playText() call on
/// MainActor.
/// This isolation ensures background compression can't interfere with active
/// playback.
/// Also allows nonisolated delegate methods to safely access mutable state.
@MainActor
final class CachedSynthesizer: NSObject, ISpeechSynthesizer,
  AVAudioPlayerDelegate
{
  private let cc = ColorConsole(#file, #function, dbg.CachedSynthesizer.other)
  private let audioStore: AudioStore
  private var audioPlayer: AVAudioPlayer?
  private var isCurrentlySpeaking = false
  // Synthesis queue (prioritized: playback:true before playback:false)
  private var synthesisQueue: [SynthesisRequest] = []
  private var queueProcessorTask: Task<Void, Never>?

  var playbackDelegate: IPlaybackDelegate?

  init(audioStore: AudioStore = .shared) {
    self.audioStore = audioStore
    super.init()
    cc.ok2(#line, "init() complete")
    startQueueProcessor()
  }

  var isSpeaking: Bool {
    isCurrentlySpeaking && (audioPlayer?.isPlaying ?? false)
  }

  var delegate: AVSpeechSynthesizerDelegate? {
    get { nil }
    set { /* AVAudioPlayer has no AVSpeechSynthesizerDelegate equivalent */ }
  }

  /// AudioStore automatically creates a new AVSpeechSynthesizer for each
  /// synthesis
  func resetSynthesizer() {}

  // MARK: - Queue Management

  /// Start the queue processor task (runs continuously in background)
  private func startQueueProcessor() {
    guard queueProcessorTask == nil else {
      cc.ok2(#line, #function, "Queue task already running")
      return
    }
    cc.ok2(#line, #function, "Starting task...")
    queueProcessorTask = Task {
      await processQueue()
    }
    cc.ok1(#line, #function, "Task started")
  }

  /// Add synthesis request to queue with deduplication and priority sorting.
  /// Merges duplicate URLs: playback:true overrides playback:false.
  private func queueRequest(_ request: SynthesisRequest) {
    cc.ok2(
      #line,
      "Queueing request for:",
      request.text.prefix(50),
      "playback:",
      request.playback,
    )

    // Check if URL already in queue
    if let index = synthesisQueue.firstIndex(where: { $0.url == request.url }) {
      // Merge: update playback flag (true overrides false)
      if request.playback {
        synthesisQueue[index].playback = true
        cc.ok2(#line, "Updated existing queue item to playback:true")
      }
    } else {
      // Add new request
      synthesisQueue.append(request)
      cc.ok2(#line, "Added new request to queue, size:", synthesisQueue.count)
    }

    // Sort by priority: playback:true first (descending)
    synthesisQueue.sort { $0.playback && !$1.playback }
    cc.ok2(
      #line,
      "Queue sorted, playback items first, size:",
      synthesisQueue.count,
    )
  }

  /// Process synthesis queue continuously (runs in background Task).
  /// Dequeues one request at a time, synthesizes, optionally plays.
  private func processQueue() async {
    while true {
      // Wait while queue is empty
      while synthesisQueue.isEmpty {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
      }

      guard !synthesisQueue.isEmpty else { continue }

      let request = synthesisQueue.removeFirst()
      cc.ok2(
        #line,
        "Processing queue request for:",
        request.text.prefix(50),
        "playback:",
        request.playback,
      )

      do {
        // Synthesize (or retrieve if already cached)
        _ = try await audioStore.storeAudio(
          text: request.text,
          audioContext: request.audioContext,
        )
        cc.ok2(#line, "Synthesis complete for:", request.text.prefix(50))

        // Play if requested
        if request.playback {
          playAudio(request.url)
        }
      } catch {
        cc.bad1(
          #line,
          "Synthesis failed for:",
          request.text.prefix(50),
          "error:",
          error,
        )
      }
    }
  }

  /// Extract and play audio from URL.
  /// Stop current playback, create AVAudioPlayer, emit callbacks.
  private func playAudio(_ url: URL) {
    cc.ok2(#line, "playAudio starting:", url.lastPathComponent)

    // Stop any current playback
    audioPlayer?.stop()
    isCurrentlySpeaking = false

    do {
      // Create and configure AVAudioPlayer
      let player = try AVAudioPlayer(contentsOf: url)
      player.delegate = self
      audioPlayer = player

      // Start playback
      isCurrentlySpeaking = true
      player.play()
      cc.ok2(#line, "Playback started")

      // Emit playback started event
      playbackDelegate?.onPlaybackStarted()
    } catch {
      cc.bad1(#line, "Failed to create AVAudioPlayer:", error)
    }
  }

  func stopSpeaking(at _: AVSpeechBoundary) -> Bool {
    // First: disarm pending playback requests (set playback:false)
    // This prevents queue processor from starting playback on dequeued requests
    for i in 0 ..< synthesisQueue.count {
      if synthesisQueue[i].playback {
        synthesisQueue[i].playback = false
        cc.ok2(#line, "Disarmed playback for queued request at index:", i)
      }
    }

    // Then: stop current playback
    guard isCurrentlySpeaking else {
      cc.ok2(#line, "stopSpeaking called but not currently playing")
      return false
    }

    audioPlayer?.stop()
    isCurrentlySpeaking = false
    cc.ok2(#line, "Stopped playback")
    return true
  }

  func playText(_ text: String, audioContext: AudioContext) throws {
    cc.ok2(#line, "playText starting: \(text.prefix(50))...")

    // Check if audio is already cached
    if let audioUrl = audioStore.audioUrl(
      text: text,
      audioContext: audioContext,
      forceUrl: false,
    ) {
      // Audio exists → play immediately
      cc.ok2(#line, #function, "Audio cached, playing immediately")
      playAudio(audioUrl)
      cc.ok1(#line, #function)
    } else {
      // Audio doesn't exist → queue synthesis with playback
      let url = audioStore.audioUrl(
        text: text,
        audioContext: audioContext,
        forceUrl: true,
      )!
      let request = SynthesisRequest(
        text: text,
        audioContext: audioContext,
        url: url,
        playback: true,
      )
      queueRequest(request)
      cc.ok1(#line, #function, "Queued synthesis+playback", url)
    }
  }

  // MARK: - AVAudioPlayerDelegate (translate to IPlaybackDelegate)

  nonisolated func audioPlayerDidFinishPlaying(
    _: AVAudioPlayer,
    successfully _: Bool,
  ) {
    Task { @MainActor in
      self.isCurrentlySpeaking = false
      self.playbackDelegate?.onPlaybackFinished()
      self.cc.ok1(#line, #function)
    }
  }

  nonisolated func audioPlayerBeginInterruption(_: AVAudioPlayer) {
    Task { @MainActor in
      // Disarm pending playback requests during interruption
      for i in 0 ..< self.synthesisQueue.count {
        if self.synthesisQueue[i].playback {
          self.synthesisQueue[i].playback = false
          self.cc.ok2(#line, #function, "Disarmed playback at:", i)
        }
      }
      self.playbackDelegate?.onPlaybackPaused()
      self.cc.ok1(#line, #function)
    }
  }

  nonisolated func audioPlayerEndInterruption(
    _: AVAudioPlayer,
    withOptions flags: UInt,
  ) {
    Task { @MainActor in
      #if os(iOS)
        if flags == AVAudioSession.InterruptionOptions.shouldResume.rawValue {
          self.audioPlayer?.play()
          self.playbackDelegate?.onPlaybackContinued()
          self.cc.ok1(#line, #function)
        }
      #else
        // On macOS, always resume
        self.audioPlayer?.play()
        self.playbackDelegate?.onPlaybackContinued()
        self.cc.ok1(#line, #function)
      #endif
    }
  }
}
