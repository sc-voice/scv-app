import Foundation
@testable import scvCore
import Testing

@Suite struct MerkleJsonTests {

    // MARK: - MD5 Basic Tests

    @Test("MD5 hash of empty string matches known value")
    func md5EmptyString() {
        let mj = MerkleJson()
        #expect(mj.hash("") == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @Test("MD5 hash of 'hello\\n' matches known value")
    func md5HelloNewline() {
        let mj = MerkleJson()
        #expect(mj.hash("hello\n") == "b1946ac92492d2347c6235b4d2611184")
    }

    @Test("MD5 hash of single space matches known value")
    func md5Space() {
        let mj = MerkleJson()
        #expect(mj.hash(" ") == "7215ee9c7d9dc229d2921a40e899ec5f")
    }

    @Test("MD5 hash of 'HTML' matches known value")
    func md5HTML() {
        let mj = MerkleJson()
        #expect(mj.hash("HTML") == "4c4ad5fca2e7a3f74dbb1ced00381aa4")
    }

    @Test("MD5 hashes are consistent")
    func md5Consistency() {
        let mj = MerkleJson()
        let hash1 = mj.hash("hello")
        let hash2 = mj.hash("hello")
        #expect(hash1 == hash2)
    }

    @Test("MD5 hashes differ for different strings")
    func md5Differs() {
        let mj = MerkleJson()
        let hash1 = mj.hash("hello")
        let hash2 = mj.hash("goodbye")
        #expect(hash1 != hash2)
    }

    // MARK: - Number Tests

    @Test("Number hashed same as string representation")
    func numberHashesSameAsString() {
        let mj = MerkleJson()
        #expect(mj.hash("123") == mj.hash(123))
        #expect(mj.hash("123.456") == mj.hash(123.456))
    }

    // MARK: - Null/Boolean Tests

    @Test("Null hashed as 'null' string")
    func nullHashesAsString() {
        let mj = MerkleJson()
        #expect(mj.hash("null") == mj.hash(NSNull()))
    }

    @Test("Boolean hashed as string representation")
    func booleanHashesAsString() {
        let mj = MerkleJson()
        #expect(mj.hash(true) == mj.hash("true"))
        #expect(mj.hash(false) == mj.hash("false"))
    }

    // MARK: - Array Tests

    @Test("Array with single element equals hash of that element")
    func arraySingleElement() {
        let mj = MerkleJson()
        #expect(mj.hash(["HTML"]) == mj.hash(mj.hash("HTML")))
    }

    @Test("Array merkle hash: [HT, ML] equals hash(hash(HT)+hash(ML))")
    func arrayMerkleHash() {
        let mj = MerkleJson()
        let hashHT = mj.hash("HT")
        let hashML = mj.hash("ML")
        #expect(mj.hash(["HT", "ML"]) == mj.hash(hashHT + hashML))
    }

    @Test("Array merkle hash: [1, 2] equals hash(hash(1)+hash(2))")
    func arrayMerkleHashNumbers() {
        let mj = MerkleJson()
        let hash1 = mj.hash(1)
        let hash2 = mj.hash(2)
        #expect(mj.hash([1, 2]) == mj.hash(hash1 + hash2))
    }

    // MARK: - Dictionary Tests

    @Test("Objects with sorted keys produce same hash")
    func objectSortedKeys() {
        let mj = MerkleJson()
        let obj1: [String: Any] = ["a": 1, "b": 2]
        let obj2: [String: Any] = ["b": 2, "a": 1]
        #expect(mj.hash(obj1) == mj.hash(obj2))
    }

    @Test("Dictionary hash respects key order (canonical)")
    func dictionaryCanonical() {
        let mj = MerkleJson()
        let obj: [String: Any] = ["a": 1]
        let expected = mj.hash("a:" + mj.hash(1) + ",")
        #expect(mj.hash(obj) == expected)
    }

    @Test("Complex object with multiple keys")
    func complexObject() {
        let mj = MerkleJson()
        let obj: [String: Any] = ["a": 1, "b": 2]
        let hashA = mj.hash(1)
        let hashB = mj.hash(2)
        let expected = mj.hash("a:" + hashA + ",b:" + hashB + ",")
        #expect(mj.hash(obj) == expected)
    }

    // MARK: - Merkle Hash Tag Tests

    @Test("merkleHash field is honored when cached=true")
    func merkleHashTag() {
        let mj = MerkleJson()
        let hashTag = "2d21a6576194aeb1de7aea4d6726624d"
        let obj: [String: Any?] = ["anything": "ignored", "merkleHash": hashTag]
        #expect(mj.hash(obj, cached: true) == hashTag)
    }

    @Test("merkleHash field ignored when cached=false")
    func merkleHashTagIgnored() {
        let mj = MerkleJson()
        let hashTag = "2d21a6576194aeb1de7aea4d6726624d"
        let obj: [String: Any?] = ["anything": "value", "merkleHash": hashTag]
        let result = mj.hash(obj, cached: false)
        #expect(result != hashTag)
    }

    // MARK: - Date Tests

    @Test("Date hashed via ISO8601 toJSON()")
    func dateHashesViaJSON() {
        let mj = MerkleJson()
        let date = Date(timeIntervalSince1970: 1518604800) // 2018-02-14T00:00:00Z
        let obj: [String: Any] = ["t": date]
        let obj2: [String: Any] = ["t": date]
        #expect(mj.hash(obj) == mj.hash(obj2))
    }

    @Test("Different dates produce different hashes")
    func differentDatesHashDifferently() {
        let mj = MerkleJson()
        let date1 = Date(timeIntervalSince1970: 1518604800)
        let date2 = Date(timeIntervalSince1970: 1518691200)
        let obj1: [String: Any] = ["t": date1]
        let obj2: [String: Any] = ["t": date2]
        #expect(mj.hash(obj1) != mj.hash(obj2))
    }
}
