import Foundation
import libzstd
import Testing

@testable import scvCore

struct ZstdIntegrationTests {
  @Test
  func decompressFrNoeismetDatabase() throws {
    // Load the original database
    guard let originalURL = Bundle.module.url(
      forResource: "ebt-fr-noeismet",
      withExtension: "db",
    ) else {
      #expect(Bool(false), "Could not find original database")
      return
    }

    let originalData = try Data(contentsOf: originalURL)
    let originalSize = originalData.count
    let originalSizeMB = Double(originalSize) / (1024 * 1024)

    // Load the compressed database
    guard let compressedURL = Bundle.module.url(
      forResource: "ebt-fr-noeismet",
      withExtension: "db.zst",
    ) else {
      #expect(Bool(false), "Could not find compressed database")
      return
    }

    let compressedData = try Data(contentsOf: compressedURL)
    let compressedSize = compressedData.count
    let compressedSizeMB = Double(compressedSize) / (1024 * 1024)
    let compressionRatio = Double(compressedSize) / Double(originalSize) * 100

    // Measure decompression time
    let startTime = Date()
    let decompressedData = try ZstdDecompression.decompress(compressedData)
    let decompressTime = Date().timeIntervalSince(startTime)

    // Calculate decompression speed
    let decompressSpeedMBps = originalSizeMB / decompressTime

    // Verify decompressed data matches original
    #expect(decompressedData == originalData)
    #expect(decompressedData.count == originalData.count)

    // Log performance metrics
    print("=== Zstd Integration Test (fr:noeismet) ===")
    print("Original size: \(String(format: "%.1f", originalSizeMB)) MiB")
    print("Compressed size: \(String(format: "%.1f", compressedSizeMB)) MiB")
    print("Compression ratio: \(String(format: "%.1f", compressionRatio))%")
    print(
      "Decompression time: \(String(format: "%.3f", decompressTime)) seconds",
    )
    print(
      "Decompression speed: \(String(format: "%.1f", decompressSpeedMBps)) MiB/s",
    )
  }

  @Test
  func decompressDeSabbamittaDatabase() throws {
    // Load the original database
    guard let originalURL = Bundle.module.url(
      forResource: "ebt-de-sabbamitta",
      withExtension: "db",
    ) else {
      #expect(Bool(false), "Could not find original database")
      return
    }

    let originalData = try Data(contentsOf: originalURL)
    let originalSize = originalData.count
    let originalSizeMB = Double(originalSize) / (1024 * 1024)

    // Load the compressed database
    guard let compressedURL = Bundle.module.url(
      forResource: "ebt-de-sabbamitta",
      withExtension: "db.zst",
    ) else {
      #expect(Bool(false), "Could not find compressed database")
      return
    }

    let compressedData = try Data(contentsOf: compressedURL)
    let compressedSize = compressedData.count
    let compressedSizeMB = Double(compressedSize) / (1024 * 1024)
    let compressionRatio = Double(compressedSize) / Double(originalSize) * 100

    // Measure decompression time
    let startTime = Date()
    let decompressedData = try ZstdDecompression.decompress(compressedData)
    let decompressTime = Date().timeIntervalSince(startTime)

    // Calculate decompression speed
    let decompressSpeedMBps = originalSizeMB / decompressTime

    // Verify decompressed data matches original
    #expect(decompressedData == originalData)
    #expect(decompressedData.count == originalData.count)

    // Log performance metrics
    print("=== Zstd Integration Test (de:sabbamitta) ===")
    print("Original size: \(String(format: "%.1f", originalSizeMB)) MiB")
    print("Compressed size: \(String(format: "%.1f", compressedSizeMB)) MiB")
    print("Compression ratio: \(String(format: "%.1f", compressionRatio))%")
    print(
      "Decompression time: \(String(format: "%.3f", decompressTime)) seconds",
    )
    print(
      "Decompression speed: \(String(format: "%.1f", decompressSpeedMBps)) MiB/s",
    )
  }
}
