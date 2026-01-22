//
//  AudioStore.swift
//  scv-core
//
//  Persistent storage for TTS audio with deterministic cache keys.
//  Wraps GuidStore to organize audio files by language and audio context settings.
//

import Foundation

/// Audio file format type
enum AudioType {
  case caf
  case m4a
}

/// AudioStore persists synthesized TTS audio for background playback and battery efficiency.
///
/// Audio files are organized using AudioContext hash to detect when settings change.
/// When user changes voice/rate/pitch, a new volume is created and old volumes become orphaned.
/// Call clearOrphanedVolumes() to auto-delete unused versions.
///
/// - Design: Single shared instance (production) + factory method for test instances
/// - Storage: Library/Caches/audio-store by default (override via create(path:))
/// - Format: Audio files (CAF or M4A)
/// - Organization: {language}-{audioContextHash[:7]}/{chapter}/{storageKey}.{suffix}
final class AudioStore {
  private let guidStore: GuidStore
  private let audioType: AudioType

  /// Shared singleton instance for production use
  nonisolated(unsafe) static let shared = AudioStore.create()

  /// Private initializer - use create() factory method instead
  private init(guidStore: GuidStore, audioType: AudioType) {
    self.guidStore = guidStore
    self.audioType = audioType
  }

  /// Create a new AudioStore instance with optional custom storage path and audio type.
  ///
  /// - Parameters:
  ///   - path: Custom path for audio storage (defaults to Library/Caches/audio-store)
  ///     Useful for testing with isolated directories.
  ///   - type: Audio format type (.caf or .m4a), defaults to .caf
  /// - Returns: New AudioStore instance
  static func create(path: URL? = nil, type: AudioType = .caf) -> AudioStore {
    let suffix = type == .caf ? ".caf" : ".m4a"

    var config = GuidStoreConfig(
      storeName: "audio-store",
      folderPrefix: 2,  // GuidStore default: 2-char chapter
      suffix: suffix,
      defaultVolume: "common"
    )

    // Set storage path
    if let customPath = path {
      config.storePath = customPath
    } else {
      let cachesURL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
      config.storePath = cachesURL.appendingPathComponent("audio-store")
    }

    let guidStore = GuidStore(config: config)
    return AudioStore(guidStore: guidStore, audioType: type)
  }

  /// Get audio URL for text and context.
  ///
  /// - Parameters:
  ///   - text: Text to look up
  ///   - audioContext: Audio settings (voice, pitch, rate, etc.)
  ///   - forceUrl: If true, return URL even if file doesn't exist yet. If false, return URL only if cached.
  /// - Returns: URL to audio file (cached or computed path), or nil if forceUrl=false and not cached
  func audioUrl(text: String, audioContext: AudioContext, forceUrl: Bool = false) -> URL? {
    let storageKey = computeStorageKey(text: text, audioContext: audioContext)
    let volume = volumeName(lang: audioContext.docLang, hash: audioContext.hash)
    let suffix = audioType == .caf ? ".caf" : ".m4a"
    let url = guidStore.guidPath(guid: storageKey, volume: volume, suffix: suffix)

    if forceUrl {
      return url
    }
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  /// Compute deterministic storage key for text + audio context.
  ///
  /// Same text + same settings = always same key (enables S3 parity).
  /// Different settings = different key (automatic cache invalidation).
  ///
  /// - Parameters:
  ///   - text: Target text
  ///   - audioContext: Audio settings (voice, pitch, rate, etc.)
  /// - Returns: 32-char hex MD5 hash
  private func computeStorageKey(text: String, audioContext: AudioContext) -> String {
    let mj = MerkleJson()
    return mj.hash([
      "text": text,
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
