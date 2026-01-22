# SuttaPlayer: Text-to-Speech Audio Playback

## Overview

`SuttaPlayer` is the main audio playback controller for reading Buddhist suttas (scriptures) aloud using iOS/macOS system text-to-speech. It manages:

- Document loading and segment sequencing
- Text-to-speech synthesis with voice selection and configuration
- Playback state (playing, paused, stopped)
- Audio session management and interruption handling
- Segment navigation and jumping
- Voice settings per language (rate, pitch, voice ID)

**File**: `scv-ui/Sources/scvUI/SuttaPlayer.swift`
**Main Actor**: Runs on main thread only (`@MainActor`)
**Pattern**: Singleton + injection (default uses system synthesizer, tests inject mocks)

## Architecture

### Class Design

```
SuttaPlayer (final, @MainActor, @ObservableObject)
  ├─ audioStore: AudioStore (handles synthesis + caching)
  ├─ audioPlayer: AVAudioPlayer? (plays cached audio files)
  ├─ currentSutta: MLDocument? (@Published)
  ├─ segments: [Segment] (extracted from MLDocument)
  ├─ currentSegmentIndex: Int (tracks playback position)
  ├─ audioContext: AudioContext (recomputed per segment)
  └─ isTransitioning: Bool (prevents rapid play/pause toggling)
```

**Architecture change**: SuttaPlayer no longer manages AVSpeechSynthesizer directly. AudioStore handles all synthesis and caching. SuttaPlayer focuses on playback orchestration and prefetch strategy.

### Key Invariants

1. **AudioStore manages synthesis**: AudioStore handles all text-to-speech and caching
2. **AVAudioPlayer for playback**: SuttaPlayer uses AVAudioPlayer to play cached URLs
3. **Main actor isolation**: All public methods are `@MainActor`, preventing concurrency issues
4. **Prefetch decoupled from playback**: Caller decides when/how to prefetch via AudioStore.storeAudio()
5. **AudioContext per segment**: Recomputed on-demand (lightweight, negligible overhead)

## Public API

### Initialization

```swift
init(synthesizer: ISpeechSynthesizer = AVSpeechSynthesizer())
```

Allows dependency injection for testing. Default uses system text-to-speech.

### Playback Control

#### `func load(_ sutta: MLDocument)`
Load a new document for playback. Extracts segments and resets playback state.
- Stops any current playback
- Resets `currentSegmentIndex` to 0
- Sets `isPlaying = false`

#### `func play()`
Start or resume playback from current position.
- Creates fresh synthesizer (recovers from failures)
- Respects `currentScid` if set, otherwise uses `currentSegmentIndex`
- Enables idle timer suppression on iOS
- Announces `.play` sound effect

#### `func pause()`
Stop playback immediately.
- Calls `synthesizer.stopSpeaking(at: .immediate)`
- Sets `isPlaying = false`
- Re-enables idle timer on iOS
- Announces `.pause` sound effect

#### `func togglePlayback()`
Toggle between play and pause with debouncing.
- Guards against rapid toggling with 500ms transition lock
- Shows error alert if synthesizer fails to start within 500ms
- Prevents user-facing "stuck" states

#### `func jumpToSegment(scid: String)`
Jump to specific segment by ID during playback.
- Updates `currentSegmentIndex`
- Pauses playback (user is navigating)
- Updates `currentSutta?.currentScid` for persistence

### Observable Properties

```swift
@Published var isPlaying: Bool              // Playback active
@Published var isSynthesizerSpeaking: Bool  // Text-to-speech actively producing audio
@Published var currentSutta: MLDocument?    // Loaded document
```

### Singleton Access

```swift
SuttaPlayer.shared  // Global instance with default synthesizer
```

## Playback Flow

### Happy Path: Playing a Sutta

```
1. load(mlDoc)
   └─ Extract segments from document

2. play()
   └─ playSegmentAt(index: 0)
      ├─ Validate isPlaying, index bounds
      ├─ Announce section/segment boundaries
      ├─ audioContext = AudioContext(for: segment.docLang)
      └─ audioStore.storeAudio(text, audioContext) async
         ├─ AudioStore synthesizes (if not cached)
         ├─ AudioStore stores to cache
         └─ Returns playable URL
      └─ AVAudioPlayer.play(url)
      └─ Setup AVAudioPlayer delegate (didFinish → playSegmentAt(next))

3. AVAudioPlayer delegate callbacks:
   ├─ audioPlayerDidFinishPlaying()
   │  └─ playSegmentAt(currentSegmentIndex + 1)  ← Chain to next segment
   │     └─ Repeat storeAudio() + play() or end playback

4. Concurrent prefetch (optional strategy):
   └─ While segment N plays, prefetch segment N+1, N+2
      └─ audioStore.storeAudio(text, audioContext) async (non-blocking)
         └─ Synthesis happens in background, stored for next playback

5. End of document
   ├─ isPlaying = false
   ├─ currentSegmentIndex = 0 (reset)
   └─ Announce .endSutta
```

**Key difference**: AudioStore handles synthesis asynchronously. Caller decides prefetch strategy (lazy, lookahead, or prefetch-all upfront).

### Interruption Handling

iOS audio session interruptions (calls, alarms):

```
1. AVAudioSession.interruptionNotification
   ├─ If interrupted: pause() playback
   └─ If resumed with shouldResume:
      └─ configureAudioSession() (re-setup)
```

### Empty Segment Handling

If a segment has no text content:

```
1. Detect: text.isEmpty
2. Announce .noText sound
3. Schedule playSegmentAt(index + 1) after 500ms delay
   └─ Skip to next non-empty segment
```

### User Jump During Playback

```
1. jumpToSegment(scid: "an1.1.1")
   ├─ Find segment by scid
   ├─ Update currentSegmentIndex
   ├─ pause() current playback
   └─ currentSutta?.currentScid = scid (persists for resume)

2. Next didFinish() uses stale nextIndexToPlay?
   └─ Check: isPlaying && nextIndexToPlay ≠ currentSegmentIndex
   └─ currentSegmentIndex is authoritative, used in playSegmentAt()
```

## Private Implementation Details

### Audio Session Configuration

```swift
private func configureAudioSession()
```

iOS only (macOS: no-op). Sets up audio session for playback:
- Category: `.playback`
- Options: `.duckOthers` (lower other audio while speaking)
- Active: `true`

Handles errors gracefully (logs, continues).

### Synthesizer Recovery

**Moved to AudioStore**: AudioStore now handles AVSpeechSynthesizer recovery.

SuttaPlayer is decoupled from synthesis concerns. If AudioStore.storeAudio() fails:
- AudioStore handles retry logic (or returns error URL for caller to handle)
- SuttaPlayer can implement lookahead prefetch strategies to mitigate latency

### Voice Selection & Dual AudioContexts

**Moved to AudioContext**: Voice selection and audio settings are now captured in AudioContext.

**Dual contexts**: Segments can be in document language (English, German, etc.) or Pali (original). Each needs separate voice configuration.

SuttaPlayer maintains two contexts:
```
docAudioContext = AudioContext(for: segment.docLang)  // e.g., "en", "de"
pliAudioContext = AudioContext(for: "pli")            // Pali original
```

**Playback workflow** (pseudocode):
```
let audioContext = segment.isPali ? pliAudioContext : docAudioContext
let url = await audioStore.storeAudio(text, audioContext)
play(url)
```

**Settings change cleanup**:
```
await audioStore.clearOrphanedVolumes(docAudioContext)
await audioStore.clearOrphanedVolumes(pliAudioContext)
```

AudioContext handles:
1. Voice priority: User config → system default for language
2. Rate/pitch multipliers from Settings
3. Deterministic hash for cache key invalidation on settings change

SuttaPlayer just passes AudioContext to AudioStore, which handles synthesis details.

### Segment Annotation

Lines 289-293: Announce section vs segment boundaries:
- `.0` scids: section boundary (major divisions)
- `.1` scids: segment boundary (regular segments)
- Helps listeners understand document structure

### State Tracking: nextIndexToPlay

**Problem**: User jumps to segment while `didFinish()` callback is queued. Stale callback uses old nextIndexToPlay.

**Solution**: Update `nextIndexToPlay` before queuing callback
```swift
nextIndexToPlay = index + 1  // Set before synthesizer.speak()
// Later...
didFinish() {
  playSegmentAt(at: nextIndexToPlay)  // Uses updated value
}
```

Relies on `isPlaying` to filter stale callbacks.

## AVSpeechSynthesizerDelegate Callbacks

All callbacks are `nonisolated` (run on audio thread), then dispatch to MainActor for UI updates.

### `speechSynthesizer(_:didStart:AVSpeechUtterance)`
Synthesis began producing audio.
- Sets `isSynthesizerSpeaking = true`

### `speechSynthesizer(_:didPause:AVSpeechUtterance)`
Synthesis paused (rare, usually caused by user interaction).
- Sets `isSynthesizerSpeaking = false`

### `speechSynthesizer(_:didContinue:AVSpeechUtterance)`
Synthesis resumed after pause.
- Sets `isSynthesizerSpeaking = true`

### `speechSynthesizer(_:didFinish:AVSpeechUtterance)`
Synthesis completed, segment finished.
- Sets `isSynthesizerSpeaking = false`
- If `isPlaying`: calls `playSegmentAt(nextIndexToPlay)` to chain to next segment
- If not playing: ignores (stale callback, user paused or jumped)

## Error Handling

### Speech Synthesis Failures

**Detection** (line 123-133):
- 500ms after `play()`, if `!synthesizer.isSpeaking` but `isPlaying`:
  - Shows iOS alert: "Speech problems - Close and reopen scVoice"
  - Calls `resetSynthesizer()`

**Recovery** (line 231-257):
```swift
resetSynthesizer()
  ├─ Save: wasPlaying, currentSegmentIndex, currentSutta
  ├─ Create new synthesizer instance
  ├─ Reconfigure audio session
  └─ Resume playback if was playing (same segment)
```

### Audio Session Configuration Failures

Line 88-91: Logged but non-fatal. Playback may still work with degraded audio.

### Empty Segments

Skipped automatically with 500ms delay. Listener doesn't notice.

### Out-of-bounds Jump

Line 267-278: Gracefully ends playback instead of crashing.

## Testing Considerations

### Mock Synthesizer Pattern

Tests inject `MockSpeechSynthesizer` implementing `ISpeechSynthesizer`:

```swift
let mock = MockSpeechSynthesizer()
let player = SuttaPlayer(synthesizer: mock)
player.play()
assert(mock.speakWasCalled)  // Verify speak() was called
```

### Mock Preservation Fix (Jan 20, 2026)

**Issue**: Line 147 created real synthesizer, discarding mock
**Fix**: Check type before recreating
```swift
if synthesizer is AVSpeechSynthesizer {
  synthesizer = AVSpeechSynthesizer()  // Only for real, not mocks
}
```

This allows tests to pass mocks and verify delegate calls without side effects.

### Test File

`scv-ui/Tests/scvUITests.swift`:
- `suttaPlayerUpdatesCurrentScidWhenPlayingSegment()` — ✅ Now passing
- `suttaPlayerJumpToSegmentWhilePlaying()` — Segment navigation
- Other UI integration tests

## Known Issues and Limitations

### 1. Synthesizer Timeout: 500ms

**Status**: Known limitation
**See**: CLAUDE.md backlog → "Fix SuttaPlayer audio synthesis timeout"

- AVSpeechSynthesizer sometimes fails to start after 500ms
- Error code: kAudioDevicePropertyMute 2003332927
- Causes: Audio device mute state, session config issues, race conditions
- Current workaround: Timeout detection + alert + reset

**Impact**: User must close and reopen app occasionally

### 2. Rapid Play/Pause Toggling

Line 123: 500ms debounce prevents user from rapidly toggling playback.
- Avoids synthesizer state corruption
- May feel unresponsive if user mashes button quickly
- Trade-off: Stability over immediate responsiveness

### 3. iOS Only Features

- `UIApplication.shared.isIdleTimerDisabled` (prevents screen lock during playback)
- Audio session interruption handling
- `UIAlertController` for error alerts

macOS: Gracefully skipped with comments.

### 4. Idle Timer Restoration

If playback interrupted mid-segment (phone call), idle timer re-enabled correctly.
Edge case: If app killed before `pause()` called, timer not restored.

## Settings Integration

Voice configuration comes from `Settings.shared`:

| Setting | Type | Default | Effect |
|---------|------|---------|--------|
| `playDoc` | Bool | true | Skip segments if false |
| `docLangSettings[lang].voiceId` | String | "" | Use specific voice or search |
| `docLangSettings[lang].rate` | Float | 1.0 | Speech rate multiplier |
| `docLangSettings[lang].pitch` | Float | 1.0 | Pitch multiplier |
| `segmentPause` | Float | 0.25 | Delay between segments (pre/post) |

See: `scv-core/Sources/Settings.swift`

## Performance

- **Synthesizer creation**: ~50-100ms (why fresh instance on each play())
- **Voice search**: ~10ms (filtered + sorted by quality)
- **Segment chain**: Async, no blocking I/O
- **Memory**: One synthesizer + utterance buffers (AVFoundation managed)

## Dependencies

- **scvCore**: MLDocument, Segment, Settings, ScvLanguage, AudioContext, AudioStore, ColorConsole
- **AVFoundation**: AVAudioPlayer, AVAudioSession (SuttaPlayer only)
  - AVSpeechSynthesizer moved to AudioStore
- **UIKit** (iOS only): UIApplication, UIAlertController, UIWindowScene

## See Also

- `scv-ui/Sources/scvUI/SuttaHeaderView.swift` — UI buttons (play/pause, control)
- `ISpeechSynthesizer` protocol — Abstraction for testing
- `scv-ui/Tests/scvUITests.swift` — Test suite
- `AudioEffects.swift` — Sound announcements
- `Settings.swift` — Voice configuration
