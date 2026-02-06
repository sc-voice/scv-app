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
public struct SessionSnapshot: Sendable, Equatable {
  public let state: SynthesisState
  public let suttaRef: SuttaRef
  public let started: Date
  public let currentStep: Int
  public let totalSteps: Int
  public let audioContext: AudioContext
  public let estimatedCompletion: Date
  public let currentSegment: Segment?
  public let segmentKey: String
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
public actor AudioSynthesisSession {
  private let audioStore: AudioStore
  private let cc = ColorConsole(
    #file,
    #function,
    dbg.AudioSynthesisSession.other,
  )

  // Work queue: segments loaded from EbtData, processed sequentially during
  // execute()
  private var pendingSegments: [Segment] = []
  private let progressCallback: ((SessionSnapshot) -> Void)?
  private var previousState: SynthesisState = .idle

  /// Sutta reference (language/translator) for this session
  var suttaRef: SuttaRef

  /// Timestamp when execute() was called
  var started: Date = .init()

  /// Total segments to synthesize for this sutta
  var totalSegments: Int = 0

  /// Current step in synthesis (incremented as segments complete)
  var currentStep: Int = 0

  /// Exponential moving average of synthesis time per segment (in seconds)
  var segmentSynthesisTime: Double = 0.1

  /// Timestamp when current segment synthesis started
  private var segmentStartTime: Date?

  /// Current synthesis state (.idle, .synthesizing, .completed, .cancelled,
  /// .failed)
  var state: SynthesisState = .idle

  /// Audio context (language, voice, pitch, rate) for synthesis
  var audioContext: AudioContext

  /// "pli" or "doc" - selects which Segment property to synthesize. The
  /// selected property is extracted; if nil or empty, segment is skipped.
  private let segmentKey: String

  /// Step count for loading segments phase
  let STEP_LOAD_SEGMENTS: Int = 1
  var totalSteps: Int {
    totalSegments > 0 ? STEP_LOAD_SEGMENTS + totalSegments : 0
  }

  /// Cached session snapshot (updated via updateSnapshot())
  public private(set) var value: SessionSnapshot

  public init(
    _ suttaRef: SuttaRef,
    progressCallback: ((SessionSnapshot) -> Void)? = nil,
    audioContext: AudioContext? = nil,
    audioStore: AudioStore? = nil,
  ) {
    self.suttaRef = suttaRef
    segmentKey = suttaRef.lang == "pli" ? "pli" : "doc"
    self.audioStore = audioStore ?? AudioStore.shared
    self.audioContext = audioContext ?? AudioContext(for: suttaRef.lang)
    self.progressCallback = progressCallback

    // Initialize snapshot
    let now = Date()
    value = SessionSnapshot(
      state: .idle,
      suttaRef: suttaRef,
      started: now,
      currentStep: 0,
      totalSteps: 0,
      audioContext: self.audioContext,
      estimatedCompletion: now,
      currentSegment: nil,
      segmentKey: segmentKey,
    )
  }

  /// Compute and cache snapshot reflecting current state.
  /// Fire progress callback only on state transitions.
  /// Always updates cached snapshot for polling.
  private func updateSnapshot() {
    let elapsed = Date().timeIntervalSince(started)
    let estimatedCompletion: Date

      // For finished states, use current time as actual completion
      = if case .failed = state
    {
      Date()
    } else if state == .completed || state == .cancelled {
      Date()
    } else if currentStep == 0 {
      // No baseline: estimate is started + elapsed
      started + elapsed
    } else {
      // In progress: estimate remaining time based on average synthesis time
      // per segment
      Date() + (Double(pendingSegments.count) * segmentSynthesisTime)
    }

    value = SessionSnapshot(
      state: state,
      suttaRef: suttaRef,
      started: started,
      currentStep: currentStep,
      totalSteps: totalSteps,
      audioContext: audioContext,
      estimatedCompletion: estimatedCompletion,
      currentSegment: pendingSegments.first,
      segmentKey: segmentKey,
    )

    // Fire callback only on state transitions
    if let cb = progressCallback, state != previousState {
      cb(value)
      previousState = state
    }
  }

  func loadSuttaSegments() async {
    let segments = await EbtData.segmentsOfSuttaRef(suttaRef)

    guard !segments.isEmpty else {
      let errorMessage = "no segments for \(suttaRef)"
      state = .failed(errorMessage)
      cc.bad1(#line, #function, errorMessage)
      updateSnapshot()
      return
    }

    pendingSegments = segments
    totalSegments = segments.count
    cc.ok1(#line, #function, suttaRef.toString(), "[\(totalSegments) segments]")
    currentStep += STEP_LOAD_SEGMENTS
    updateSnapshot()
  }

  /// Execute synthesis of all segments in session's sutta.
  ///
  /// Returns final snapshot showing completion state (completed, cancelled, or
  /// failed).
  /// Synthesis runs on background thread via actor.
  /// progressCallback (if provided) fires on state transitions: .synthesizing,
  /// .completed, .cancelled, .failed.
  /// Query session.value anytime for current progress via polling.
  public func execute() async -> SessionSnapshot {
    // Guard: reject if not idle
    guard state == .idle else {
      let errorMessage = "Cannot execute: state is \(state), expected .idle"
      state = .failed(errorMessage)
      cc.bad1(#line, #function, errorMessage)
      updateSnapshot()
      return value
    }

    currentStep = 0
    state = .synthesizing
    started = Date()
    updateSnapshot()

    await loadSuttaSegments()

    // Synthesize segments sequentially
    while state == .synthesizing, !pendingSegments.isEmpty {
      // Check cancellation before processing segment
      if state == .cancelled {
        cc.ok1(#line, #function, "Synthesis cancelled")
        return value
      }

      let segment = pendingSegments.removeFirst()

      // Extract text using segmentKey
      let text = segment.textOf(segmentKey)

      // Skip blank segments
      guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
        cc.ok2(#line, #function, "Skipping blank segment: \(segment.scid)")
        _ = incrementSynthesisState()
        continue
      }

      // Synthesize via AudioStore
      do {
        segmentStartTime = Date()
        _ = try await audioStore.storeAudio(
          text: text,
          audioContext: audioContext,
        )

        // Update EMA of synthesis time
        if let startTime = segmentStartTime {
          let actualTime = Date().timeIntervalSince(startTime)
          let alpha = 0.3 // smoothing factor
          segmentSynthesisTime = alpha * actualTime + (1 - alpha) *
            segmentSynthesisTime
        }
        segmentStartTime = nil

        cc.ok2(#line, #function, "Synthesized: \(segment.scid)")
        _ = incrementSynthesisState()
      } catch {
        let errorMessage = "Synthesis failed for \(segment.scid): \(error.localizedDescription)"
        state = .failed(errorMessage)
        cc.bad1(#line, #function, errorMessage)
        updateSnapshot()
        return value
      }
    }

    // Handle completion
    if state == .synthesizing {
      state = .completed
      cc.ok1(#line, #function, suttaRef.toString(), "[\(state)]")
      updateSnapshot()
      return value
    } else {
      return value
    }
  }

  /// Increment synthesis progress after processing a segment.
  ///
  /// Updates currentStep and cached snapshot via updateSnapshot(). Does not
  /// fire callback (state unchanged). Returns updated snapshot for polling.
  private func incrementSynthesisState() -> SessionSnapshot {
    currentStep += 1
    updateSnapshot()
    return value
  }

  /// Cancels active synthesis job.
  ///
  /// Sets state to .cancelled. Worker checks state before processing each
  /// segment.
  /// Current segment completes gracefully. Pending segments discarded.
  /// progressCallback (if provided) fires with state = .cancelled.
  public func cancel() -> SessionSnapshot {
    state = .cancelled
    updateSnapshot()
    return value
  }
}
