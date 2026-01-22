# AudioStore: Persistent TTS Audio Storage

## Overview

AudioStore persists synthesized TTS audio for two critical reasons:

1. **Background playback requirement** — AVSpeechSynthesizer cannot synthesize when app is backgrounded. Background audio requires entire sutta pre-cached.
2. **Battery efficiency** — Synthesis is expensive. Replaying from storage avoids repeated TTS computation.

SC-Voice is **song-like** usage (high replay, memorization patterns). Users often replay same suttas many times with same voice settings, making persistent storage valuable.

## Storage Organization Strategy

Audio files are organized using:
- **AudioContext hash** — Captures voice, rate, pitch, and other synthesis settings (32-char MD5)
- **Segment cache key** — Combines segment content (scid, text) with AudioContext hash (deterministic MD5)

**Design principle**: When user changes voice/rate/pitch → new AudioContext hash → new storage volume → old files automatically orphaned and deletable.

Storage key is deterministic:
- Same segment + same settings = always same key
- Same segment + different settings = different key
- Enables "self-cleaning" when settings change

See: `MerkleJson.md` for hash algorithm details

## Directory Structure

AudioStore uses GuidStore with volume per AudioContext (See: `doc/GuidStore.md`):

```
Library/Caches/audio-store/
├── en-abc123d/  (volume = language-audiocontexthash_prefix, 7 chars of hash)
│   ├── ab/  (chapter = 2-char segment key prefix)
│   │   ├── abc123def456.m4a
│   │   ├── abc789ghi012.m4a
│   │   └── ...
│   ├── cd/
│   │   └── cde456fgh789.m4a
├── en-xyz789a/  (different audiocontext hash = different volume)
│   ├── ab/
│   │   └── ...
└── de-abc123d/
    └── ...
```

**Design**:
- **Volume**: `{language}-{audioContextHash[:7]}` — Language + first 7 chars of audioContext hash
- **Chapter**: 2-char prefix of segment key (GuidStore default)
- **File**: Full segment key + ".m4a"
- **Format**: M4A (AAC codec) — ~7x compression (15KB vs 100KB per segment)

**Self-cleaning on settings change**: User changes voice/rate/pitch → new AudioContext hash → new volume. Old volume becomes orphaned. Call `clearOldAudioContext()` to delete.

## Storage Key Generation

**AudioContext Hash** (implementation detail, scv-core/Sources/AudioContext.swift):
```swift
let audioContext = AudioContext(for: docLang)  // Resolves voice, captures settings
let settingsHash = audioContext.hash()         // 32-char MD5 via MerkleJson
```

**Full Storage Key** (segment + settings combined):
```swift
let mj = MerkleJson()
let storageKey = mj.hash([
  "scid": segment.scid,
  "text": segment.text,
  "audioContext": audioContext.hash
])
```

Result: Unique key changes if segment content OR any audio setting changes.

### Implementation Pattern

**AudioStore class**

```swift
class AudioStore {
  private let guidStore: GuidStore

  init() {
    var config = GuidStoreConfig(
      storeName: "audio-store",
      folderPrefix: 2,  // GuidStore default: 2-char chapter
      suffix: ".m4a",
      defaultVolume: "en"
    )
    let cachesURL = FileManager.default
      .urls(for: .cachesDirectory, in: .userDomainMask)[0]
    config.storePath = cachesURL.appendingPathComponent("audio-store")
    self.guidStore = GuidStore(config: config)
  }

  func storedAudioURL(segment: Segment, audioContext: AudioContext) -> URL? {
    let storageKey = computeStorageKey(segment: segment, audioContext: audioContext)
    let volume = volumeName(lang: audioContext.docLang, hash: audioContext.hash)
    let url = guidStore.guidPath(guid: storageKey, volume: volume, suffix: ".m4a")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  func storeAudio(segment: Segment, audioContext: AudioContext, data: Data) throws {
    let storageKey = computeStorageKey(segment: segment, audioContext: audioContext)
    let volume = volumeName(lang: audioContext.docLang, hash: audioContext.hash)
    let url = guidStore.guidPath(guid: storageKey, volume: volume, suffix: ".m4a")
    try data.write(to: url, options: .atomic)
  }

  func clearOrphanedVolumes(lang: String, currentHash: String) async throws {
    let allVolumes = try await guidStore.listVolumes()
    let currentPrefix = "\(lang)-\(String(currentHash.prefix(7)))"

    // Find old volumes for this language with different hash
    let oldVolumes = allVolumes.filter { volume in
      volume.hasPrefix("\(lang)-") && volume != currentPrefix
    }

    // Delete orphaned volumes
    for volume in oldVolumes {
      let count = try await guidStore.clearVolume(volume)
      // Log: "Deleted orphaned audio volume: \(volume) (\(count) files)"
    }
  }

  private func volumeName(lang: String, hash: String) -> String {
    let hashPrefix = String(hash.prefix(7))  // First 7 chars of audioContext hash
    return "\(lang)-\(hashPrefix)"
  }

  private func computeStorageKey(segment: Segment, audioContext: AudioContext) -> String {
    let mj = MerkleJson()
    return mj.hash([
      "scid": segment.scid,
      "text": segment.text,
      "audioContext": audioContext.hash
    ])
  }
}
```

**Core methods**:
- `storedAudioURL(segment, audioContext)` → URL? (nil if not stored)
- `storeAudio(segment, audioContext, data)` → writes file atomically
- `clearOrphanedVolumes(lang, currentHash)` async → auto-deletes old audio contexts for language

### Lifecycle Management

**Automatic cleanup on settings change**:
- User changes voice/rate/pitch → AudioContext.hash changes → new volume
- On next playback, AudioStore calls `clearOrphanedVolumes(lang, currentHash)`
- Lists all volumes, filters for language, deletes volumes with old hash prefix
- No manual tracking needed

**No LRU, no size limits**: Self-cleaning strategy works because:
- Settings change → new volume → old volumes auto-delete
- No accumulation of orphaned files
- Users typically stick to 1-2 voice configurations

## Critical Constraint: Background Playback

**Simple fact**: AVSpeechSynthesizer cannot synthesize when app is backgrounded.

**Implication**: Audio caching is no longer optional—it's **required** for background playback support.

- Foreground playback: Can synthesize on-demand (current behavior)
- Background playback: **Requires entire sutta cached before app backgrounds**

See: `doc/BackgroundAudio.md` for full analysis

## Use Cases

| Scenario | Benefit | Note |
|----------|---------|------|
| User replays same sutta 3× in a week | Medium | Saves ~300ms total synthesis, but cache invalidated if settings change |
| Study session with voice changes | Low | Each voice config = new cache entries |
| Daily memorization practice | High | Same sutta, same voice, many replays = strong cache hit rate |
| Background playback | **Required** | Entire sutta must be cached upfront before backgrounding |
| Commute listening (new suttas daily) | Low | Each sutta first-play uncached |

## Performance Impact

### Synthesis Latency

| Operation | Time |
|-----------|------|
| AVSpeechSynthesizer synthesis | ~50ms |
| Write to cache file | ~10ms |
| Read from cache file | ~5-10ms |
| Playback start (either source) | ~5ms |

**On-demand caching trade-off**:
- First play: ~60ms (synthesis + write)
- Repeat plays: ~10ms (file read, no re-synthesis)
- Overhead on first play acceptable for significant repeat-play benefit

### Memory & Disk Usage

**Memory**: Files-only caching, no in-memory buffer except during synthesis

**Disk scaling** (M4A with AAC codec):
- Single segment: ~15KB per voice (compressed, ~7x smaller than PCM)
- Full EN corpus (148,496 segments) × 1 voice: ~2.2GB (M4A) vs ~44GB (uncompressed)
- Practical cache: 10-50 suttas with 2-3 voices = 150MB-2GB
- GuidStore distributes files across subdirectories (default 256 dirs, ~1800 files each)

### Background Audio Workflow

"Create Background Audio" menu item (See: `doc/BackgroundAudio.md`):
- Synthesize all segments upfront (100+ segments × 50ms = 5+ seconds)
- User accepts delay once
- All future replays instant (cache hits)
- Enables background playback (required: AVSpeechSynthesizer can't run backgrounded)

## SuttaPlayer Integration

### Playback Flow with Caching

**Current** (no cache):
```
play() → synthesizeSegment() → AVSpeechSynthesizer → ~50ms → playback
```

**With cache**:
```
play() → checkCache()
  ├─ Hit: playAudioFile() → ~5-10ms latency
  └─ Miss: synthesize() → cacheAudio() → playAudioData() → ~60ms latency
```

### Implementation Point

Integrate cache check at `SuttaPlayer.playNextSegment()`:

```swift
func playNextSegment() {
  guard let segment = currentSegment else { return }
  let audioContext = AudioContext(for: segment.docLang)

  // Check cache first
  if let cachedURL = audioCache.cachedAudioURL(segment: segment, audioContext: audioContext) {
    playAudioFile(cachedURL)
    return
  }

  // Synthesize and cache
  synthesizeSegment(segment, audioContext: audioContext) { audioData in
    try? self.audioCache.cacheAudio(segment: segment, audioContext: audioContext, data: audioData)
    self.playAudioData(audioData)
  }
}
```

### AudioContext Computation

**When**: On-demand during playback (SuttaPlayer.playNextSegment)
**Where**: scv-core/Sources/AudioContext.swift (already implemented)
**Caching**: AudioContext is lightweight (5 fields), recomputing on each segment is negligible

## Integration Points

- **SuttaPlayer** — Detects cache hits/misses, switches playback strategy
- **Settings** — Changes invalidate audioContextHash
- **MerkleJson** — Provides deterministic hashing for cache keys
- **FileManager** — Stores/retrieves audio files
- **Background audio workflow** — "Create Background Audio" menu initiates pre-synthesis


## See Also

- `doc/GuidStore.md` — File storage system architecture
- `doc/BackgroundAudio.md` — Background playback architecture and constraints
- `doc/SuttaPlayer.md` — Current AVSpeechSynthesizer implementation
- `doc/MerkleJson.md` — Hash algorithm and cache key generation
- `scv-core/Sources/AudioContext.swift` — AudioContext implementation
- `scv-core/Sources/MerkleJson.swift` — Hash algorithm implementation

## Testing Considerations

### Cache Key Determinism

Cache keys must be identical for same segment + settings (enables S3 parity, test repeatability):

```swift
func testCacheKeyConsistency() {
  let context = AudioContext(for: "en")
  let key1 = cacheKey(for: segment, audioContext: context)
  let key2 = cacheKey(for: segment, audioContext: context)
  XCTAssertEqual(key1, key2)
}
```

### Cache Invalidation

Settings change must produce different cache keys (no false cache hits):

```swift
func testCacheInvalidationOnSettingsChange() {
  let oldContext = AudioContext(for: "en")
  let oldKey = cacheKey(for: segment, audioContext: oldContext)

  settings.rate = 1.5  // Simulate user change

  let newContext = AudioContext(for: "en")
  let newKey = cacheKey(for: segment, audioContext: newContext)

  XCTAssertNotEqual(oldKey, newKey)
}
```

### GuidStore Integration

Verify file storage and retrieval:

```swift
func testAudioCacheStorage() async throws {
  let audioData = Data(/* synthesized audio */)
  try audioCache.cacheAudio(segment: segment, audioContext: audioContext, data: audioData)

  let cached = try audioCache.cachedAudioURL(segment: segment, audioContext: audioContext)
  XCTAssertNotNil(cached)

  let readData = try Data(contentsOf: cached!)
  XCTAssertEqual(readData, audioData)
}
```

## Implementation: Phase 1

1. [ ] Create AudioCache class wrapping GuidStore with M4A storage
2. [ ] Implement cache key generation (segment + AudioContext hash)
3. [ ] Implement `cachedAudioURL()` (check if file exists)
4. [ ] Implement `cacheAudio()` (write synthesized audio atomically)
5. [ ] Implement `clearOldAudioContext()` (delete orphaned volume)
6. [ ] Integrate cache check into SuttaPlayer.playText() (check before synthesis)
7. [ ] Call cacheAudio() after synthesis (fire-and-forget)
8. [ ] Test cache key determinism and invalidation
