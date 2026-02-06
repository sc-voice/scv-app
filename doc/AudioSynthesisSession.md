# AudioSynthesisSession

## Overview

AudioSynthesisSession (ASS) is a single-use session for background audio synthesis of one sutta. Each synthesis job creates a new session that orchestrates segment-by-segment synthesis via a producer-consumer pipeline pattern.

**Actors:**
- **End User**: Initiates session with `execute(progressCallback:)`, receives progress updates
- **AudioSynthesisSession**: Orchestrates synthesis, manages work queue, handles cancellation
- **AudioStore**: Persistent audio cache for application support (CAF and M4A files)

## Design Rationale

### Separation of Concerns

- **AudioSynthesisSession**: Orchestrates synthesis work, manages queues, handles cancellation
- **AudioStore**: Handles file persistence (CAF/M4A storage and retrieval)
- **AudioSynthesisSession does NOT synthesize audio directly** — it delegates to AudioStore

Session queues segments and calls AudioStore.storeAudio() for each. AudioStore handles actual synthesis via AVSpeechSynthesizer and file I/O.

### Threading Model

- **End User** (main thread): Calls `execute(progressCallback:)` and `cancel()`
- **AudioSynthesisSession** (background thread via actor): Runs synthesis loop, updates progress
- **Thread safety**: Swift `actor` provides automatic isolation
- **Progress callbacks**: Posted back to caller from background work

**API Design:**
- `execute() async -> SessionSnapshot` — Start synthesis, returns final snapshot (.completed, .cancelled, or .failed)
- `cancel() -> SessionSnapshot` — Signal cancellation, returns current snapshot
- Internal synthesis loop:
  - Processes one segment at a time via AudioStore
  - Checks cancellation flag before each segment
  - Halts immediately on error
  - Calls `updateSnapshot()` after each state change, which fires progress callback

### Pipeline Pattern

```
User calls execute() → Session queues segments → AudioStore synthesizes → caches files
                                                                              ↓
                                                                Progress callbacks → UI
```

**Key characteristics:**
- **Single-use**: Each session is tied to one sutta ref; create new session for different sutta
- **Immutable**: Session state initialized on creation, only updated during execute()
- **Persistence**: Audio files survive app restarts
- **Cancellation**: User can cancel mid-batch via cancel()
- **Sequential**: Session processes one segment at a time via AudioStore
- **Progress**: Callback informs UI of progress (currentStep, totalSteps, ETA, completion state)

## API

### Session Initialization

Create a new session for a sutta:

```swift
let session = AudioSynthesisSession(
    suttaRef: SuttaRef,
    audioContext: AudioContext?,  // Optional; defaults to Settings.docLang
    audioStore: AudioStore?        // Optional; defaults to AudioStore.shared
)
```

**Parameters:**
- `suttaRef`: Sutta reference (e.g., SuttaRef.create("DN33/en/sujato"))
- `audioContext`: Audio settings (voice, pitch, rate). If nil, uses current document language
- `audioStore`: Dependency injection for testing. If nil, uses production singleton

**Immutable state after init:**
- `suttaRef`: Sutta to synthesize (tied to session)
- `audioContext`: Audio settings for all segments
- `started`: Timestamp when execute() called
- `currentStep`: Incremented during synthesis (0 = not started)
- `totalSteps`: STEP_INITIALIZE + totalSegments
- `estimatedTimeRemaining`: Computed from elapsed time and progress

### execute()

Execute synthesis of all segments.

```swift
func execute() async -> SessionSnapshot
```

**Return:**
- `SessionSnapshot`: Final snapshot showing completion state (.completed, .cancelled, or .failed)

**Semantics:**
1. Guard: Reject if state ≠ .idle → set .failed state, call `updateSnapshot()` (fires callback), return snapshot
2. Set state = .synthesizing, call `updateSnapshot()` (fires callback)
3. Load all segments via `loadSuttaSegments()` → calls `updateSnapshot()` after loading
4. Synthesize segments sequentially (while state == .synthesizing && pendingSegments not empty):
   - Check if state == .cancelled → exit loop, return snapshot
   - Extract segment text using `segmentKey` ("pli" or "doc")
   - If text blank → call `incrementSynthesisState()` (increments step, calls `updateSnapshot()`), continue
   - Synthesize via `AudioStore.storeAudio()`:
     - Success → call `incrementSynthesisState()`, continue
     - Error → set state = .failed, call `updateSnapshot()`, return snapshot
5. After loop: if state == .synthesizing → set state = .completed, call `updateSnapshot()`, return snapshot
6. Otherwise return current snapshot (state == .cancelled)

**State transitions during execute():**
- .idle → .synthesizing (at start)
- .synthesizing → .completed (all segments processed)
- .synthesizing → .cancelled (user called cancel() during synthesis)
- .synthesizing → .failed(String) (AudioStore threw on non-blank segment)
- .idle → .failed(String) (rejected: already executing or previously completed)

### cancel()

Cancel active synthesis.

```swift
func cancel() -> SessionSnapshot
```

**Return:**
- `SessionSnapshot`: Current snapshot with state = .cancelled

**Semantics:**
1. Set state = .cancelled
2. Call `updateSnapshot()` (fires callback)
3. Return current snapshot
4. Synthesis loop checks state == .cancelled before each segment and exits gracefully
5. Current segment completes (if in progress), remaining pending segments discarded

**Idempotent**: Safe to call multiple times or when synthesis already finished.

### SessionSnapshot

Public readonly interface for progress callbacks:

```swift
public struct SessionSnapshot: Sendable {
  let state: SynthesisState
  let suttaRef: SuttaRef
  let started: Date
  let currentStep: Int
  let totalSteps: Int
  let audioContext: AudioContext
  let estimatedCompletion: Date
  let currentSegment: Segment?
  let segmentKey: String
}
```

**Fields:**
- `state`: Current synthesis state (.idle, .synthesizing, .completed, .cancelled, .failed)
- `suttaRef`: Sutta reference for this session
- `started`: Timestamp when execute() was called
- `currentStep`: Current step (0 = not started, incremented as segments complete)
- `totalSteps`: Total steps (STEP_LOAD_SEGMENTS + totalSegments)
- `audioContext`: Audio settings (language, voice, pitch, rate)
- `estimatedCompletion`: Estimated completion time based on progress at snapshot creation
- `currentSegment`: First pending segment (nil if all processed)
- `segmentKey`: "pli" or "doc" - determines which Segment property is being synthesized

**State field semantics:**
- `.idle`: Session created, execute() not called
- `.synthesizing`: Synthesis in progress
- `.completed`: All segments synthesized successfully
- `.cancelled`: User called cancel() during synthesis
- `.failed(Error)`: AudioStore threw error, synthesis halted

## Implementation Notes

### Dependency Injection

```swift
// Production
let suttaRef = SuttaRef.create("DN33/en/sujato")!
let finalSnapshot = await AudioSynthesisSession(
  suttaRef,
  progressCallback: { snapshot in
    // Update UI with progress
    print("Step \(snapshot.currentStep)/\(snapshot.totalSteps)")
    print("Estimated completion: \(snapshot.estimatedCompletion)")
  }
).execute()

// Final state available in finalSnapshot
switch finalSnapshot.state {
case .completed:
  print("All segments synthesized")
case .cancelled:
  print("Synthesis cancelled")
case .failed(let error):
  print("Synthesis failed: \(error)")
default:
  break
}

// Testing with custom audioStore
let testStore = AudioStore.create(path: testDir)
let testSnapshot = await AudioSynthesisSession(
  testRef,
  progressCallback: { _ in },
  audioStore: testStore
).execute()
```

### Thread Safety

Uses Swift `actor` for automatic mutual exclusion. No manual locks needed.

### Error Handling Strategy

**Decision: Halt on first error, skip blank segments gracefully**

**Rationale:** AudioSynthesisSession is called from Background Playback menu to synthesize partial suttas. Some segments may have no text in the selected language. These should be skipped silently to allow synthesis to proceed with available content.

**Behavior:**
- Blank segments (the Segment property selected by segmentKey is nil or empty): skip synthesis, increment progress, continue to next segment
- If `AudioStore.storeAudio()` throws for non-blank segment: session catches error and transitions to .failed(error)
- Pending segments are discarded on error
- Final callback sent with `state = .failed(error)` on error or `state = .completed` if all available segments synthesized
- Partial playback supported: synthesized segments playable even if some segments were blank or synthesis was cancelled

### Cancellation Handling

- `cancel()` sets internal cancellation flag
- Session synthesis loop checks flag before processing each segment
- Current segment completes (graceful shutdown)
- Final callback sent with `state = .cancelled`
- Cancellation stops all synthesis in that single-use session

### Resume Capability (Implicit via Idempotent Caching)

AudioSynthesisSession does not provide explicit pause/resume API (`pause()`, `resume()`).

**Resume is implicitly supported through idempotent caching:**
1. User initiates synthesis (long-press, menu item, or API call)
2. Session synthesizes segments and caches audio via AudioStore.storeAudio()
3. User backgrounds app mid-synthesis → cancellation via dismissal or app background
4. Later, user re-triggers synthesis for same sutta
5. New session loads segments again, calls AudioStore.storeAudio() for each
6. AudioStore returns cached files for already-synthesized segments (no re-synthesis cost)
7. Session only synthesizes remaining uncached segments
8. User perceives seamless "resume"

**Design advantage**: No session state persistence needed. Caching layer handles resume transparently. Sessions remain single-use and immutable.

### SwiftUI Integration

**Actor references in @State**: AudioSynthesisSession is a reference type (actor). It is `Sendable` and can be held safely in SwiftUI @State:

```swift
struct SuttaCardView: View {
  @State var backgroundSession: AudioSynthesisSession?
  @State var showSynthesisModal = false
  @State var currentSnapshot: SessionSnapshot?

  // Long-press on play button initiates synthesis
  var body: some View {
    Button(action: { startSynthesis() }) { ... }
      .onLongPressGesture { startSynthesis() }
  }

  private func startSynthesis() {
    guard let suttaRef = suttaRef else { return }

    // Create session with callback for progress updates
    backgroundSession = AudioSynthesisSession(
      suttaRef,
      progressCallback: { snapshot in
        // Thread safety: callback fires on background actor thread
        // Marshal UI updates to main thread via DispatchQueue.main.async
        DispatchQueue.main.async {
          self.currentSnapshot = snapshot
        }
      }
    )

    showSynthesisModal = true

    // Execute synthesis on background thread via Task/await
    Task {
      let finalSnapshot = await backgroundSession?.execute()
      // Synthesis complete; finalSnapshot contains final state
    }
  }

  private func cancelSynthesis() {
    // Safely call cancel() on actor via Task/await
    Task {
      await backgroundSession?.cancel()
    }
  }

  // Clean up on view dismissal to prevent orphaned synthesis
  .onDisappear {
    Task {
      await backgroundSession?.cancel()
    }
  }
}
```

**Key patterns:**

1. **Hold actor in @State**: Actors are reference types and `Sendable`, safe for @State
2. **Call async methods via Task/await**: All actor methods (`execute()`, `cancel()`) require `await`
3. **Thread marshaling in callback**: progressCallback fires on background actor thread. Use `DispatchQueue.main.async { self.property = value }` to update @State
4. **Cleanup on view dismissal**: Call `await backgroundSession?.cancel()` in `.onDisappear` to prevent orphaned synthesis tasks

## Related Documentation

- `doc/BackgroundAudio.md` — Architecture and UX for background audio
- `doc/AudioStore.md` — Audio file persistence and caching
- `doc/SuttaPlayer.md` — Audio playback integration

## Implementation Status

Implemented and tested per design. Full `execute()` synthesis loop with state machine, segment iteration, error handling, and cancellation support. Comprehensive unit tests verify init, loadSuttaSegments, and cancel behavior. Integration test validates full workflow with thig1.1/en/soma: 9 segments synthesized in 1.79 seconds (average 200ms per segment), with all callbacks fired and state transitions verified.
