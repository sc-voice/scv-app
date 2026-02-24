# AudioStore: Persistent TTS Audio Storage

## Overview

AudioStore synthesizes and stores TTS audio for individual text segments.
The stored audio reduces power consumption and can be replayed at any time
in foreground or background.
Audio file names are hashes computed from (text, AudioContext).
AudioStore is a cache that is critical for the application,
and is stored by default in: `Library/Application Support/audio-store/`

See: `doc/BackgroundAudio.md`, `doc/GuidStore.md`

## API

**Initialization**:
- `AudioStore.shared` — Production singleton (Library/Application Support/audio-store)
- `AudioStore.create(path: URL?, type: AudioType = .caf, timeout: TimeInterval = 5, adapter: IAVAdapter? = nil) -> AudioStore`
  - `path`: Custom storage directory (defaults to Library/Application Support/audio-store)
  - `type`: Audio format (.caf or .m4a), defaults to .caf
  - `timeout`: Synthesis timeout in seconds (default 5s), raises error if exceeded
  - `adapter`: Dependency injection for AVFoundation adapter (defaults to AVAdapter()); used for testing with MockAVAdapter

**Core methods**:

1. **`audioUrl(text: String, audioContext: AudioContext, forceUrl: Bool = false) -> URL?`**
   - Returns audio file URL based on forceUrl parameter
   - `forceUrl=true`: Return URL even if file doesn't exist
   - `forceUrl=false`: Return URL only if cached, nil otherwise

2. **`storeAudio(text: String, audioContext: AudioContext, timeout: TimeInterval? = nil) async throws -> URL`**
   - Synthesizes text via adapter (AVSpeechSynthesizer or MockAVAdapter)
   - Stores CAF file atomically via GuidStore
   - Returns immediately if file already cached
   - For `.m4a` type: Returns CAF URL immediately, starts background M4A conversion
   - Throws on synthesis timeout or write failure
   - Rejects empty text with error

3. **`diskSize() async -> Int`**
   - Calculates total disk size of all audio volumes in bytes
   - Returns 0 if store doesn't exist or calculation fails

4. **`clearAllAudio() async -> Int`**
   - Deletes all volumes and audio files
   - Returns count of volumes deleted
   - Used for disk space reclamation or cache reset

5. **`compactContextVolumes(context: AudioContext) async -> CompactionStatus`** ⚠️ *Conditional feature*
   - **Note:** Only available when compiled with `COMPACT_CONTEXT_VOLUMES` flag (currently disabled)
   - Deletes volumes from previous audio contexts
   - Filters by language + hash prefix
   - Call after voice/rate/pitch changes
   - Returns: volumesScanned, volumesDeleted, volumesKept, elapsedSeconds

## Usage

**Typical usage** (via CachedSynthesizer):

```swift
// Check cache (optional)
if let url = audioStore.audioUrl(text, audioContext) {
  play(url)
  return
}

// Synthesize + store
let url = await audioStore.storeAudio(text, audioContext)
// For .m4a type: url is CAF (playable immediately)
// Background conversion to M4A starts automatically
play(url)
```

**Testing with mock adapter**:

```swift
// Production: uses real AVSpeechSynthesizer
let store = AudioStore.shared

// Testing: uses fast MockAVAdapter (copies test audio file)
let mockStore = AudioStore.create(adapter: MockAVAdapter())
```

**Batch synthesis** (background playback):

For pre-synthesizing entire suttas, use **AudioSynthesisSession** to queue all segments before user backgrounds app. See: `doc/AudioSynthesisSession.md`

## Performance

| Operation | Time | Notes |
|-----------|------|-------|
| AVSpeechSynthesizer synthesis | Varies | Depends on text length and voice |
| Write to cache (GuidStore) | ~10ms | Atomic, includes directory creation |
| Read from cache | ~5-10ms | File exists check + filesystem lookup |
| MockAVAdapter (test) | <1ms | Copies pre-recorded test audio |
| File size (CAF, short segment) | 85-114KB | Varies by voice and text length |
| File size (CAF, long segment) | ~5.4MB | Example: dn10:2.32.2 (1058 chars) |
| M4A conversion | ~0.3s | AVAudioConverter, ~7x compression ratio |

**Disk scaling** (M4A with AAC, 7x compression):
- Single short segment: ~12-16KB per voice (compressed)
- Single long segment (1000+ chars): ~700KB per voice (compressed)
- Full EN corpus (148,496 segments) × 1 voice: ~2.2GB (M4A) vs ~44GB (CAF uncompressed)
- Typical cache: 10–50 suttas with 2–3 voices = 150MB–2GB

**M4A Pipeline**:
- `storeAudio()` returns CAF URL immediately (playable)
- Background task converts CAF→M4A asynchronously (non-blocking)
- CAF is deleted when next `storeAudio()` call returns M4A
- Users can play audio while conversion happens in background

## Testing

**Using MockAVAdapter**:

MockAVAdapter is a public testing utility in scvCore that enables fast unit tests without real audio synthesis:
- Copies pre-recorded test audio (`scv-core/Tests/Data/test-audio.caf`) instead of synthesizing
- Simulates playback state in memory (no real AVAudioPlayer)
- Allows manual delegate triggering for testing event sequences
- Test synthesis: <1ms (vs ~50-200ms real synthesis)
- Available to all packages (scv-core, scv-ui, etc.)

Enable in tests:
```swift
import scvCore

// In scv-core tests
let MOCK_AV = true  // or false for real AVAdapter
let store = AudioStore.create(
  adapter: MOCK_AV ? MockAVAdapter() : AVAdapter()
)

// In scv-ui tests (similar approach)
let audioStore = AudioStore.create(adapter: MockAVAdapter())
```

All 540 tests in scv-core pass with MockAVAdapter enabled.

**Cache key determinism**:
```swift
let context = AudioContext(for: "en")
let key1 = cacheKey(for: segment, audioContext: context)
let key2 = cacheKey(for: segment, audioContext: context)
XCTAssertEqual(key1, key2)  // Same settings → same key
```

**Cache invalidation on settings change**:
```swift
let oldContext = AudioContext(for: "en")
let oldKey = cacheKey(for: segment, audioContext: oldContext)

settings.rate = 1.5  // User change

let newContext = AudioContext(for: "en")
let newKey = cacheKey(for: segment, audioContext: newContext)
XCTAssertNotEqual(oldKey, newKey)  // Different settings → different key
```

**Lifecycle verification** (cleanup on settings change) ⚠️ *Conditional feature*:
- User changes voice/rate/pitch → AudioContext hash changes → new volume
- Old volume becomes orphaned
- `compactContextVolumes()` can delete orphaned volumes (if `COMPACT_CONTEXT_VOLUMES` flag enabled)
- No LRU or size limits needed; self-cleaning strategy sufficient for typical usage

## Integration Points

- **CachedSynthesizer** — Calls `storeAudio()` to synthesize and cache
- **AudioSynthesisSession** — Uses AudioStore for batch synthesis (background playback)
- **Settings** — Voice/rate/pitch changes invalidate audioContextHash
- **MerkleJson** — Provides deterministic hashing for cache keys
- **GuidStore** — File organization and storage management
- **IAVAdapter** — Protocol for audio synthesis/playback (enables AVAdapter or MockAVAdapter)
  - **AVAdapter** — Production: wraps AVSpeechSynthesizer and AVAudioPlayer
  - **MockAVAdapter** — Testing: copies test audio file for fast unit tests

## Related Docs

- `doc/AudioSynthesisSession.md` — Batch synthesis orchestrator
- `doc/BackgroundAudio.md` — Background playback architecture
- `doc/GuidStore.md` — File storage architecture
- `doc/MerkleJson.md` — Hash algorithm and cache key generation
- `scv-core/Sources/AudioContext.swift` — AudioContext implementation
- `scv-core/Sources/AVAdapter.swift` — Production audio adapter
- `scv-core/Sources/MockAVAdapter.swift` — Public testing audio adapter (copies test audio, available to all packages)

## Storage Design (Internal)

**Volume structure** (via GuidStore):
```
Library/Application Support/audio-store/
├── en-abc123d/           (language-audioContextHash[:7])
│   ├── ab/               (2-char prefix of segment key)
│   │   ├── abc123def.m4a
│   │   └── ...
├── en-xyz789a/           (different audioContext hash)
└── de-abc123d/
```

**Storage key** (deterministic MD5 of text + audioContext):
- Same text + same settings = same key
- Same text + different settings = different key
- Enables self-cleaning on settings change

**Lifecycle**:
- User changes voice/rate/pitch → new AudioContext hash → new volume
- Old volumes automatically become orphaned
- Call `compactContextVolumes()` to delete orphaned volumes
