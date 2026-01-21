# Audio Caching for Playback

## Overview

Analysis of caching synthesized TTS audio to avoid re-synthesis on replay. Caching was initially an optimization consideration but became an architectural requirement for background playback support.

## Usage Pattern Context

SC-Voice is **song-like** usage (high replay, memorization patterns), not news-like (one-time listening). This makes caching valuable.

## Architecture: Two-Level Hashing

Cache keys are deterministic by hashing an AudioContext struct:

### Level 1: Audio Settings Hash

Hash all audio settings that affect output:
```
audioContextHash = mj.hash({
  voiceId,
  rate,
  pitch,
  segmentPause,
  playDoc,
  playPali,
  ... (any setting affecting audio output)
})
```

**Result**: 32-character hex string representing audio configuration

### Level 2: AudioContext Hash

Hash the complete context:
```
struct AudioContext {
  segment: Segment          // scid, text, docLang, etc.
  audioContextHash: String  // settings hash from Level 1
}

cacheKey = mj.hash(audioContext)
```

**Result**: Unique cache key that changes if segment content OR audio settings change

## Benefits of Two-Level Design

1. **Clean invalidation** — Settings change → audioContextHash changes → new cache key → cache miss
2. **Reusable hashes** — Same audioContextHash used for multiple segments (all using same voice/rate/pitch)
3. **Deterministic keys** — Same segment + same settings = always same cache key (enables S3 parity)
4. **MerkleJson integration** — Uses existing hash algorithm for consistency

See: `MerkleJson.md` for hash algorithm details

## Cache Storage Strategy

### Storage Organization: GuidStore Required

Use GuidStore with dedicated audio volume (See: `doc/GuidStore.md`):

```
Library/Caches/audio-cache/
└── audio/
    ├── abc/
    │   ├── abc123def456.m4a
    │   ├── abc789ghi012.m4a
    │   └── ...
    ├── def/
    │   └── def345jkl678.m4a
    └── ...
```

**Why GuidStore is essential at this scale**:
- EN corpus alone: 148,496 segments
- Multiple voices/settings: 3-5 configurations per language
- **Total realistic cache size: 450k-750k audio files**
- Single-directory filesystem becomes bottleneck at this scale
- GuidStore distributes across ~4,096 subdirectories (3-char hex prefix)
- Result: ~36-180 files per directory (performant)

**Directory structure**:
- **Storage location**: `FileManager.cachesDirectory` (auto-cleaned by OS)
- **Volume**: "audio" (separate from other caches)
- **Chapter**: First 3 chars of cache key (prevents single-dir filesystem bottleneck)
- **Filename**: Full cache key + ".m4a" suffix
- **Persistence**: Survives app launches and updates

### Cache Key Generation

**AudioContext Hash** (implementation detail, scv-core/Sources/AudioContext.swift):
```swift
let audioContext = AudioContext(for: docLang)  // Resolves voice, captures settings
let settingsHash = audioContext.hash()         // 32-char MD5 via MerkleJson
```

**Full Cache Key** (segment + settings combined):
```swift
let mj = MerkleJson()
let cacheKey = mj.hash([
  "scid": segment.scid,
  "text": segment.text,
  "audioContext": audioContext.hash()
])
```

Result: Unique key changes if segment content OR any audio setting changes.

### Implementation Pattern

**1. AudioCache wrapper class**

```swift
class AudioCache {
  private let guidStore: GuidStore

  init() {
    var config = GuidStoreConfig(
      storeName: "audio-cache",
      folderPrefix: 3,
      suffix: ".m4a",
      defaultVolume: "audio"
    )
    let cachesURL = FileManager.default
      .urls(for: .cachesDirectory, in: .userDomainMask)[0]
    config.storePath = cachesURL.appendingPathComponent("audio-cache")
    self.guidStore = GuidStore(config: config)
  }
}
```

**2. Cache operations**

- **Check cache**: `cachedAudioURL(segment, audioContext)` → URL? (nil if file doesn't exist)
- **Store audio**: `cacheAudio(segment, audioContext, data)` → writes file atomically
- **Clear cache**: `clearAudioCache()` async → deletes all .m4a files

### Lifecycle Management

**Cache invalidation**: Automatic when settings change
- User changes voice/rate/pitch → new AudioContext hash → new cache key
- Old files become orphaned but persist on disk
- No explicit invalidation needed

**Cache cleanup**: Not automatic—requires active management
- **OS cleanup insufficient**: iOS/macOS only deletes cache when:
  - Device storage critical (< 500MB free)
  - App uninstalled
  - User manually "Offload App" or "Delete App"
- **Reality**: With 100GB+ device storage, cache persists indefinitely
- **Implication**: Must implement explicit cleanup

**Required: Size limits + LRU eviction**

```swift
// Enforce maximum cache size (e.g., 5GB per language)
func enforceMaxCacheSize(maxBytes: Int64 = 5_000_000_000) {
  let currentSize = cacheSize()
  if currentSize > maxBytes {
    let excessBytes = currentSize - maxBytes
    removeOldestCacheFiles(targetBytes: excessBytes)
  }
}

// Delete oldest files until storage target met
func removeOldestCacheFiles(targetBytes: Int64) {
  // 1. Enumerate all .m4a files in audio volume
  // 2. Sort by modification date (oldest first)
  // 3. Delete until totalSize < targetBytes
  // 4. Log cleanup statistics
}
```

**Manual cleanup**:
- "Clear Audio Cache" settings option
- Calls `clearAudioCache()` to delete all files in audio volume

**Timing**:
- Run `enforceMaxCacheSize()` after synthesis (every ~50ms = negligible)
- Or run once per app launch
- Or run when app backgrounded (prevent UI stutter)

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

**Memory**: Files-only caching, no in-memory buffer except during synthesis (~100KB typical segment)

**Disk scaling**:
- Single segment: ~300KB average per voice
- Full EN corpus (148,496 segments) × 1 voice: ~44GB uncompressed
- Practical cache: Much smaller (users cache subset of suttas)
  - 10 suttas × 100 segments × 300KB × 2 voices = ~600MB
  - 50 suttas (study collection): ~3GB
  - 100+ suttas (full library): ~6GB+
- OS auto-cleans cache directory when device space needed
- Directory distribution critical: 450k-750k files in thousands of subdirectories

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

## Scale Context

**Dataset size**: 148,496 segments in English alone (multiple languages, voices, settings)

**Cache realism**: At peak usage with multiple voice configurations, cache could contain 450k-750k audio files spread across 4,096 subdirectories via GuidStore.

**Critical decision**: Directory distribution via GuidStore is **not optional** at this scale—it's an **architectural requirement** for filesystem performance.

## See Also

- `doc/GuidStore.md` — File storage system architecture (essential for 450k+ file cache at scale)
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

## Implementation Roadmap

**Phase 1: Core caching** (on-demand synthesis + file storage)
1. [ ] Create AudioCache class wrapping GuidStore
2. [ ] Implement cache key generation (segment + AudioContext hash)
3. [ ] Add cache hit/miss detection to SuttaPlayer
4. [ ] Integrate cache check into playback flow (SuttaPlayer.playNextSegment)
5. [ ] Test cache key determinism (same segment+settings = same key)
6. [ ] Test cache invalidation (settings change = different key)

**Phase 2: Size management** (required—OS cleanup insufficient)
7. [ ] Implement `cacheSize()` (enumerate all .m4a files, sum bytes)
8. [ ] Implement `removeOldestCacheFiles()` (LRU eviction by modification date)
9. [ ] Implement `enforceMaxCacheSize()` (delete excess files, maintain limit)
10. [ ] Add "Clear Audio Cache" settings option (calls `clearAudioCache()`)
11. [ ] Add cache cleanup timing (post-synthesis, app launch, or app backgrounding)

**Phase 3: Background playback** (requires pre-synthesis)
12. [ ] Implement preload for background audio (synthesize all segments upfront)
13. [ ] Add "Create Background Audio" menu item (initiates preload)
14. [ ] Measure actual synthesis + file write timing (validate latency trade-off)
15. [ ] Test background playback end-to-end
