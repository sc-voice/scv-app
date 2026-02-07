# SuttaPlayer: Text-to-Speech Audio Playback

## Overview

SuttaPlayer.shared is a singleton that orchestrates Text-to-Speech (TTS) audio playback 
for a SuttaCard document. 
It loads a document, extracts segments, and plays them in sequence 
in response to user navigation (jump to segment, pause/resume).

**File**: `scv-ui/Sources/scvUI/SuttaPlayer.swift`

## API

### Initialization

```swift
init(synthesizer: ISpeechSynthesizer = CachedSynthesizer())
```

### Playback Control

#### `func load(_ sutta: MLDocument)`
Load a new document for playback. Extracts segments and resets playback state.

#### `func play()`
Start or resume playback from current position.

#### `func pause()`
Stop playback immediately.

#### `func togglePlayback()`
Toggle between play and pause with debouncing.

#### `func jumpToSegment(scid: String)`
Pause playback and set current segment.

### Observable Properties

```swift
@Published var isPlaying: Bool              // Playback active
@Published var isSynthesizerSpeaking: Bool  // Text-to-speech actively producing audio
@Published var currentSutta: MLDocument?    // Loaded document
@Published var audioContext: AudioContext?  // Current audio context (voice/rate/pitch)
```

### Settings Integration

Playback customizations are defined by `Settings.shared`:

| Setting | Type | Default | Effect |
|---------|------|---------|--------|
| `playDoc` | Bool | true | Skip segments if false |
| `docLangSettings[lang].voiceId` | String | "" | Use specific voice or search |
| `docLangSettings[lang].rate` | Float | 1.0 | Speech rate multiplier |
| `docLangSettings[lang].pitch` | Float | 1.0 | Pitch multiplier |
| `segmentPause` | Float | 0.25 | Delay between segments (pre/post) |


## Implementation

**Design**: SuttaPlayer manages synthesizer directly via `CachedSynthesizer`. Synthesis happens inline during playback, not pre-cached. SuttaPlayer focuses on playback orchestration and segment chaining. See: SuttaPlayer.swift property documentation for private state details.

### Key Invariants

1. **Synthesizer manages synthesis**: CachedSynthesizer handles text-to-speech inline during playback
2. **Direct text playback**: SuttaPlayer calls synthesizer.playText() immediately, no intermediate caching
3. **Main actor isolation**: All public methods are `@MainActor`, preventing concurrency issues
4. **Single AudioContext**: One context per document language, recomputed at play() start
5. **Delegate-based callbacks**: Synthesizer notifies SuttaPlayer via IPlaybackDelegate for segment chaining

### Playback Flow

#### Happy Path: Playing a Sutta

```
1. load(mlDoc)
   └─ Extract segments from document

2. play()
   ├─ Create fresh synthesizer (recovers from failures)
   ├─ Initialize audioContext from currentSutta.docLang
   └─ playSegmentAt(index: 0 or currentScid)
      ├─ Validate isPlaying, index bounds
      ├─ Announce section/segment boundaries
      ├─ Calculate segmentPause delay if needed
      └─ playText(segment.doc, langCode)
         └─ synthesizer.playText(text, audioContext)
            └─ Synthesis begins immediately

3. Synthesizer delegate callbacks (IPlaybackDelegate):
   ├─ onPlaybackStarted()
   │  └─ isSynthesizerSpeaking = true
   │     └─ Cancel pending timeout check
   ├─ onPlaybackFinished()
   │  └─ Set earliestPlaybackTime (respects segmentPause)
   │  └─ playSegmentAt(nextIndexToPlay)  ← Chain to next segment
   │     └─ Repeat playText() or end playback

4. End of document
   ├─ playSegmentAt() guards against out-of-bounds
   ├─ isPlaying = false
   ├─ currentSegmentIndex = 0 (reset)
   ├─ Re-enable idle timer
   └─ Announce .endSutta
```

Synthesis happens inline during playback. No prefetch strategy — segments play sequentially on-demand.

#### Interruption Handling

iOS audio session interruptions (calls, alarms):

```
1. AVAudioSession.interruptionNotification
   ├─ If interrupted: pause() playback
   └─ If resumed with shouldResume:
      └─ configureAudioSession() (re-setup)
```

See: SuttaPlayer.swift:48-88

#### User Jump During Playback

```
1. jumpToSegment(scid: "an1.1.1")
   ├─ Find segment by scid
   ├─ Update currentSegmentIndex
   ├─ pause() current playback
   └─ currentSutta?.currentScid = scid (persists for resume)

2. Next onPlaybackFinished() callback checks isPlaying
   └─ currentSegmentIndex is authoritative, used in playSegmentAt()
```

See: SuttaPlayer.swift:213-225, 350, 419-437

### IPlaybackDelegate Protocol

SuttaPlayer implements **IPlaybackDelegate** to receive playback events from synthesizer. This abstraction decouples SuttaPlayer from AVFoundation implementation details.

All callbacks are @MainActor (safe for UI updates).

See: `scv-ui/Sources/scvUI/ISpeechSynthesizer.swift` for protocol definition.

#### `onPlaybackStarted()`
Synthesis began producing audio.
- Sets `isSynthesizerSpeaking = true`
- Cancels pending timeout check

See: SuttaPlayer.swift:395-407

#### `onPlaybackPaused()`
Synthesis paused (rare, usually caused by user interaction).
- Sets `isSynthesizerSpeaking = false`

See: SuttaPlayer.swift:409-412

#### `onPlaybackContinued()`
Synthesis resumed after pause.
- Sets `isSynthesizerSpeaking = true`

See: SuttaPlayer.swift:414-417

#### `onPlaybackFinished()`
Synthesis completed, segment finished.
- Sets `isSynthesizerSpeaking = false`
- Sets `earliestPlaybackTime` (respects segmentPause)
- If `isPlaying`: calls `playSegmentAt(nextIndexToPlay)` to chain to next segment
- If not playing: ignores (stale callback, user paused or jumped)

See: SuttaPlayer.swift:419-438

**Translation layer**: SpeechSynthesizerImpl implements both AVSpeechSynthesizerDelegate (receives low-level AVFoundation callbacks) and translates to IPlaybackDelegate events (high-level business logic). See: `scv-ui/Sources/scvUI/ISpeechSynthesizer.swift:113-150`

### Testing

#### Mock Synthesizer Pattern

Tests inject `MockSpeechSynthesizer` implementing `ISpeechSynthesizer`:

```swift
let mock = MockSpeechSynthesizer()
let player = SuttaPlayer(synthesizer: mock)
player.play()
assert(mock.speakWasCalled)  // Verify speak() was called
```

## Challenges

### Known Issues and Limitations

* **Synthesis latency** sluggish UX that improves once audio is cached
* **Synthesizer Timeout** Synthesis should complete within 5 seconds
* **Rapid Play/Pause Toggling**  `isTransitioning` flag ignores button mashing

## References

- `scv-ui/Sources/scvUI/SuttaHeaderView.swift` — UI buttons (play/pause, control)
- `scv-ui/Sources/scvUI/ISpeechSynthesizer.swift` — ISpeechSynthesizer protocol definition
- `scv-ui/Sources/scvUI/CachedSynthesizer.swift` — Synthesizer implementation
- `scv-ui/Tests/SuttaPlayerTests.swift` — Test suite
- `scv-ui/Sources/scvUI/AudioEffects.swift` — Sound announcements
- `scv-core/Sources/Settings.swift` — Voice configuration
