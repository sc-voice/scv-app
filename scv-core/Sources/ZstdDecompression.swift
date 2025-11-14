import Foundation
import libzstd

/// Utility for decompressing zstd-compressed data
public enum ZstdDecompression {
  /// Error types for zstd decompression
  public enum Error: Swift.Error {
    case decompressionFailed(String)
    case invalidData
  }

  /// Decompresses zstd-compressed data
  /// - Parameter compressedData: The zstd-compressed data
  /// - Returns: The decompressed data
  /// - Throws: ZstdDecompression.Error if decompression fails
  public static func decompress(_ compressedData: Data) throws -> Data {
    var decompressed = Data()

    try compressedData.withUnsafeBytes { compressedBuffer in
      guard let compressedPtr = compressedBuffer.baseAddress else {
        throw Error.invalidData
      }

      // Get decompressed size
      let frameContentSize = ZSTD_getFrameContentSize(
        compressedPtr,
        compressedData.count,
      )

      guard frameContentSize != ZSTD_CONTENTSIZE_UNKNOWN,
            frameContentSize != ZSTD_CONTENTSIZE_ERROR,
            frameContentSize > 0
      else {
        throw Error.decompressionFailed("Unable to determine decompressed size")
      }

      // Allocate decompression context
      guard let dctx = ZSTD_createDCtx() else {
        throw Error
          .decompressionFailed("Failed to create decompression context")
      }
      defer { ZSTD_freeDCtx(dctx) }

      // Allocate output buffer
      decompressed.count = Int(frameContentSize)

      let decompressedSize = try decompressed
        .withUnsafeMutableBytes { decompressedBuffer in
          guard let decompressedPtr = decompressedBuffer.baseAddress else {
            throw Error.invalidData
          }

          let result = ZSTD_decompressDCtx(
            dctx,
            decompressedPtr,
            Int(frameContentSize),
            compressedPtr,
            compressedData.count,
          )

          guard ZSTD_isError(result) == 0 else {
            let errorString = String(cString: ZSTD_getErrorName(result))
            throw Error.decompressionFailed(errorString)
          }

          return result
        }

      // Trim to actual decompressed size
      decompressed.count = decompressedSize
    }

    return decompressed
  }
}
