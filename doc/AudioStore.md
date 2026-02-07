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
- `AudioStore.create(path: URL?, type: AudioType = .caf)` — Test factory with isolated paths

**Core methods**:

1. **`audioUrl(text: String, audioContext: AudioContext, forceUrl: Bool = false) -> URL?`**
   - Returns audio file URL based on forceUrl parameter
   - `forceUrl=true`: Return URL even if file doesn't exist
   - `forceUrl=false`: Return URL only if cached, nil otherwise

2. **`storeAudio(text: String, audioContext: AudioContext, timeout: TimeInterval?) async throws -> URL`**
   - Synthesizes text via AVSpeechSynthesizer (0.23s–0.82s per segment)
   - Stores CAF file atomically via GuidStore
   - Returns immediately if file already cached
   - Throws on synthesis timeout or write failure

3. **`compactContextVolumes(context: AudioContext) async -> CompactionStatus`**
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
play(url)
```

**Batch synthesis** (background playback):

For pre-synthesizing entire suttas, use **AudioSynthesisSession** to queue all segments before user backgrounds app. See: `doc/AudioSynthesisSession.md`

## Performance

| Operation | Time |
|-----------|------|
| AVSpeechSynthesizer synthesis | ~50ms |
| Write to cache | ~10ms |
| Read from cache | ~5-10ms |
| File size (CAF, single segment) | 70-114KB |

**Disk scaling** (M4A with AAC, 7x compression):
- Single segment: ~15KB per voice
- Full EN corpus (148,496 segments) × 1 voice: ~2.2GB (M4A) vs ~44GB (uncompressed)
- Typical cache: 10–50 suttas with 2–3 voices = 150MB–2GB

## Testing

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

**Lifecycle verification** (cleanup on settings change):
- User changes voice/rate/pitch → AudioContext hash changes → new volume
- Old volume becomes orphaned (can call `compactContextVolumes()` to delete)
- No LRU or size limits needed; self-cleaning strategy sufficient for typical usage

## Integration Points

- **CachedSynthesizer** — Calls `storeAudio()` to synthesize and cache
- **AudioSynthesisSession** — Uses AudioStore for batch synthesis (background playback)
- **Settings** — Voice/rate/pitch changes invalidate audioContextHash
- **MerkleJson** — Provides deterministic hashing for cache keys
- **GuidStore** — File organization and storage management

## Related Docs

- `doc/AudioSynthesisSession.md` — Batch synthesis orchestrator
- `doc/BackgroundAudio.md` — Background playback architecture
- `doc/GuidStore.md` — File storage architecture
- `doc/MerkleJson.md` — Hash algorithm and cache key generation
- `scv-core/Sources/AudioContext.swift` — AudioContext implementation

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
