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

## References

- Google Lyra: Neural audio codec at 3 kbps
- Meta Encodec: State-of-the-art neural audio codec
- Apple AVSpeechSynthesizer: Built-in macOS/iOS TTS
- Piper (Mozilla): Lightweight open-source TTS
- ElevenLabs: Advanced voice synthesis
- TensorFlow SoundStream: Trainable neural audio codec
