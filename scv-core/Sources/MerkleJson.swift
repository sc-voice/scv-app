import Foundation

/// Deterministic MD5 hash computation for JSON structures.
///
/// Provides byte-for-byte compatibility with JavaScript merkle-json
/// implementation
/// to ensure consistent hashing for audio file keys on S3.
///
/// Supported types:
/// - String: hashed directly
/// - Date: converted to ISO8601 string via toJSON()
/// - Double/Int: converted to string representation
/// - Array: merkle hashing (hash each element, concatenate hashes, hash result)
/// - Dictionary: keys sorted alphabetically, then canonical format
/// - Optional: null values hashed as "null" string
/// - Boolean: true/false hashed as "true"/"false" strings
///
public class MerkleJson {
  let hashTag: String

  public init(hashTag: String = "merkleHash") {
    self.hashTag = hashTag
  }

  /// Compute deterministic MD5 hash of any JSON-serializable value
  /// - Parameters:
  ///   - value: The value to hash (String, Date, number, Array, Dictionary,
  /// null)
  ///   - cached: If true, honor merkleHash field in objects if present
  /// - Returns: 32-character hex string (lowercase a-f)
  public func hash(_ value: Any?, cached: Bool = true) -> String {
    // Check Bool before NSNumber because Bool bridges to NSNumber in Swift
    if let bool = value as? Bool {
      return hash(bool ? "true" : "false", cached: cached)
    } else if let str = value as? String {
      return md5(str)
    } else if let arr = value as? [Any?] {
      // Array merkle hashing: concatenate hashes of elements, then hash
      var acc = ""
      for item in arr {
        acc += hash(item, cached: cached)
      }
      return hash(acc, cached: cached)
    } else if let num = value as? NSNumber {
      // Numbers converted to string representation
      let str = num.stringValue
      return hash(str, cached: cached)
    } else if let date = value as? Date {
      // Dates converted to ISO8601 string via toJSON() equivalent
      return hash(date.toJSON(), cached: cached)
    } else if let dict = value as? [String: Any?] {
      // Objects with merkleHash field handling
      if cached, let cachedHash = dict[hashTag] as? String {
        return cachedHash
      }

      // Sort keys, build "key:hash(value)," format
      let sortedKeys = dict.keys.sorted()
      var acc = ""
      for key in sortedKeys {
        if key != hashTag {
          let val = dict[key] as Any?
          acc += key + ":" + hash(val, cached: cached) + ","
        }
      }
      return hash(acc, cached: cached)
    } else if value == nil {
      return hash("null", cached: cached)
    } else if value is NSNull {
      return hash("null", cached: cached)
    }

    // Fallback: convert to string
    return hash(String(describing: value), cached: cached)
  }

  // MARK: - MD5 Implementation

  // Based on http://www.myersdaily.org/joseph/javascript/md5.js

  private func md5(_ s: String) -> String {
    let state = md51(s)
    return hex(state)
  }

  private func md51(_ s: String) -> [UInt32] {
    // MD5 initial values (standard constants)
    var state: [UInt32] = [
      0x6745_2301,
      0xEFCD_AB89,
      0x98BA_DCFE,
      0x1032_5476,
    ]
    let bytes = Array(s.utf8)

    var i = 0
    while i + 64 <= bytes.count {
      let chunk = Array(bytes[i ..< i + 64])
      md5cycle(&state, md5blk(chunk))
      i += 64
    }

    let remaining = Array(bytes[i...])
    var tail = Array(repeating: UInt32(0), count: 16)

    for j in 0 ..< remaining.count {
      let byteValue = UInt32(remaining[j])
      let index = j >> 2
      let shift = (j & 3) << 3
      tail[index] |= byteValue << shift
    }

    tail[remaining.count >> 2] |= 0x80 << ((remaining.count & 3) << 3)

    if remaining.count > 55 {
      md5cycle(&state, tail)
      tail = Array(repeating: UInt32(0), count: 16)
    }

    tail[14] = UInt32(bytes.count * 8)
    md5cycle(&state, tail)

    return state
  }

  private func md5blk(_ data: [UInt8]) -> [UInt32] {
    var blocks = Array(repeating: UInt32(0), count: 16)

    for i in stride(from: 0, to: 64, by: 4) {
      let index = i >> 2
      let b0 = UInt32(data[i])
      let b1 = UInt32(data[i + 1]) << 8
      let b2 = UInt32(data[i + 2]) << 16
      let b3 = UInt32(data[i + 3]) << 24
      blocks[index] = b0 | b1 | b2 | b3
    }

    return blocks
  }

  private func md5cycle(_ x: inout [UInt32], _ k: [UInt32]) {
    var a = x[0], b = x[1], c = x[2], d = x[3]

    a = ff(a, b, c, d, k[0], 7, UInt32(bitPattern: -680_876_936))
    d = ff(d, a, b, c, k[1], 12, UInt32(bitPattern: -389_564_586))
    c = ff(c, d, a, b, k[2], 17, 606_105_819)
    b = ff(b, c, d, a, k[3], 22, UInt32(bitPattern: -1_044_525_330))
    a = ff(a, b, c, d, k[4], 7, UInt32(bitPattern: -176_418_897))
    d = ff(d, a, b, c, k[5], 12, 1_200_080_426)
    c = ff(c, d, a, b, k[6], 17, UInt32(bitPattern: -1_473_231_341))
    b = ff(b, c, d, a, k[7], 22, UInt32(bitPattern: -45_705_983))
    a = ff(a, b, c, d, k[8], 7, 1_770_035_416)
    d = ff(d, a, b, c, k[9], 12, UInt32(bitPattern: -1_958_414_417))
    c = ff(c, d, a, b, k[10], 17, UInt32(bitPattern: -42063))
    b = ff(b, c, d, a, k[11], 22, UInt32(bitPattern: -1_990_404_162))
    a = ff(a, b, c, d, k[12], 7, 1_804_603_682)
    d = ff(d, a, b, c, k[13], 12, UInt32(bitPattern: -40_341_101))
    c = ff(c, d, a, b, k[14], 17, UInt32(bitPattern: -1_502_002_290))
    b = ff(b, c, d, a, k[15], 22, 1_236_535_329)

    a = gg(a, b, c, d, k[1], 5, UInt32(bitPattern: -165_796_510))
    d = gg(d, a, b, c, k[6], 9, UInt32(bitPattern: -1_069_501_632))
    c = gg(c, d, a, b, k[11], 14, 643_717_713)
    b = gg(b, c, d, a, k[0], 20, UInt32(bitPattern: -373_897_302))
    a = gg(a, b, c, d, k[5], 5, UInt32(bitPattern: -701_558_691))
    d = gg(d, a, b, c, k[10], 9, 38_016_083)
    c = gg(c, d, a, b, k[15], 14, UInt32(bitPattern: -660_478_335))
    b = gg(b, c, d, a, k[4], 20, UInt32(bitPattern: -405_537_848))
    a = gg(a, b, c, d, k[9], 5, 568_446_438)
    d = gg(d, a, b, c, k[14], 9, UInt32(bitPattern: -1_019_803_690))
    c = gg(c, d, a, b, k[3], 14, UInt32(bitPattern: -187_363_961))
    b = gg(b, c, d, a, k[8], 20, 1_163_531_501)
    a = gg(a, b, c, d, k[13], 5, UInt32(bitPattern: -1_444_681_467))
    d = gg(d, a, b, c, k[2], 9, UInt32(bitPattern: -51_403_784))
    c = gg(c, d, a, b, k[7], 14, 1_735_328_473)
    b = gg(b, c, d, a, k[12], 20, UInt32(bitPattern: -1_926_607_734))

    a = hh(a, b, c, d, k[5], 4, UInt32(bitPattern: -378_558))
    d = hh(d, a, b, c, k[8], 11, UInt32(bitPattern: -2_022_574_463))
    c = hh(c, d, a, b, k[11], 16, 1_839_030_562)
    b = hh(b, c, d, a, k[14], 23, UInt32(bitPattern: -35_309_556))
    a = hh(a, b, c, d, k[1], 4, UInt32(bitPattern: -1_530_992_060))
    d = hh(d, a, b, c, k[4], 11, 1_272_893_353)
    c = hh(c, d, a, b, k[7], 16, UInt32(bitPattern: -155_497_632))
    b = hh(b, c, d, a, k[10], 23, UInt32(bitPattern: -1_094_730_640))
    a = hh(a, b, c, d, k[13], 4, 681_279_174)
    d = hh(d, a, b, c, k[0], 11, UInt32(bitPattern: -358_537_222))
    c = hh(c, d, a, b, k[3], 16, UInt32(bitPattern: -722_521_979))
    b = hh(b, c, d, a, k[6], 23, 76_029_189)
    a = hh(a, b, c, d, k[9], 4, UInt32(bitPattern: -640_364_487))
    d = hh(d, a, b, c, k[12], 11, UInt32(bitPattern: -421_815_835))
    c = hh(c, d, a, b, k[15], 16, 530_742_520)
    b = hh(b, c, d, a, k[2], 23, UInt32(bitPattern: -995_338_651))

    a = ii(a, b, c, d, k[0], 6, UInt32(bitPattern: -198_630_844))
    d = ii(d, a, b, c, k[7], 10, 1_126_891_415)
    c = ii(c, d, a, b, k[14], 15, UInt32(bitPattern: -1_416_354_905))
    b = ii(b, c, d, a, k[5], 21, UInt32(bitPattern: -57_434_055))
    a = ii(a, b, c, d, k[12], 6, 1_700_485_571)
    d = ii(d, a, b, c, k[3], 10, UInt32(bitPattern: -1_894_986_606))
    c = ii(c, d, a, b, k[10], 15, UInt32(bitPattern: -1_051_523))
    b = ii(b, c, d, a, k[1], 21, UInt32(bitPattern: -2_054_922_799))
    a = ii(a, b, c, d, k[8], 6, 1_873_313_359)
    d = ii(d, a, b, c, k[15], 10, UInt32(bitPattern: -30_611_744))
    c = ii(c, d, a, b, k[6], 15, UInt32(bitPattern: -1_560_198_380))
    b = ii(b, c, d, a, k[13], 21, 1_309_151_649)
    a = ii(a, b, c, d, k[4], 6, UInt32(bitPattern: -145_523_070))
    d = ii(d, a, b, c, k[11], 10, UInt32(bitPattern: -1_120_210_379))
    c = ii(c, d, a, b, k[2], 15, 718_787_259)
    b = ii(b, c, d, a, k[9], 21, UInt32(bitPattern: -343_485_551))

    x[0] = add32(a, x[0])
    x[1] = add32(b, x[1])
    x[2] = add32(c, x[2])
    x[3] = add32(d, x[3])
  }

  private func cmn(
    _ q: UInt32,
    _ a: UInt32,
    _ b: UInt32,
    _ x: UInt32,
    _ s: UInt32,
    _ t: UInt32,
  ) -> UInt32 {
    let sum = add32(add32(a, q), add32(x, t))
    return add32((sum << s) | (sum >> (32 - s)), b)
  }

  private func ff(
    _ a: UInt32,
    _ b: UInt32,
    _ c: UInt32,
    _ d: UInt32,
    _ x: UInt32,
    _ s: UInt32,
    _ t: UInt32,
  ) -> UInt32 {
    cmn((b & c) | ((~b) & d), a, b, x, s, t)
  }

  private func gg(
    _ a: UInt32,
    _ b: UInt32,
    _ c: UInt32,
    _ d: UInt32,
    _ x: UInt32,
    _ s: UInt32,
    _ t: UInt32,
  ) -> UInt32 {
    cmn((b & d) | (c & ~d), a, b, x, s, t)
  }

  private func hh(
    _ a: UInt32,
    _ b: UInt32,
    _ c: UInt32,
    _ d: UInt32,
    _ x: UInt32,
    _ s: UInt32,
    _ t: UInt32,
  ) -> UInt32 {
    cmn(b ^ c ^ d, a, b, x, s, t)
  }

  private func ii(
    _ a: UInt32,
    _ b: UInt32,
    _ c: UInt32,
    _ d: UInt32,
    _ x: UInt32,
    _ s: UInt32,
    _ t: UInt32,
  ) -> UInt32 {
    cmn(c ^ (b | ~d), a, b, x, s, t)
  }

  private func add32(_ a: UInt32, _ b: UInt32) -> UInt32 {
    (a &+ b) & 0xFFFF_FFFF
  }

  private func hex(_ state: [UInt32]) -> String {
    let hexChars = "0123456789abcdef"
    var result = ""

    for num in state {
      for j in 0 ..< 4 {
        let byte = (num >> (j * 8)) & 0xFF
        let high = (byte >> 4) & 0xF
        let low = byte & 0xF

        let h = hexChars[hexChars.index(
          hexChars.startIndex,
          offsetBy: Int(high),
        )]
        let l = hexChars[hexChars.index(
          hexChars.startIndex,
          offsetBy: Int(low),
        )]
        result.append(h)
        result.append(l)
      }
    }

    return result
  }
}

// MARK: - Date Extension

extension Date {
  /// Returns ISO8601-formatted string representation, compatible with
  /// JavaScript Date.toJSON()
  func toJSON() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: self)
  }
}
