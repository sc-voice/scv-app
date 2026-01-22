/*
//
//  AudioStore.swift
//  scv-core
//
//  Persistent storage for TTS audio with deterministic cache keys.
//  Wraps GuidStore to organize audio files by language and audio context settings.
//

import Foundation

/// AudioStore persists synthesized TTS audio for background playback and battery efficiency.
///
/// Audio files are organized using AudioContext hash to detect when settings change.
/// When user changes voice/rate/pitch, a new volume is created and old volumes become orphaned.
/// Call clearOrphanedVolumes() to auto-delete unused versions.
///
/// - Thread safety: @MainActor isolated (GuidStore path resolution is sync)
/// - Storage: Library/Caches/audio-store by default (override via init parameter)
/// - Format: M4A files with .m4a suffix
/// - Organization: {language}-{audioContextHash[:7]}/{chapter}/{storageKey}.m4a
@MainActor
final class AudioStore {
  private let guidStore: GuidStore

  /// Initialize AudioStore with optional custom storage path.
  ///
  /// - Parameter storePath: Custom path for audio storage (defaults to Library/Caches/audio-store)
  ///   Useful for testing with isolated directories.
  init(storePath: URL? = nil) {
    var config = GuidStoreConfig(
      storeName: "audio-store",
      folderPrefix: 2,  // GuidStore default: 2-char chapter
      suffix: ".m4a",
      defaultVolume: "common"
    )

    // Set storage path
    if let customPath = storePath {
      config.storePath = customPath
    } else {
      let cachesURL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
      config.storePath = cachesURL.appendingPathComponent("audio-store")
    }

    self.guidStore = GuidStore(config: config)
  }

  /// Check if audio is stored for a segment with given context.
  ///
  /// - Parameters:
  ///   - segment: Target segment
  ///   - audioContext: Audio settings (voice, pitch, rate, etc.)
  /// - Returns: URL to cached audio file, or nil if not stored
  func storedAudioURL(segment: Segment, audioContext: AudioContext) -> URL? {
    let storageKey = computeStorageKey(segment: segment, audioContext: audioContext)
    let volume = volumeName(lang: audioContext.docLang, hash: audioContext.hash)
    let url = guidStore.guidPath(guid: storageKey, volume: volume, suffix: ".m4a")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  /// Store synthesized audio for a segment (fire-and-forget).
  ///
  /// Writes audio atomically to cache. Errors are silently ignored to avoid
  /// blocking playback if storage fails.
  ///
  /// - Parameters:
  ///   - segment: Target segment
  ///   - audioContext: Audio settings (voice, pitch, rate, etc.)
  ///   - data: Synthesized audio data (M4A format)
  func storeAudio(segment: Segment, audioContext: AudioContext, data: Data) {
    let storageKey = computeStorageKey(segment: segment, audioContext: audioContext)
    let volume = volumeName(lang: audioContext.docLang, hash: audioContext.hash)
    let url = guidStore.guidPath(guid: storageKey, volume: volume, suffix: ".m4a")

    do {
      try data.write(to: url, options: .atomic)
    } catch {
      // Silently ignore storage failures to avoid blocking playback
      // Could log here with ColorConsole if needed
    }
  }

  /// Delete orphaned audio volumes for a language with different audio context.
  ///
  /// When user changes voice/rate/pitch, a new volume is created with different hash.
  /// Call this to clean up old volumes, freeing disk space.
  ///
  /// - Parameters:
  ///   - lang: Document language code (e.g., "en", "de")
  ///   - currentHash: Current audio context hash (identifies volumes to keep)
  func clearOrphanedVolumes(lang: String, currentHash: String) async {
    do {
      let allVolumes = try await guidStore.listVolumes()
      let currentPrefix = "\(lang)-\(String(currentHash.prefix(7)))"

      // Find old volumes for this language with different hash
      let oldVolumes = allVolumes.filter { volume in
        volume.hasPrefix("\(lang)-") && volume != currentPrefix
      }

      // Delete orphaned volumes
      for volume in oldVolumes {
        let count = try await guidStore.clearVolume(volume)
        // Could log here: "Deleted orphaned audio volume: \(volume) (\(count) files)"
      }
    } catch {
      // Silently ignore cleanup errors
      // Could log here with ColorConsole if needed
    }
  }

  /// Compute deterministic storage key for segment + audio context.
  ///
  /// Same segment + same settings = always same key (enables S3 parity).
  /// Different settings = different key (automatic cache invalidation).
  ///
  /// - Parameters:
  ///   - segment: Target segment
  ///   - audioContext: Audio settings (voice, pitch, rate, etc.)
  /// - Returns: 32-char hex MD5 hash
  private func computeStorageKey(segment: Segment, audioContext: AudioContext) -> String {
    let mj = MerkleJson()
    return mj.hash([
      "scid": segment.scid,
      "text": segment.text,
      "audioContext": audioContext.hash
    ])
  }

  /// Format volume name from language and audio context hash.
  ///
  /// Volume names group audio files by language and audio context, enabling
  /// fast cleanup when settings change.
  ///
  /// - Parameters:
  ///   - lang: Document language code (e.g., "en", "de", "pli")
  ///   - hash: Audio context hash (32-char hex)
  /// - Returns: Volume name format: "{lang}-{hashprefix7}" (e.g., "en-abc123d")
  private func volumeName(lang: String, hash: String) -> String {
    let hashPrefix = String(hash.prefix(7))
    return "\(lang)-\(hashPrefix)"
  }
}
*/
