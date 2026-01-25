# Pali Text-to-Speech (PailTTS) Investigation

## Objective

Explore AI-based audio compression strategies for a Buddhist sutta corpus (3MB UTF-8 text) to reduce storage and bandwidth requirements while maintaining audio availability.
This analysis is based on the Majjhima Nikaya alone which comprises:

| Value | Unit |
|-------|------|
| 27,347 | lines |
| 294,796 | words |
| 3,072,235 | characters |

The Tipitaka in its entirety is over 17x larger.

## Problem Statement

- Textual corpus: 3MB UTF-8 characters (~500K words, ~58 hours of speech)
- Standard audio encoding (AAC 128kbps): **3.3 GB** storage required
- Need to reduce storage/bandwidth for mobile and offline delivery

## Findings

### Standard Audio Compression Baseline

| Codec | Bitrate | File Size |
|-------|---------|-----------|
| MP3/AAC (low) | 64 kbps | 1.67 GB |
| MP3/AAC (standard) | 128 kbps | **3.35 GB** |
| MP3/AAC (high) | 256 kbps | 6.71 GB |
| Opus (efficient) | 32 kbps | 0.84 GB |

**Calculation basis:**
- 3MB = 3,145,728 bytes
- Average word: 6 bytes (5 chars + space)
- ~524K words ÷ 150 wpm = 3,495 minutes (58.25 hours)
- 58.25 hours × 3,600 sec/hour × bitrate = file size

### AI-Based Compression Approaches

#### 1. Neural Codecs (Most Aggressive Compression)

**Technologies:** TensorFlow SoundStream, Meta Encodec, Google Lyra

**Compression ratio:** 10-100x better than MP3/AAC at equivalent quality

| Codec | Bitrate | Size (3MB corpus) |
|-------|---------|-------------------|
| Google Lyra | 3 kbps | ~12 MB |
| Encodec | 6-24 kbps | ~25-100 MB |
| SoundStream | 10-50 kbps | ~40-200 MB |

**Trade-offs:**
- Requires AI decoder on playback device
- Not yet production-grade for all platforms
- Licensing/availability constraints
- Intelligible speech quality at extreme compression

#### 2. Text-to-Speech Synthesis (Most Practical) ⭐

**Core concept:** Store compressed text + TTS model instead of pre-recorded audio

**Storage breakdown:**
- Text corpus: 3 MB (already UTF-8 compressed)
- TTS model: 50-200 MB (cached on device, one-time download)
- **Total: 50-203 MB** (vs 3.3 GB for AAC)
- **Compression: 94-98% reduction**

**Advantages:**
1. Eliminates massive audio file storage
2. Zero bandwidth for corpus growth (only text downloads)
3. Language-agnostic (single text file, swap TTS model for different language)
4. Supports multiple voices (switch models)
5. Can generate audio on-demand or during idle/WiFi
6. Sync time minimal (text-only deltas)

**Disadvantages:**
1. Original speaker voice cannot be preserved
2. Requires inference time on device (generation latency)
3. TTS quality depends on model selection
4. Requires modern device (model execution capability)

**TTS Model Options:**
- **Apple Native (macOS/iOS):** Built-in AVSpeechSynthesizer, no download required
- **OpenAI TTS:** High quality, requires API/local inference
- **Google Cloud TTS:** Production quality, requires API
- **ElevenLabs:** Advanced voice cloning, requires API
- **Piper (Mozilla):** Open-source, lightweight (~50-100MB models)
- **Bark (Suno AI):** Open-source, multilingual, good quality

#### 3. Hybrid: Semantic Audio Compression

**Concept:** Store high-level audio features (mel-spectrograms) + neural decoder

**Compression:** 1-5% of original PCM size (~15-150 MB for 3MB corpus)

**Trade-offs:**
- Lossy reconstruction quality
- Requires AI inference for playback
- Complex implementation

#### 4. Domain-Specific Neural Codec

**Concept:** Train custom neural codec on representative sutta audio

**Compression:** 20-50% better than generic codecs (~400-1500 MB)

**Trade-offs:**
- Requires training data and ML infrastructure
- One-time training cost
- Codec optimized for Buddhist suttas specifically
- Slower adoption timeline

## Comparison Matrix

| Approach | Storage | Setup | Latency | Reversibility | Complexity |
|----------|---------|-------|---------|---------------|-----------|
| AAC 128kbps | 3.3 GB | None | Immediate | N/A | Low |
| Opus 32kbps | 0.84 GB | None | Immediate | N/A | Low |
| TTS Synthesis | 50-203 MB | Model DL | Generation time | Original voice lost | Medium |
| Neural Codec (Lyra) | 12-100 MB | Model + codec | Decoding latency | Original voice lost | Medium |
| Semantic Compression | 15-150 MB | Model + codec | Decoding latency | Original voice lost | High |
| Domain-Trained Codec | 400-1500 MB | Train + model | Decoding latency | Original voice lost | High |

## Recommendation for SC-Voice

**Text-to-Speech Synthesis** is the optimal choice because:

1. **Dramatic storage reduction:** 94-98% (3.3 GB → ~50-200 MB)
2. **Alignment with existing architecture:** Already manages text corpus
3. **Language support:** Single text, multiple TTS models for different languages
4. **Incremental adoption:** Can phase in TTS alongside existing audio
5. **Platform availability:** Apple's AVSpeechSynthesizer built-in, no download required on iOS/macOS
6. **Future-proof:** Can upgrade TTS quality as models improve

### Implementation Path

**Phase 1: Proof of Concept**
- Use native AVSpeechSynthesizer for macOS/iOS
- Generate sample audio for 1-2 suttas
- Measure quality, latency, device performance
- Verify acceptability vs original recordings

**Phase 2: Production Integration**
- Evaluate higher-quality TTS (Piper, ElevenLabs, or OpenAI)
- Implement audio generation/caching strategy
- Create download fallback for pre-recorded audio
- Add voice selection UI

**Phase 3: Full Deployment**
- Generate audio corpus on-demand
- Implement efficient caching
- Support multiple languages/voices
- Monitor quality feedback

## Open Questions

1. Are original speaker voices required for Buddhist suttas, or is high-quality TTS acceptable?
2. What is acceptable latency for audio generation on first play?
3. Should pre-recorded audio be retained as fallback or fully replaced?
4. Are there licensing concerns with specific TTS providers?
5. What is target device platform (iOS, macOS, web)?

## CAF to M4A Conversion Analysis (2026-01-25)

### Problem Statement

Current AudioStore uses CAF format (uncompressed PCM) for TTS synthesis output. CAF provides fast write but poor compression:
- Single segment: ~85-114KB (CAF)
- Full corpus: ~12.5GB (148K segments × ~85KB)

M4A (AAC codec) provides much better compression:
- Single segment: ~8.5-15KB
- Full corpus: ~1.3-2.2GB (90-95% reduction)

**Question**: Should we convert CAF to M4A after synthesis to reduce storage?

### AVAudioConverter Investigation Results

**Tested approaches**:

1. **AVAudioFile(forWriting:settings:)** with MPEG4AAC
   - ✅ Works, produces valid AAC files
   - ❌ Pre-allocates massive "free" box padding (31KB vs afconvert's 3KB)
   - Result: 37KB file vs optimal 8.7KB (4.3x larger)
   - Root cause: Defensive metadata space pre-allocation, no configuration option

2. **AVEncoderBitRateKey / AVEncoderBitRateStrategyKey**
   - ❌ Causes NSInvalidArgumentException crashes
   - ❌ File corruption when accepted

3. **ExtAudioFile API**
   - ✅ No padding issues are solved (uses same Core Audio framework)
   - Requires unsafe pointer handling for AudioBufferList

4. **Lower-level AudioConverter C API (kAudioConverterEncodeBitRate)**
   - ✅ Supports bitrate control
   - ❌ Only affects audio frame data (mdat), not metadata padding
   - ❌ Not exposed through AVAudioConverter Swift wrapper

5. **M4A Transcoding (read M4A → write M4A)**
   - ❌ Produces corrupted output files
   - AVAudioFile decompresses on read, re-encodes on write, adds padding

### Benchmark: AVAudioConverter vs afconvert (DN10:2.32.2, 1058 chars)

| Metric | AVAudioConverter | afconvert | Difference |
|--------|------------------|-----------|-----------|
| Input (CAF) | 5.3 MB | 5.3 MB | — |
| Output (M4A) | 280 KB (19.15x) | 256 KB (20.91x) | +24 KB (+9%) |
| Conversion time | 0.075s | 0.082s | 8% faster |
| Compression loss | 1.76x ratio | Optimal | 4.3% worse |

**Conclusion**: AVAudioConverter is production-viable despite larger files (8% speed gain, acceptable 9% size tradeoff).

### Architectural Recommendation

**Separate CAF generation from M4A compaction**:
- Stage 1 (synchronous): Synthesize text → CAF file → play immediately
- Stage 2 (async background): CAF → M4A compaction when not needed for playback

**Rationale**:
- Conversion latency (75ms) acceptable for background task
- Avoids blocking playback for uncached audio
- Enables background synthesis (AVSpeechSynthesizer can't run backgrounded)
- Allows user to control when/whether compaction occurs

**Not viable approaches**:
- Real-time M4A encoding during synthesis (adds ~75ms latency)
- Using afconvert subprocess (defeats goal of native frameworks)
- Lower-level C API (complex unsafe pointer handling, only optimizes mdat not padding)

### Implementation Path (Future)

For production deployment:
1. Implement AVAudioConverter CAF→M4A in background task
2. Make M4A compaction optional/deferred (Settings → Storage → "Compress to M4A")
3. Measure user adoption before full mandatory rollout
4. Consider App Group container for background app refresh compatibility

## Implementation Architecture

### Overview

The goal of PaliTTS is to synthesize Pali words correctly in multiple languages. This is difficult given that each language only uses a subset of the available phonemes and native speakers often have difficulty pronouncing Pali. This difficulty is compounded by contemporary languages (e.g., en-US) that have drifted further from their contemporary counterparts based in India (e.g., en-IN). To deal with this divergence, we need language-specific IPA customization for Pali words.

### Language-Specific IPA Mappings

Rather than per-voice customization (as in the original JavaScript implementation), the Swift migration uses **language-keyed IPA mappings**. Each language has a single "Default" voice configuration that applies to all voices in that language.

**Rationale**:
- The IPA phoneme representation for a given language should be identical regardless of which voice speaks it
- Apple's NL framework provides language detection without requiring massive word dictionaries
- Eliminates redundancy: each language IPA mapping is defined once, not repeated per voice
- Preserves future flexibility: voice-specific customizations can be added later by extending the Default entry

### Minimal JSON Structure

The `scv-core/Sources/Resources/voices.json` file contains only fields required by the wordXYZ() methods:

```json
[{
    "name": "Default",
    "language": "pli",
    "ipa": { "pli": { "a": "ɑ", ... } },
    "customWords": { "occupies": { "ipa": "ɒkʊpaɪz" } }
}, {
    "name": "Default",
    "language": "en",
    "ipa": {},
    "customWords": {}
}]
```

**Fields**:
- `name`: Voice identifier (always "Default" for minimal migration)
- `language`: Language code for word context (used in wordIPA lookups)
- `ipa`: Language-keyed object containing character-to-phoneme mappings
- `customWords`: Optional per-word IPA overrides (e.g., foreign words with specific pronunciation)

### Architecture Changes from JavaScript

The original JavaScript implementation (`abstract-tts.cjs`, `words.cjs`) had several responsibilities that are now split:

| Responsibility | Original | Swift Migration |
|---|---|---|
| Language detection | Words class (JSON dict lookups) | Apple NL framework |
| Word dictionary | Massive per-language JSON files | Not needed |
| Tokenization | Words.tokenize() | Not needed for SSML generation |
| IPA customization | Per-voice mappings in voices.json | Language-keyed Default voice |
| Custom word handling | Words.lookup() + customWords | Direct customWords lookup |

## References

- Google Lyra: Neural audio codec at 3 kbps
- Meta Encodec: State-of-the-art neural audio codec
- Apple AVSpeechSynthesizer: Built-in macOS/iOS TTS
- Piper (Mozilla): Lightweight open-source TTS
- ElevenLabs: Advanced voice synthesis
- TensorFlow SoundStream: Trainable neural audio codec
