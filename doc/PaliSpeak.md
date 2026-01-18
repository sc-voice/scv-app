# PaliSpeak - English TTS Pronunciation Guide

Mapping Pali words to English phonetic representations for AVFoundation's SpeechSynthesizer.

## Pali Phonology Essentials

Pali uses a **precise vowel system** with phonologically significant distinctions:
- Long vowels take **approximately twice as long** to pronounce as short vowels
- Pali uses **vowel length for stress**, not dynamic stress accent (loudness)
- Syllables with long vowels are emphasized in proper pronunciation

## Vowel System

### Short Vowels (rassa)
- `a` → "uh" (brief, like English "cup")
- `i` → "ih" (brief, like English "sit")
- `u` → "oo" (brief, like English "put")

### Long Vowels (dīgha) - EMPHASIZED
- `ā` → "AH" (holds ~2x longer, like English "father")
- `ī` → "EE" (holds ~2x longer, like English "see")
- `ū` → "OO" (holds ~2x longer, like English "goose")
- `e` → "AY" (simple vowel, not a diphthong)
- `o` → "OH" (simple vowel, not a diphthong)

## Consonant System

### Aspirated Consonants (digraphs with "h")
These are pronounced with a "strong breath pulse," distinct from unaspirated versions:
- `kh` → aspirated k (strong breath + k)
- `gh` → aspirated g (strong breath + g)
- `ch` → aspirated c/ch (strong breath + ch)
- `jh` → aspirated j (strong breath + j)
- `th` → aspirated t (strong breath + t)
- `dh` → aspirated d (strong breath + d)
- `ph` → aspirated p (strong breath + p)
- `bh` → aspirated b (strong breath + b)

### Retroflex Consonants
Pronounced with tongue positioned behind the dental ridge, producing a "characteristic hollow sound":
- `ṭ` → retroflex t (English "t" approximation)
- `ṭh` → retroflex th (English "th" approximation)
- `ḍ` → retroflex d (English "d" approximation)
- `ḍh` → retroflex dh (English "dh" approximation)
- `ṇ` → retroflex n (English "n" approximation)

### Dental Consonants
Normal dental consonants (tongue touches teeth):
- `t`, `th`, `d`, `dh`, `n` → as in English

### Double Consonants
Must be clearly articulated as **two separate sounds**, not merged:
- `mm`, `nn`, `tt`, `ll` etc. → slight pause/separation between the two sounds

## Transcription Rules for English TTS

1. **Syllable Breaking**: Consonants+vowel form syllables (e.g., dhamma = dha-mma, not dham-ma)
2. **Stress Marking**: Capitalize syllables containing long vowels (ā, ī, ū, e, o)
3. **Vowel Pronunciation**: Apply short/long vowel rules above
4. **Consonant Preservation**: Use h-digraphs (kh, dh, th, etc.) as written
5. **Double Consonants**: Write as-is; TTS will interpret as held sound

## Examples from MN 44

### rājagaha (Rājagaha - the capital city)
- **Syllables**: rā-ja-ga-ha
- **Analysis**:
  - rā (long ā) = RAH
  - ja (short a) = yah
  - ga (short a) = gah
  - ha (short a) = hah
- **EN Speak**: `RAH-yah-gah-hah`
- **Stress**: First syllable emphasized (long ā)

### visākha (Visākhā - a person's name)
- **Syllables**: vi-sā-kha
- **Analysis**:
  - vi (short i) = vis
  - sā (long ā) = AHK (with aspirated kh)
  - kha (aspirated) = part of previous syllable
- **EN Speak**: `vis-AHK-uh`
- **Stress**: Second syllable emphasized (long ā + aspirated kh)

### dhammadinnā (Dhammadinnā - a person's name)
- **Syllables**: dha-mma-di-nnā
- **Analysis**:
  - dha (short a, aspirated d) = dah
  - mma (short a, double m) = mm held/separated, then uh = "dahm" combined
  - di (short i) = din
  - nnā (long ā, double n) = nn held/separated, then AH = "NAH" combined
- **EN Speak**: `dahm-muh-din-NAH`
- **Stress**: Final syllable emphasized (long ā)

## Implementation Notes

Store pronunciations in `pali-speak-en.json` as a word-to-pronunciation map with:
- ALL CAPS for syllables with long vowels
- Hyphens separating syllables
- Use with AVSpeechUtterance's `phonetic` attribute or preprocess before synthesis

## References

**Primary Sources:**

1. **Pāli Grammar - Pronunciation Guide**
   - See: https://paligrammar.com/pronunciation/
   - Covers vowel length system with short/long distinctions
   - Explains aspiration and consonant pronunciation patterns
   - Notes precise vowel length ratios (long vowels ~2x short vowels)

2. **The Pronunciation of Pali** (Ancient Buddhist Texts)
   - See: https://ancient-buddhist-texts.net/Textual-Studies/Grammar/The-Pronunciation-of-Pali.htm
   - Comprehensive guide on Pali vowel and consonant systems
   - Documents aspirated consonant pronunciation ("strong breath pulse")
   - Explains retroflex consonants and their "characteristic hollow sound"
   - Guidance on double consonant articulation as two separate sounds
   - Recommendations for learning through group chanting with experienced speakers

**Key Phonological Principles:**

- Pali vowel length operates on approximately 2:1 ratio (short vowels: long vowels in duration)
- Stress is phonologically marked by **vowel length**, not dynamic stress accent (loudness like English)
- This differs from English stress patterns and is essential for proper Pali pronunciation
