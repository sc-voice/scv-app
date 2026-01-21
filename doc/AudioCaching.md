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

## Cache Storage Strategy (TBD)

### Questions to Resolve

1. **Storage location**: FileManager cache directory? App documents? Specify path strategy
2. **File naming**: Use cache key as filename? Organize by sutta/segment?
3. **Lifecycle management**: LRU eviction at size limits? TTL-based cleanup? Auto-cleanup on app update?
4. **Error handling**: Re-synthesize if cache file missing? Alert user?

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

### Synthesis Latency Tradeoff

**Current (no cache, direct synthesis)**:
- Play button → AVSpeechSynthesizer → audio in ~50ms per segment

**With on-demand cache**:
- Play button → check cache → cache miss → synthesize + write file → audio in ~100-150ms
- Cache hit → play from file → audio in ~10-20ms

**Background audio workflow** ("Create Background Audio"):
- Menu item → synthesize all segments (100+ segments × 50ms) → 5+ seconds delay
- Then: all replays instant (cache hits)

See: `doc/BackgroundAudio.md` → "UX Impact" for tradeoffs

## Open Questions

1. **When to compute audioContextHash?**
   - At Segment creation?
   - On-demand during playback?
   - Cached in AudioContext once computed?

2. **Where does AudioContext struct live?**
   - Extension on Segment?
   - Separate wrapper type?
   - Part of SuttaPlayer state?

3. **File I/O strategy for synthesis**:
   - Synthesize to memory buffer first, then write?
   - Stream directly to file?
   - Temporary file during synthesis, rename on success?

4. **Fallback behavior**:
   - If cached file corrupted, re-synthesize?
   - If cache miss, synthesize inline or block UI?

## Integration Points

- **SuttaPlayer** — Detects cache hits/misses, switches playback strategy
- **Settings** — Changes invalidate audioContextHash
- **MerkleJson** — Provides deterministic hashing for cache keys
- **FileManager** — Stores/retrieves audio files
- **Background audio workflow** — "Create Background Audio" menu initiates pre-synthesis

## See Also

- `doc/BackgroundAudio.md` — Background playback architecture and constraints
- `doc/SuttaPlayer.md` — Current AVSpeechSynthesizer implementation
- `doc/MerkleJson.md` — Hash algorithm and cache key generation
- `scv-core/Sources/MerkleJson.swift` — Implementation

## Implementation Roadmap (When Pursued)

1. Define AudioContext struct and audioContextHash computation
2. Implement cache storage layer (FileManager wrapper)
3. Add cache hit/miss detection to SuttaPlayer
4. Measure actual synthesis + file write timing (validate UX impact)
5. Implement "Create Background Audio" UI and background synthesis queue
6. Handle cache invalidation when Settings change
7. Test background playback end-to-end
