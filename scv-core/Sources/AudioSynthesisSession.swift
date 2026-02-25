import Foundation

//
//  AudioSynthesisSession
//
//  Single-use session for background audio synthesis of one sutta.
//  Each synthesis job creates a new session that orchestrates segment-by-segment
//  synthesis via producer-consumer pipeline pattern.
//
//  ## Design Rationale
//
//  ### Separation of Concerns
//
//  - AudioSynthesisSession: Orchestrates synthesis work, manages queues, handles
//    cancellation
//  - AudioStore: Handles file persistence (CAF/M4A storage and retrieval)
//  - Session does NOT synthesize audio directly — it delegates to AudioStore
//
//  Session queues segments and calls AudioStore.storeAudio() for each. AudioStore
//  handles actual synthesis via AVSpeechSynthesizer and file I/O.
//
//  ### Threading Model
//
//  - End User (main thread): Calls execute() and cancel()
//  - AudioSynthesisSession (background thread via actor): Runs synthesis loop,
//    updates progress
//  - Thread safety: Swift actor provides automatic isolation
//  - Progress callbacks: Posted back to caller from background work
//
//  ### Pipeline Pattern
//
//  ```
//  User calls execute() → Session queues segments → AudioStore synthesizes →
//  caches files
//                                                                        ↓
//                                                              Progress callbacks →
//                                                              UI
//  ```
//
//  Key characteristics:
//  - Single-use: Each session tied to one sutta ref; create new session for
//    different sutta
//  - Immutable: Session state initialized on creation, only updated during
//    execute()
//  - Persistence: Audio files survive app restarts
//  - Cancellation: User can cancel mid-batch via cancel()
//  - Sequential: Session processes one segment at a time via AudioStore
//  - Progress: Callback informs UI of progress (currentStep, totalSteps, ETA,
//    completion state)
//
//  ## Error Handling Strategy
//
//  Decision: Halt on first error, skip blank segments gracefully
//
//  Rationale: AudioSynthesisSession is called from Background Playback menu to
//  synthesize partial suttas. Some segments may have no text in the selected
//  language. These should be skipped silently to allow synthesis to proceed with
//  available content.
//
//  Behavior:
//  - Blank segments (selected property nil or empty): skip synthesis, increment
//    progress, continue
//  - If AudioStore.storeAudio() throws for non-blank segment: session catches
//    error and transitions to .failed(error)
//  - Pending segments discarded on error
//  - Final callback sent with state = .failed(error) on error or state =
//    .completed if all available segments synthesized
//  - Partial playback supported: synthesized segments playable even if some
//    segments were blank or synthesis was cancelled
//
//  ## Resume Capability (Implicit via Idempotent Caching)
//
//  AudioSynthesisSession does not provide explicit pause/resume API.
//
//  Resume is implicitly supported through idempotent caching:
//  1. User initiates synthesis (long-press, menu item, or API call)
//  2. Session synthesizes segments and caches audio via AudioStore.storeAudio()
//  3. User backgrounds app mid-synthesis → cancellation via dismissal or app
//     background
//  4. Later, user re-triggers synthesis for same sutta
//  5. New session loads segments again, calls AudioStore.storeAudio() for each
//  6. AudioStore returns cached files for already-synthesized segments (no
//     re-synthesis cost)
//  7. Session only synthesizes remaining uncached segments
//  8. User perceives seamless "resume"
//
//  Design advantage: No session state persistence needed. Caching layer handles
//  resume transparently. Sessions remain single-use and immutable.
//
//  ## SwiftUI Integration
//
//  Actor references in @State: AudioSynthesisSession is a reference type (actor).
//  It is Sendable and can be held safely in SwiftUI @State:
//
//  ```swift
//  struct SuttaCardView: View {
//    @State var backgroundSession: AudioSynthesisSession?
//    @State var showSynthesisModal = false
//    @State var currentSnapshot: SessionSnapshot?
//
//    var body: some View {
//      Button(action: { startSynthesis() }) { ... }
//        .onLongPressGesture { startSynthesis() }
//    }
//
//    private func startSynthesis() {
//      guard let suttaRef = suttaRef else { return }
//
//      // Create session with callback for progress updates
//      backgroundSession = AudioSynthesisSession(
//        suttaRef,
//        progressCallback: { snapshot in
//          // Thread safety: callback fires on background actor thread
//          // Marshal UI updates to main thread via DispatchQueue.main.async
//          DispatchQueue.main.async {
//            self.currentSnapshot = snapshot
//          }
//        }
//      )
//
//      showSynthesisModal = true
//
//      // Execute synthesis on background thread via Task/await
//      Task {
//        let finalSnapshot = await backgroundSession?.execute()
//        // Synthesis complete; finalSnapshot contains final state
//      }
//    }
//
//    private func cancelSynthesis() {
//      Task {
//        await backgroundSession?.cancel()
//      }
//    }
//
//    // Clean up on view dismissal to prevent orphaned synthesis
//    .onDisappear {
//      Task {
//        await backgroundSession?.cancel()
//      }
//    }
//  }
//  ```
//
//  Key patterns:
//  1. Hold actor in @State: Actors are reference types and Sendable, safe for
//     @State
//  2. Call async methods via Task/await: All actor methods (execute(), cancel())
//     require await
//  3. Thread marshaling in callback: progressCallback fires on background actor
//     thread. Use DispatchQueue.main.async { self.property = value } to update
//     @State
//  4. Cleanup on view dismissal: Call await backgroundSession?.cancel() in
//     .onDisappear to prevent orphaned synthesis tasks
//
//  ## Progress Monitoring Patterns
//
//  ### Callbacks (State Changes)
//
//  progressCallback fires when session state changes:
//  - .idle → .synthesizing (synthesis starts)
//  - .synthesizing → .completed (all segments processed)
//  - .synthesizing → .cancelled (user cancelled)
//  - .synthesizing → .failed(String) (error halts synthesis)
//
//  This is sparse: ~2 callbacks per session. Useful for UI state transitions
//  (show/hide modal, enable/disable buttons).
//
//  ### Polling (On-Demand Progress)
//
//  For high-frequency progress tracking (UI wanting per-segment granularity),
//  query session.value directly:
//
//  ```swift
//  Task {
//    while !Task.isCancelled {
//      let snapshot = await session.value
//      print("Step \(snapshot.currentStep)/\(snapshot.totalSteps)")
//      try? await Task.sleep(nanoseconds: 500_000_000)  // ~0.5s
//    }
//  }
//  ```
//
//  Polling always sees fresh snapshot—no throttling, no stale data. Consumers
//  control update frequency on their schedule.
//
//  Consumer Patterns:
//  - SuttaCardView (UI): Subscribe to callbacks for state changes; optionally
//    poll for smooth progress indication
//  - Tests: Poll session.value for deterministic progress verification; no timing
//    sleeps needed
//  - Background tasks: Poll on custom schedule; no callbacks required
//  - CLI tools: Poll with custom interval (0.1s, 1s, etc.) per requirements
//
//  ## Performance
//
//  Real-world: thig1.1/en/soma: 9 segments synthesized in 1.79s (200ms avg per
//  segment)
//
//  See: doc/BackgroundAudio.md, doc/AudioStore.md, doc/SuttaPlayer.md
//

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
  var segmentSynthesisTime: Double = 1

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
