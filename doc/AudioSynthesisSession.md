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
- `execute(progressCallback:)` — Entry point: start synthesis for session's sutta
- `cancel()` — Entry point: signal cancellation
- Internal worker loops segments, calls AudioStore.storeAudio(), updates progress:
  - Processes one segment at a time via AudioStore
  - Checks cancellation flag before each segment
  - Halts immediately on error
  - Sends progress callbacks throughout

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

### execute(progressCallback:)

Execute synthesis of all segments.

```swift
func execute(progressCallback: @escaping (IAudioSynthesisManager) -> Void) async
```

**Parameters:**
- `progressCallback`: Called repeatedly with IAudioSynthesisManager state snapshot. Final callback has state != .synthesizing

**Semantics:**
1. Load all segments from sutta via EbtData
2. Return immediately (non-blocking)
3. Session synthesizes segments sequentially on background thread via AudioStore
4. progressCallback fired after each segment with: currentStep, totalSteps, estimatedTimeRemaining, state
5. When synthesis ends (success, error, or cancellation), final callback sent with state indicating outcome

**State transitions during execute():**
- .idle → .synthesizing (at start)
- .synthesizing → .completed (all segments done)
- .synthesizing → .cancelled (user called cancel() during synthesis)
- .synthesizing → .failed(Error) (AudioStore threw)

### cancel()

Cancel active synthesis.

```swift
func cancel() async
```

**Semantics:**
1. Set internal cancellation flag
2. Finish current segment gracefully (AudioStore.storeAudio() completes)
3. Discard remaining pending segments
4. Final callback sent with state = .cancelled

**Idempotent**: Safe to call multiple times or when synthesis already finished.

### IAudioSynthesisManager Protocol

Public readonly interface for progress callbacks:

```swift
protocol IAudioSynthesisManager {
  var state: SynthesisState { get }
  var suttaRef: SuttaRef { get }
  var started: Date { get }
  var currentStep: Int { get }
  var totalSteps: Int { get }
  var audioContext: AudioContext { get }
  var estimatedTimeRemaining: TimeInterval { get }
}
```

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
let session = AudioSynthesisSession(suttaRef: suttaRef)
await session.execute(progressCallback: { state in
  // Update UI with state
})

// Testing with mock audioStore
let testStore = AudioStore.create(path: testDir)
let session = AudioSynthesisSession(suttaRef: testRef, audioStore: testStore)
```

### Thread Safety

Uses Swift `actor` for automatic mutual exclusion. No manual locks needed.

### Error Handling Strategy

**Decision: Halt on first error**

**Rationale:** If AudioStore fails to synthesize a segment, no audio file exists for playback. Continuing synthesis is pointless. Immediately halt and report error.

**Behavior:**
- If `AudioStore.storeAudio()` throws, session catches error and transitions to .failed(error)
- Pending segments are discarded
- Final callback sent with `state = .failed(error)`
- No partial playback scenarios to handle

### Cancellation Handling

- `cancel()` sets internal cancellation flag
- Session synthesis loop checks flag before processing each segment
- Current segment completes (graceful shutdown)
- Pending segments discarded
- Final callback sent with `state = .cancelled`
- Partially synthesized files left in place (not deleted)

## Related Documentation

- `doc/BackgroundAudio.md` — Architecture and UX for background audio
- `doc/AudioStore.md` — Audio file persistence and caching
- `doc/SuttaPlayer.md` — Audio playback integration

## Implementation Status

- [x] Skeleton structure created
- [ ] prepareSuttaAudio() implementation
- [ ] cancelSynthesis() implementation
- [ ] synthesizeWorker() implementation
- [ ] Unit tests
- [ ] Integration tests with AudioStore
