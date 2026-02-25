# scv-core Module

The scvCore module is the bottom layer of the scVoice application codebase.
As the bottom layer, scvCore focuses on non-UI application concerns:

* Text-to-speech (TTS)
* Content database (CDB)
* User preferences (PREF)
* Debug logging (LOG)
* Localization (LOC)
* Serialization



## AVAdapter.swift  (TTS)

IAVAdapter protocol provides dependency injection wrapper for AVFoundation classes (AVSpeechSynthesizer, AVAudioPlayer) enabling fast unit tests without real audio synthesis or playback. Protocol defines synthesizeToFile() for async text-to-audio conversion and ID-based player API (createPlayer, play, stop, pause, isPlaying, duration, currentTime, setDelegate) hiding AVAudioPlayer references from clients. AVAdapter class provides production implementation wrapping actual AVFoundation APIs with internal player dictionary keyed by AudioPlayerID, while MockAVAdapter (in Tests/) provides instant synthesis and simulated playback for test performance. IAVAudioPlayerDelegate protocol simplifies AVAudioPlayerDelegate callbacks (audioPlayerDidFinishPlaying, audioPlayerBeginInterruption, audioPlayerEndInterruption) for client translation to domain-specific events.

## AudioStore.swift (TTS)

AudioStore provides persistent TTS audio storage wrapping GuidStore to organize synthesized audio files by language and AudioContext hash in format {language}-{audioContextHash[:7]}/{chapter}/{storageKey}.{suffix} enabling automatic cache invalidation when voice/pitch/rate settings change. Uses IAVAdapter for synthesis with deterministic MD5 storage keys ensuring same text plus settings always produces same filename for S3 parity, supports CAF and M4A formats with background M4A conversion providing 7x compression, stores files in Library/Application Support/audio-store by default with shared singleton for production and factory method for test isolation. Provides storeAudio() for async synthesis with configurable timeout, audioUrl() for cached file lookup, clearAllAudio() and diskSize() utilities, and conditional compactContextVolumes() to delete orphaned volumes when user changes audio settings creating new hash-prefixed volumes.

## AudioSynthesisSession.swift (TTS)

AudioSynthesisSession is a single-use immutable actor for batch synthesis of all segments in one sutta enabling background audio preparation before user playback. Loads segments from EbtData based on SuttaRef, synthesizes sequentially via AudioStore using specified AudioContext (language/voice/pitch/rate), and tracks progress with SessionSnapshot exposing readonly state (idle, synthesizing, completed, cancelled, failed), currentStep, totalSteps, estimatedCompletion calculated from exponential moving average of per-segment synthesis time. Provides execute() for async synthesis with optional progressCallback firing on state transitions, cancel() for graceful termination allowing current segment to complete while discarding pending segments, and value property for polling current snapshot. Selects segment text property based on language (pli vs doc), skips blank segments, and reports failures with error messages for individual segment synthesis errors.

## CachedSynthesizer.swift (TTS)

CachedSynthesizer implements ISpeechSynthesizer wrapping AVAudioPlayer for cached audio playback with @MainActor isolation ensuring AudioStore URL stability during playback lifecycle. Manages synthesis queue prioritizing playback requests over cache-only requests with deduplication merging duplicate URLs, processes queue serially via background Task, and translates AVAudioPlayerDelegate callbacks to IPlaybackDelegate events (onPlaybackStarted, onPlaybackFinished, onPlaybackPaused, onPlaybackContinued). Uses AudioStore for retrieving cached/synthesized audio files and provides stopSpeaking() that disarms pending playback requests in synthesis queue while stopping current playback.

## ColorConsole.swift (LOG)

ColorConsole provides emoji-prefixed colored logging to Xcode console with thread-safe timestamp tracking showing elapsed time since app launch and since last output. Defines ok1/ok2 methods for normal execution paths (✅/↓🍀) and bad1/bad2 methods for error paths (❌/↓🌶️) with verbosity levels controlling output (0=silent, 1=final returns only, 2=intermediate logging). Best practice requires calling with #line and #function for source context, keeping log statements single-line under 80 characters, using ok1 for final normal return before closing brace and bad1 for final error return before throw. Thread safety achieved via NSLock protecting appLaunchTime and lastOutputTime static variables with nonisolated(unsafe) marking documented in doc/ColorConsole.md.

## Lemmatizer.swift (CDB)

Lemmatizer normalizes text to base word forms using Apple's NaturalLanguage framework with language-specific support for English, German, French, Italian, Russian enabling consistent search indexing and matching. Caches lemmatization results to JSONL file ({lang}-lemmas.json) persisting across builds with word-by-word processing avoiding context-dependent variations, skips identity mappings (word == lemma) in cache to reduce file size, and provides clean() method removing punctuation while preserving Unicode letters and diacriticals (ä, ö, ü, ā, ī, ṅ). Thread-safe with nonisolated(unsafe) NLTagger and dictionary relying on copy-on-write semantics allowing multiple EbtSeekers to share one Lemmatizer per language, supports German-specific normalization (ae→ä, oe→ö, ue→ü), and provides lemmatizeForSqlData() returning space-padded format " lemma1 lemma2 ... " for database storage.

## Localize.swift (LOC)

Localize provides String extensions for localization with thread-safe configurable bundle enabling test isolation. Defines .localized property for simple NSLocalizedString lookup and .localized(_ arguments:) method for formatted strings with CVarArg parameters, both using localizationBundle variable protected by NSLock wrapping nonisolated(unsafe) Bundle.module reference. Localization resources stored in scv-core/Sources/Resources/{lang}.lproj/Localizable.strings directories with primary language EN, keys must be alphabetically sorted with context comments explaining user-facing usage and parameter descriptions for formatted strings. All EN localization keys must have corresponding translations in all supported language folders, used throughout codebase in 20+ files across scv-core and scv-ui modules.

