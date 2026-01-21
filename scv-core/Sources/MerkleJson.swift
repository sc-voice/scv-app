import Foundation

/// Deterministic MD5 hash computation for JSON structures.
///
/// Provides byte-for-byte compatibility with JavaScript merkle-json implementation
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
    ///   - value: The value to hash (String, Date, number, Array, Dictionary, null)
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
                    let val = dict[key]
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
            0x67452301,
            0xEFCDAB89,
            0x98BADCFE,
            0x10325476
        ]
        let bytes = Array(s.utf8)

        var i = 0
        while i + 64 <= bytes.count {
            let chunk = Array(bytes[i..<i+64])
            md5cycle(&state, md5blk(chunk))
            i += 64
        }

        let remaining = Array(bytes[i...])
        var tail = Array(repeating: UInt32(0), count: 16)

        for j in 0..<remaining.count {
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
            let b1 = UInt32(data[i+1]) << 8
            let b2 = UInt32(data[i+2]) << 16
            let b3 = UInt32(data[i+3]) << 24
            blocks[index] = b0 | b1 | b2 | b3
        }

        return blocks
    }

    private func md5cycle(_ x: inout [UInt32], _ k: [UInt32]) {
        var a = x[0], b = x[1], c = x[2], d = x[3]

        a = ff(a, b, c, d, k[0], 7, UInt32(bitPattern: -680876936))
        d = ff(d, a, b, c, k[1], 12, UInt32(bitPattern: -389564586))
        c = ff(c, d, a, b, k[2], 17, 606105819)
        b = ff(b, c, d, a, k[3], 22, UInt32(bitPattern: -1044525330))
        a = ff(a, b, c, d, k[4], 7, UInt32(bitPattern: -176418897))
        d = ff(d, a, b, c, k[5], 12, 1200080426)
        c = ff(c, d, a, b, k[6], 17, UInt32(bitPattern: -1473231341))
        b = ff(b, c, d, a, k[7], 22, UInt32(bitPattern: -45705983))
        a = ff(a, b, c, d, k[8], 7, 1770035416)
        d = ff(d, a, b, c, k[9], 12, UInt32(bitPattern: -1958414417))
        c = ff(c, d, a, b, k[10], 17, UInt32(bitPattern: -42063))
        b = ff(b, c, d, a, k[11], 22, UInt32(bitPattern: -1990404162))
        a = ff(a, b, c, d, k[12], 7, 1804603682)
        d = ff(d, a, b, c, k[13], 12, UInt32(bitPattern: -40341101))
        c = ff(c, d, a, b, k[14], 17, UInt32(bitPattern: -1502002290))
        b = ff(b, c, d, a, k[15], 22, 1236535329)

        a = gg(a, b, c, d, k[1], 5, UInt32(bitPattern: -165796510))
        d = gg(d, a, b, c, k[6], 9, UInt32(bitPattern: -1069501632))
        c = gg(c, d, a, b, k[11], 14, 643717713)
        b = gg(b, c, d, a, k[0], 20, UInt32(bitPattern: -373897302))
        a = gg(a, b, c, d, k[5], 5, UInt32(bitPattern: -701558691))
        d = gg(d, a, b, c, k[10], 9, 38016083)
        c = gg(c, d, a, b, k[15], 14, UInt32(bitPattern: -660478335))
        b = gg(b, c, d, a, k[4], 20, UInt32(bitPattern: -405537848))
        a = gg(a, b, c, d, k[9], 5, 568446438)
        d = gg(d, a, b, c, k[14], 9, UInt32(bitPattern: -1019803690))
        c = gg(c, d, a, b, k[3], 14, UInt32(bitPattern: -187363961))
        b = gg(b, c, d, a, k[8], 20, 1163531501)
        a = gg(a, b, c, d, k[13], 5, UInt32(bitPattern: -1444681467))
        d = gg(d, a, b, c, k[2], 9, UInt32(bitPattern: -51403784))
        c = gg(c, d, a, b, k[7], 14, 1735328473)
        b = gg(b, c, d, a, k[12], 20, UInt32(bitPattern: -1926607734))

        a = hh(a, b, c, d, k[5], 4, UInt32(bitPattern: -378558))
        d = hh(d, a, b, c, k[8], 11, UInt32(bitPattern: -2022574463))
        c = hh(c, d, a, b, k[11], 16, 1839030562)
        b = hh(b, c, d, a, k[14], 23, UInt32(bitPattern: -35309556))
        a = hh(a, b, c, d, k[1], 4, UInt32(bitPattern: -1530992060))
        d = hh(d, a, b, c, k[4], 11, 1272893353)
        c = hh(c, d, a, b, k[7], 16, UInt32(bitPattern: -155497632))
        b = hh(b, c, d, a, k[10], 23, UInt32(bitPattern: -1094730640))
        a = hh(a, b, c, d, k[13], 4, 681279174)
        d = hh(d, a, b, c, k[0], 11, UInt32(bitPattern: -358537222))
        c = hh(c, d, a, b, k[3], 16, UInt32(bitPattern: -722521979))
        b = hh(b, c, d, a, k[6], 23, 76029189)
        a = hh(a, b, c, d, k[9], 4, UInt32(bitPattern: -640364487))
        d = hh(d, a, b, c, k[12], 11, UInt32(bitPattern: -421815835))
        c = hh(c, d, a, b, k[15], 16, 530742520)
        b = hh(b, c, d, a, k[2], 23, UInt32(bitPattern: -995338651))

        a = ii(a, b, c, d, k[0], 6, UInt32(bitPattern: -198630844))
        d = ii(d, a, b, c, k[7], 10, 1126891415)
        c = ii(c, d, a, b, k[14], 15, UInt32(bitPattern: -1416354905))
        b = ii(b, c, d, a, k[5], 21, UInt32(bitPattern: -57434055))
        a = ii(a, b, c, d, k[12], 6, 1700485571)
        d = ii(d, a, b, c, k[3], 10, UInt32(bitPattern: -1894986606))
        c = ii(c, d, a, b, k[10], 15, UInt32(bitPattern: -1051523))
        b = ii(b, c, d, a, k[1], 21, UInt32(bitPattern: -2054922799))
        a = ii(a, b, c, d, k[8], 6, 1873313359)
        d = ii(d, a, b, c, k[15], 10, UInt32(bitPattern: -30611744))
        c = ii(c, d, a, b, k[6], 15, UInt32(bitPattern: -1560198380))
        b = ii(b, c, d, a, k[13], 21, 1309151649)
        a = ii(a, b, c, d, k[4], 6, UInt32(bitPattern: -145523070))
        d = ii(d, a, b, c, k[11], 10, UInt32(bitPattern: -1120210379))
        c = ii(c, d, a, b, k[2], 15, 718787259)
        b = ii(b, c, d, a, k[9], 21, UInt32(bitPattern: -343485551))

        x[0] = add32(a, x[0])
        x[1] = add32(b, x[1])
        x[2] = add32(c, x[2])
        x[3] = add32(d, x[3])
    }

    private func cmn(_ q: UInt32, _ a: UInt32, _ b: UInt32, _ x: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 {
        let sum = add32(add32(a, q), add32(x, t))
        return add32((sum << s) | (sum >> (32 - s)), b)
    }

    private func ff(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32, _ x: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 {
        return cmn((b & c) | ((~b) & d), a, b, x, s, t)
    }

    private func gg(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32, _ x: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 {
        return cmn((b & d) | (c & (~d)), a, b, x, s, t)
    }

    private func hh(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32, _ x: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 {
        return cmn(b ^ c ^ d, a, b, x, s, t)
    }

    private func ii(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32, _ x: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 {
        return cmn(c ^ (b | (~d)), a, b, x, s, t)
    }

    private func add32(_ a: UInt32, _ b: UInt32) -> UInt32 {
        return (a &+ b) & 0xFFFFFFFF
    }

    private func hex(_ state: [UInt32]) -> String {
        let hexChars = "0123456789abcdef"
        var result = ""

        for num in state {
            for j in 0..<4 {
                let byte = (num >> (j * 8)) & 0xFF
                let high = (byte >> 4) & 0xF
                let low = byte & 0xF

                let h = hexChars[hexChars.index(hexChars.startIndex, offsetBy: Int(high))]
                let l = hexChars[hexChars.index(hexChars.startIndex, offsetBy: Int(low))]
                result.append(h)
                result.append(l)
            }
        }

        return result
    }
}

// MARK: - Date Extension

extension Date {
    /// Returns ISO8601-formatted string representation, compatible with JavaScript Date.toJSON()
    func toJSON() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
