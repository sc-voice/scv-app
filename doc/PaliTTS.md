# PaliTTS Architecture

## Overview

The goal of PaliTTS is to synthesize Pali words correctly in multiple languages. This is difficult given that each language only uses a subset of the available phonemes and native speakers often have difficulty pronouncing Pali. This difficulty is compounded by contemporary languages (e.g., en-US) that have drifted further from their contemporary counterparts based in India (e.g., en-IN). To deal with this divergence, we need to have language specific IPA customization for Pali words.

The design for the scVoice Swift PaliTTS implementation originates with 
[the sc-voice.net server](https://github.com/sc-voice/api_sc-voice_net),
which synthesizes text using Amazon Web Services (AWS Polly).
The Swift migration of that codebase is a rewrite explicitly for AVSpeechSynthesizer, 
which has some support for SSML.

## Design Decisions

### Language-Specific IPA Mappings

Rather than per-voice customization (as in the original JavaScript implementation), the Swift migration uses **language-keyed IPA mappings**. Each language has a single "Default" voice configuration that applies to all voices in that language.

**Rationale**:
- The IPA phoneme representation for a given language should be identical regardless of which voice speaks it
- Apple's NL framework provides language detection without requiring massive word dictionaries
- Eliminates redundancy: each language IPA mapping is defined once, not repeated per voice
- Preserves future flexibility: voice-specific customizations can be added later by extending the Default entry

### Voice Customization

Voice customizations are stored in 
`scv-core/Sources/Resources/voices.json`,
which has a default voice for each scVoice document language.
Each voice has a native language, and each voice can have 
custom pronunciation of native words (rare but useful for heteronyms) or
custom pronunciation of Pali words (common).

The ultimate consumer of voices.json configuration is AbstractTts.swift

#### AbstractTts Class

`AbstractTts` is instantiated with a single voice configuration from voices.json.
Each instance corresponds to one voice in one language.
For multiple voices (e.g., English speaker synthesizing both English and Pali text),
you create multiple AbstractTts instances with different configurations.

AbstractTts initialization parameters:
- `language`: The voice's native language (e.g., "en", "pli")
- `localeIPA`: IPA system to use for pronunciation (typically same as language)
- `customWords`: Optional per-word pronunciation overrides
- `syllableVowels`: Optional custom vowel set for syllable detection


#### Voices.json

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

Removed fields from original:
- Per-voice metadata (gender, locale, rates, usages) - not needed for TTS synthesis
- Voice service information (aws-polly, etc.) - handled by platform-specific synthesizers

### Pali class

Since Pali words are pronounced differently than native language words, there is a need to detect
the language of a given word so that we can pronounce it correctly.
The Pali class handles the detection of Pali words via `Pali.shared.isPali()`.
For words with Pali diacritical letters, detection is trivial.
However, some Pali words (e.g., "arahant") have no diacritical marks.
Furthermore, some Pali words (e.g., "me") can also occur in native languages.

The case of words such as "me" and "arahant" serves to illustrate the challenge of pronunciation.
Indeed EN "me" and PLI "me" sound completely different.
Empirically, it turns out that translators tend to avoid using Pali words such as "me" in their own translations in order to avoid reader confusion.
In addition, longer Pali words without diacritcals (e.g., "arahant"),
can simply be treated as custom words with their own IPA.

### Architecture Changes from JavaScript

The original JavaScript implementation (`abstract-tts.cjs`, `words.cjs`) had several responsibilities that are now split:

| Responsibility | Original | Swift Migration |
|---|---|---|
| Language detection | Words class (JSON dict lookups) | Apple NL framework |
| Word dictionary | Massive per-language JSON files | Not needed |
| Tokenization | Words.tokenize() | Not needed for SSML generation |
| IPA customization | Per-voice mappings in voices.json | Language-keyed Default voice |
| Custom word handling | Words.lookup() + customWords | Direct customWords lookup |
