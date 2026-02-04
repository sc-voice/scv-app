import Foundation

// State tracking
public enum SynthesisState: Sendable, Equatable {
  case idle // awaiting request
  case synthesizing // synthesisWorker still processing segments
  case completed // All segments synthesized successfully
  case cancelled // User called cancelSynthesis()
  case failed(String) // Error message describing synthesis failure
}

// Snapshot struct for progress callbacks
public struct SessionSnapshot: Sendable {
  let state: SynthesisState
  let suttaRef: SuttaRef
  let started: Date
  let currentStep: Int
  let totalSteps: Int
  let audioContext: AudioContext
  let estimatedTimeRemaining: TimeInterval
  let currentSegment: Segment?
}

/// Single-use session for background audio synthesis of one sutta.
///
/// Each synthesis job creates a new session. Sessions are immutable once
/// created
/// and track: sutta reference, audio context, progress (steps, timing), and
/// completion state.
/// Public interface (SessionSnapshot) exposes readonly state for
/// progress callbacks.
///
/// - Session: synthesizes text segments to audio files and stores via
/// AudioStore
/// - End User: requests sutta audio preparation and receives progress updates
actor AudioSynthesisSession {
  private let audioStore: AudioStore
  private let cc = ColorConsole(
    #file,
    #function,
    dbg.AudioSynthesisSession.other,
  )

  // Work queue
  private var pendingSegments: [Segment] = []
  private var progressCallback: ((SessionSnapshot) -> Void)?
  private var lastCallbackSnapshot: SessionSnapshot?

  var suttaRef: SuttaRef
  var started: Date = .init()
  var completedSegments: Int = 0
  var totalSegments: Int = 0
  var currentStep: Int = 0
  var state: SynthesisState = .idle
  var audioContext: AudioContext
  let STEP_LOAD_SEGMENTS: Int = 1
  var totalSteps: Int {
    totalSegments > 0 ? STEP_LOAD_SEGMENTS + totalSegments : 0
  }

  var estimatedTimeRemaining: TimeInterval {
    let stepsRemaining = max(0, totalSteps - currentStep)
    let elapsed = Date().timeIntervalSince(started)
    if currentStep == 0 { // no baseline for estimate
      return elapsed
    }
    return elapsed * (Double(stepsRemaining) / Double(currentStep))
  }

  private let segmentKey: String

  init(
    _ suttaRef: SuttaRef,
    audioContext: AudioContext? = nil,
    audioStore: AudioStore? = nil,
  ) {
    self.suttaRef = suttaRef
    segmentKey = suttaRef.lang == "pli" ? "pli" : "doc"
    self.audioStore = audioStore ?? AudioStore.shared
    self.audioContext = audioContext ?? AudioContext(for: suttaRef.lang)
  }

  func loadSuttaSegments() async {
    let segments = await EbtData.segmentsOfSuttaRef(suttaRef)

    guard !segments.isEmpty else {
      let errorMessage = "no segments for \(suttaRef)"
      state = .failed(errorMessage)
      cc.bad1(#line, #function, errorMessage)
      progressCallback?(getValue())
      return
    }

    pendingSegments = segments
    totalSegments = segments.count
    cc.ok1(#line, #function, suttaRef.toString(), "[\(totalSegments) segments]")
    currentStep += STEP_LOAD_SEGMENTS
    progressCallback?(getValue())
  }

  /// Execute synthesis of all segments in session's sutta.
  ///
  /// Returns immediately (non-blocking). Synthesis runs on background thread
  /// via actor.
  /// progressCallback called repeatedly with state updates and once at
  /// completion
  /// (success, error, or cancellation).
  ///
  /// - Parameter progressCallback: Called with progress updates and final
  /// completion state
  func execute(progressCallback: @escaping (SessionSnapshot)
    -> Void) async
  {
    self.progressCallback = progressCallback
    currentStep = 0
    state = .synthesizing
    started = Date()

    await loadSuttaSegments()

    // TODO: Iterate and synthesize via AudioStore
    // TODO: Update progress and call progressCallback
    // TODO: Handle cancellation and errors
  }

  /// Cancels active synthesis job.
  ///
  /// Sets cancellation flag. Worker checks flag before processing each segment.
  /// Current segment completes gracefully. Pending segments discarded.
  /// Final callback sent with state = .cancelled.
  func cancel() async {
    // TODO: Implementation
  }

  // MARK: - Testing Helpers

  /// Returns current session state as snapshot (for testing)
  func getValue() -> SessionSnapshot {
    SessionSnapshot(
      state: state,
      suttaRef: suttaRef,
      started: started,
      currentStep: currentStep,
      totalSteps: totalSteps,
      audioContext: audioContext,
      estimatedTimeRemaining: estimatedTimeRemaining,
      currentSegment: pendingSegments.first,
    )
  }

  /// Wraps progressCallback to track last invocation (for testing)
  func setTestProgressCallback(_ callback: @escaping (SessionSnapshot)
    -> Void)
  {
    progressCallback = { snapshot in
      self.lastCallbackSnapshot = snapshot
      callback(snapshot)
    }
  }

  /// Returns last snapshot sent to progressCallback (for testing)
  func getLastCallbackSnapshot() -> SessionSnapshot? {
    lastCallbackSnapshot
  }
}
