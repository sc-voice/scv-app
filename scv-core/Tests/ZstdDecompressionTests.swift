import Foundation
import libzstd
import Testing

@testable import scvCore

struct ZstdDecompressionTests {
  @Test
  func decompressSimpleData() throws {
    // Create sample data
    let originalData = "Hello, World! This is a test of zstd compression."
      .data(using: .utf8)!

    // Compress the data
    let compressedData = try compressData(originalData)

    // Decompress the data
    let decompressedData = try ZstdDecompression.decompress(compressedData)

    // Verify
    #expect(decompressedData == originalData)
  }

  @Test
  func decompressLargeData() throws {
    // Create a large sample data (1MB)
    let pattern = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
    let largeString = String(repeating: pattern, count: 17000)
    let originalData = largeString.data(using: .utf8)!

    // Compress the data
    let compressedData = try compressData(originalData)

    // Decompress the data
    let decompressedData = try ZstdDecompression.decompress(compressedData)

    // Verify
    #expect(decompressedData == originalData)
    #expect(decompressedData.count == originalData.count)
  }

  @Test
  func decompressInvalidData() throws {
    let invalidData = Data([0xFF, 0xFF, 0xFF, 0xFF])

    // Should throw error
    var errorThrown = false
    do {
      _ = try ZstdDecompression.decompress(invalidData)
    } catch {
      errorThrown = true
    }

    #expect(errorThrown == true)
  }

  // Helper function to compress data using zstd
  private func compressData(_ data: Data) throws -> Data {
    var compressed = Data()

    try data.withUnsafeBytes { buffer in
      guard let ptr = buffer.baseAddress else {
        throw NSError(domain: "CompressionError", code: -1)
      }

      let cctx = ZSTD_createCCtx()
      defer { ZSTD_freeCCtx(cctx) }

      let bound = ZSTD_compressBound(data.count)
      compressed.count = bound

      let compressedSize = try compressed.withUnsafeMutableBytes { compBuffer in
        guard let compPtr = compBuffer.baseAddress else {
          throw NSError(domain: "CompressionError", code: -1)
        }

        let result = ZSTD_compressCCtx(
          cctx,
          compPtr,
          bound,
          ptr,
          data.count,
          3, // compression level
        )

        guard ZSTD_isError(result) == 0 else {
          throw NSError(domain: "CompressionError", code: Int(result))
        }

        return result
      }

      compressed.count = compressedSize
    }

    return compressed
  }
}
