//
//  AudioStore.swift
//  scv-core
//
//  Persistent storage for TTS audio with deterministic cache keys.
//  Wraps GuidStore to organize audio files by language and audio context
//  settings.
//

import AVFoundation
import Foundation

/// Audio file format type
enum AudioType {
  case caf
  case m4a
}

/// Compaction status report for orphaned volume cleanup.
///
/// Reports the results of clearing volumes with outdated audio context hashes
/// when user settings change (voice, pitch, rate).
public struct CompactionStatus: Sendable {
  /// Total volumes examined for this language
  public let volumesScanned: Int

  /// Volumes deleted (orphaned with old hash prefix)
  public let volumesDeleted: Int

  /// Volumes retained (current hash prefix for language)
  public let volumesKept: Int

  /// Time elapsed during compaction in seconds
  public let elapsedSeconds: TimeInterval
}

/// AudioStore persists synthesized TTS audio for background playback and
/// battery efficiency.
///
/// Audio files are organized using AudioContext hash to detect when settings
/// change.
/// When user changes voice/rate/pitch, a new volume is created and old volumes
/// become orphaned.
/// Call clearOrphanedVolumes() to auto-delete unused versions.
///
/// - Design: Single shared instance (production) + factory method for test
/// instances
/// - Storage: Library/Caches/audio-store by default (override via
/// create(path:))
/// - Format: Audio files (CAF or M4A)
/// - Organization:
/// {language}-{audioContextHash[:7]}/{chapter}/{storageKey}.{suffix}
final class AudioStore: Sendable {
  private let guidStore: GuidStore
  private let audioType: AudioType
  private let cc = ColorConsole(#file, "AudioStore", dbg.AudioStore.other)
  let timeout: TimeInterval // Configurable synthesis timeout (default 5s)

  /// Shared singleton instance for production use
  nonisolated(unsafe) static let shared = AudioStore.create()

  /// Private initializer - use create() factory method instead
  private init(
    guidStore: GuidStore,
    audioType: AudioType,
    timeout: TimeInterval = 5,
  ) {
    self.guidStore = guidStore
    self.audioType = audioType
    self.timeout = timeout
  }

  /// Create a new AudioStore instance with optional custom storage path, audio
  /// type, and timeout.
  ///
  /// - Parameters:
  ///   - path: Custom path for audio storage (defaults to
  /// Library/Caches/audio-store)
  ///     Useful for testing with isolated directories.
  ///   - type: Audio format type (.caf or .m4a), defaults to .caf
  ///   - timeout: Synthesis timeout in seconds (default 5s)
  /// - Returns: New AudioStore instance
  static func create(
    path: URL? = nil,
    type: AudioType = .caf,
    timeout: TimeInterval = 5,
  ) -> AudioStore {
    let suffix = type == .caf ? ".caf" : ".m4a"

    var config = GuidStoreConfig(
      storeName: "audio-store",
      folderPrefix: 2, // GuidStore default: 2-char chapter
      suffix: suffix,
      defaultVolume: "common",
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
    return AudioStore(guidStore: guidStore, audioType: type, timeout: timeout)
  }

  /// Get audio URL for text and context.
  ///
  /// - Parameters:
  ///   - text: Text to look up
  ///   - audioContext: Audio settings (voice, pitch, rate, etc.)
  ///   - forceUrl: If true, return URL even if file doesn't exist yet. If
  /// false, return URL only if cached.
  /// - Returns: URL to audio file (cached or computed path), or nil if
  /// forceUrl=false and not cached
  func audioUrl(text: String, audioContext: AudioContext,
                forceUrl: Bool = false) -> URL?
  {
    let storageKey = computeStorageKey(text: text, audioContext: audioContext)
    let volume = volumeName(lang: audioContext.docLang, hash: audioContext.hash)
    let suffix = audioType == .caf ? ".caf" : ".m4a"
    let url = guidStore.guidPath(
      guid: storageKey,
      volume: volume,
      suffix: suffix,
    )

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
  private func computeStorageKey(text: String,
                                 audioContext: AudioContext) -> String
  {
    let mj = MerkleJson()
    return mj.hash([
      "text": text,
      "audioContext": audioContext.hash,
    ])
  }

  /// Synthesize and store audio for text and context.
  ///
  /// Performs text-to-speech synthesis and writes the result to a CAF file.
  /// Returns the URL when synthesis completes successfully.
  ///
  /// - Parameters:
  ///   - text: Text to synthesize
  ///   - audioContext: Audio settings (voice, pitch, rate, etc.)
  ///   - timeout: Synthesis timeout in seconds (defaults to instance timeout).
  /// Throws if exceeded.
  /// - Returns: URL to synthesized audio file
  /// - Throws: File creation errors, synthesis failures, or timeout
  func storeAudio(
    text: String,
    audioContext: AudioContext,
    timeout: TimeInterval? = nil,
  ) async throws -> URL {
    // Reject empty text
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw NSError(
        domain: "AudioStore",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "Cannot synthesize empty text"],
      )
    }

    let finalUrl = audioUrl(text: text, audioContext: audioContext, forceUrl: true)!

    // Compute CAF URL (for .m4a mode)
    let cafUrl = audioType == .m4a
      ? URL(fileURLWithPath: finalUrl.path.replacingOccurrences(of: ".m4a", with: ".caf"))
      : finalUrl

    // Check for cached M4A first (if applicable)
    if audioType == .m4a, FileManager.default.fileExists(atPath: finalUrl.path) {
      return finalUrl
    }

    // Check for cached CAF as fallback
    if FileManager.default.fileExists(atPath: cafUrl.path) {
      return cafUrl
    }

    // Ensure output directory exists
    let outputDir = cafUrl.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: outputDir,
      withIntermediateDirectories: true,
    )

    // Perform synthesis to CAF
    let effectiveTimeout = timeout ?? self.timeout
    try await performSynthesis(
      text: text,
      audioContext: audioContext,
      to: cafUrl,
      timeout: effectiveTimeout,
    )

    // If M4A requested, start background conversion task (don't await)
    if audioType == .m4a {
      Task.detached { @Sendable [weak self] in
        guard let self else { return }
        do {
          try await self.convertCAFToM4A(cafUrl: cafUrl, m4aUrl: finalUrl)
        } catch {
          cc.bad1(#line, "M4A conversion failed: \(error)")
        }
      }
    }

    return cafUrl
  }

  /// Perform synthesis and write to CAF audio file.
  private func performSynthesis(
    text: String,
    audioContext: AudioContext,
    to cafUrl: URL,
    timeout: TimeInterval,
  ) async throws {
    let fileManager = FileManager.default

    // Create utterance with audio context voice settings
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: audioContext.docLang)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    utterance.pitchMultiplier = audioContext.pitch
    utterance.volume = 1.0

    // Synthesize directly to CAF file
    let outputUrl = cafUrl

    // Setup synthesis with file writing
    let synthesizer = AVSpeechSynthesizer()
    var audioFile: AVAudioFile?
    let lock = NSLock()
    var isComplete = false
    var synthesisError: Error?

    let onBuffer: (AVAudioBuffer) -> Void = { buffer in
      lock.lock()
      defer { lock.unlock() }

      guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
        return
      }

      // Empty buffer signals completion
      if pcmBuffer.frameLength == 0 {
        isComplete = true
        return
      }

      do {
        // First buffer: create file
        if audioFile == nil {
          audioFile = try AVAudioFile(
            forWriting: outputUrl,
            settings: pcmBuffer.format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false,
          )
        }

        // Write buffer to file
        try audioFile?.write(from: pcmBuffer)
      } catch {
        synthesisError = error
      }
    }

    // Start synthesis
    synthesizer.write(utterance, toBufferCallback: onBuffer)

    // Wait for completion (with configurable timeout)
    let timeoutDate = Date().addingTimeInterval(timeout)
    while !isComplete, synthesisError == nil, Date() < timeoutDate {
      usleep(50000) // 50ms sleep
    }

    // If synthesis failed, clean up partial file and throw
    if let error = synthesisError {
      try? fileManager.removeItem(at: outputUrl)
      throw error
    }

    if Date() >= timeoutDate {
      try? fileManager.removeItem(at: outputUrl)
      throw NSError(
        domain: "AudioStore",
        code: -1,
        userInfo: [
          NSLocalizedDescriptionKey: "Synthesis timeout after \(timeout)s",
        ],
      )
    }

  }

  /// Convert CAF file to M4A (AAC codec) format using AVAudioConverter.
  ///
  /// Uses native Swift AVAudioConverter to encode CAF to AAC (M4A).
  /// This provides ~7x compression over uncompressed PCM.
  ///
  /// - Parameters:
  ///   - cafUrl: URL to source CAF file
  ///   - m4aUrl: URL to destination M4A file
  /// - Throws: Conversion errors
  private func convertCAFToM4A(cafUrl: URL, m4aUrl: URL) async throws {
    do {
      // Step 1: Read CAF file
      let inputAudioFile = try AVAudioFile(forReading: cafUrl)
      let inputFormat = inputAudioFile.processingFormat
      let frameCount = AVAudioFramePosition(inputAudioFile.length)

      // Step 2: Create PCM output format for converter
      let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: inputFormat.sampleRate,
        channels: inputFormat.channelCount,
        interleaved: false,
      )!

      // Step 3: Create converter (reuse throughout chunk processing)
      guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
      else {
        throw NSError(
          domain: "AudioStore",
          code: -3,
          userInfo: [
            NSLocalizedDescriptionKey: "Failed to create AVAudioConverter"
          ],
        )
      }

      // Step 4: Create output file with AAC settings
      let m4aSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: inputFormat.sampleRate,
        AVNumberOfChannelsKey: inputFormat.channelCount,
      ]

      let outputAudioFile = try AVAudioFile(
        forWriting: m4aUrl,
        settings: m4aSettings,
      )

      // Step 5: Convert in chunks
      let bufferSize: AVAudioFrameCount = 4096
      var totalFramesProcessed: AVAudioFrameCount = 0

      while totalFramesProcessed < frameCount {
        let framesRemaining = frameCount - AVAudioFramePosition(totalFramesProcessed)
        let framesToRead = AVAudioFrameCount(min(
          framesRemaining,
          AVAudioFramePosition(bufferSize),
        ))

        // Read chunk from input
        let inputBuffer = AVAudioPCMBuffer(
          pcmFormat: inputFormat,
          frameCapacity: framesToRead,
        )!
        try inputAudioFile.read(into: inputBuffer, frameCount: framesToRead)

        if inputBuffer.frameLength == 0 {
          break
        }

        // Create output buffer for converted data
        let outputBuffer = AVAudioPCMBuffer(
          pcmFormat: outputFormat,
          frameCapacity: bufferSize,
        )!

        // Convert chunk using same converter instance
        try converter.convert(to: outputBuffer, from: inputBuffer)

        // Write converted buffer
        try outputAudioFile.write(from: outputBuffer)

        totalFramesProcessed += inputBuffer.frameLength
      }

      // Clean up temporary CAF file
      try FileManager.default.removeItem(at: cafUrl)
    } catch {
      // Clean up M4A if conversion failed
      try? FileManager.default.removeItem(at: m4aUrl)
      throw error
    }
  }

  /// List all volumes in the audio store (for testing).
  ///
  /// - Returns: Array of volume names
  func listVolumes() async throws -> [String] {
    try await guidStore.listVolumes()
  }

  /// Compact audio volumes by removing orphaned contexts.
  ///
  /// When user changes voice/pitch/rate, a new AudioContext hash is created.
  /// Old volumes with different hash prefixes become orphaned. This method
  /// scans all volumes for the document language and deletes those with
  /// outdated hash prefixes, keeping only the current context volume.
  ///
  /// Errors are handled silently (failed deletions don't throw).
  ///
  /// - Parameter context: Current audio context (determines current hash and
  /// language)
  /// - Returns: CompactionStatus with counts of scanned/deleted/kept volumes
  /// and elapsed time
  func compactContextVolumes(context: AudioContext) async -> CompactionStatus {
    let cc = ColorConsole(#file, #function, dbg.AudioStore.other)
    let startTime = Date()
    let lang = context.docLang
    let currentHash = String(context.hash.prefix(7))

    cc.ok2(
      #line,
      #function,
      "Starting compaction for language:",
      lang,
      "hash prefix:",
      currentHash,
    )

    do {
      let allVolumes = try await guidStore.listVolumes()
      cc.ok2(#line, #function, "Found", allVolumes.count, "total volumes")

      var scanned = 0
      var deleted = 0
      var kept = 0

      for volume in allVolumes {
        // Check if volume matches pattern: "{lang}-{hashPrefix7}"
        guard volume.hasPrefix("\(lang)-") else {
          continue
        }

        scanned += 1

        // Extract hash prefix from volume name (e.g., "en-abc123d" ->
        // "abc123d")
        let volumeHashPrefix = String(volume.dropFirst(lang.count + 1))

        if volumeHashPrefix == currentHash {
          // Keep current context volume
          cc.ok2(#line, #function, "Keeping current volume:", volume)
          kept += 1
        } else {
          // Delete orphaned volume
          do {
            _ = try await guidStore.clearVolume(volume)
            cc.ok2(#line, #function, "Deleted orphaned volume:", volume)
            deleted += 1
          } catch {
            // Silently ignore deletion errors
            cc.bad2(
              #line,
              #function,
              "Failed to delete volume",
              volume,
              "error:",
              error,
            )
            continue
          }
        }
      }

      let elapsed = Date().timeIntervalSince(startTime)
      let status = CompactionStatus(
        volumesScanned: scanned,
        volumesDeleted: deleted,
        volumesKept: kept,
        elapsedSeconds: elapsed,
      )

      cc.ok1(
        #line,
        #function,
        "Compaction complete: scanned=\(scanned) deleted=\(deleted) kept=\(kept) elapsed=\(String(format: "%.3f", elapsed))s",
      )

      return status
    } catch {
      // If listing volumes fails, return zero status silently
      let elapsed = Date().timeIntervalSince(startTime)
      let errorMsg = "Failed to list volumes: \(error)"
      cc.bad1(#line, #function, errorMsg)
      return CompactionStatus(
        volumesScanned: 0,
        volumesDeleted: 0,
        volumesKept: 0,
        elapsedSeconds: elapsed,
      )
    }
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
