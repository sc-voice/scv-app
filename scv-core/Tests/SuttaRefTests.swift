//
//  SuttaRefTests.swift
//  scv-coreTests
//
//  Created by Claude on 2025-11-20.
//

import Foundation

@testable import scvCore
import Testing

@Suite struct SuttaRefTests {
  @Test("default ctor throws") func defaultCtorThrows() {
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "", lang: "pli")
    }
  }

  @Test("custom ctor succeeds") func customCtor() {
    let suttaUid = "thig1.1"
    let lang = "tst-lang"
    let author = "tst-author"
    let segnum = "0.1"

    let ref = try? SuttaRef(
      suttaUid: suttaUid,
      lang: lang,
      author: author,
      segnum: segnum,
    )

    #expect(ref?.suttaUid == suttaUid)
    #expect(ref?.lang == lang)
    #expect(ref?.author == author)
    #expect(ref?.segnum == segnum)

    // Test copy
    if let original = ref {
      let copy = try? SuttaRef(
        suttaUid: original.suttaUid,
        lang: original.lang,
        author: original.author,
        segnum: original.segnum,
        scid: original.scid,
      )
      #expect(copy?.suttaUid == suttaUid)
      #expect(copy?.lang == lang)
      #expect(copy?.author == author)
      #expect(copy?.segnum == segnum)
    }
  }

  @Test("create() with jpn language") func createJpn() {
    let suttaUid = "an1.31-40"
    let lang = "jpn"
    let author = "kaz"

    let ref1 = SuttaRef.create(suttaUid, defaultLang: lang)
    #expect(ref1?.suttaUid == suttaUid)
    #expect(ref1?.lang == lang)
    #expect(ref1?.author == nil)

    let ref2 = SuttaRef.create("\(suttaUid)/\(lang)/\(author)")
    #expect(ref2?.suttaUid == suttaUid)
    #expect(ref2?.lang == lang)
    #expect(ref2?.author == author)
  }

  @Test("create() string reference") func createString() {
    let suttaUid = "thig1.1"
    let lang = "tst-lang"
    let author = "tst-author"
    let segnum = "0.1"

    // sutta_uid/lang/author:segnum
    let ref1 = SuttaRef.create("\(suttaUid)/\(lang)/\(author):\(segnum)")
    #expect(ref1?.suttaUid == suttaUid)
    #expect(ref1?.lang == lang)
    #expect(ref1?.author == author)
    #expect(ref1?.segnum == segnum)

    // sutta_uid/lang/author
    let ref2 = SuttaRef.create("\(suttaUid)/\(lang)/\(author)")
    #expect(ref2?.suttaUid == suttaUid)
    #expect(ref2?.lang == lang)
    #expect(ref2?.author == author)
    #expect(ref2?.segnum == nil)

    // sutta_uid/lang
    let ref3 = SuttaRef.create("\(suttaUid)/\(lang)")
    #expect(ref3?.suttaUid == suttaUid)
    #expect(ref3?.lang == lang)
    #expect(ref3?.author == nil)

    // sutta_uid/lang:segnum
    let ref4 = SuttaRef.create("\(suttaUid)/\(lang):\(segnum)")
    #expect(ref4?.suttaUid == suttaUid)
    #expect(ref4?.lang == lang)
    #expect(ref4?.author == nil)
    #expect(ref4?.segnum == segnum)

    // sutta_uid only (defaults to pli/ms)
    let ref5 = SuttaRef.create(suttaUid)
    #expect(ref5?.suttaUid == suttaUid)
    #expect(ref5?.lang == "pli")
    #expect(ref5?.author == "ms")

    // sutta_uid:segnum
    let ref6 = SuttaRef.create("\(suttaUid):\(segnum)")
    #expect(ref6?.suttaUid == suttaUid)
    #expect(ref6?.lang == "pli")
    #expect(ref6?.author == "ms")
    #expect(ref6?.segnum == segnum)
  }

  @Test("create() with defaultLang") func createWithDefaultLang() {
    let suttaUid = "thig1.1"
    let lang = "tst-lang"
    let author = "tst-author"
    let segnum = "0.1"
    let defaultLang = "default-lang"

    let ref1 = SuttaRef.create(
      "\(suttaUid):\(segnum)/\(lang)/\(author)",
      defaultLang: defaultLang,
    )
    #expect(ref1?.suttaUid == suttaUid)
    #expect(ref1?.lang == lang)
    #expect(ref1?.author == author)
    #expect(ref1?.segnum == segnum)

    let ref2 = SuttaRef.create("\(suttaUid)", defaultLang: defaultLang)
    #expect(ref2?.suttaUid == suttaUid)
    #expect(ref2?.lang == defaultLang)
    #expect(ref2?.author == nil)
  }

  @Test("create() object") func createObject() {
    let suttaUid = "thig1.1"
    let lang = "tst-lang"
    let author = "tst-author"
    let segnum = "0.1"

    let ref1 = SuttaRef.create([
      "sutta_uid": suttaUid,
      "lang": lang,
      "author": author,
      "segnum": segnum,
    ])
    #expect(ref1?.suttaUid == suttaUid)
    #expect(ref1?.lang == lang)
    #expect(ref1?.author == author)
    #expect(ref1?.segnum == segnum)

    let ref2 = SuttaRef.create(["sutta_uid": suttaUid])
    #expect(ref2?.suttaUid == suttaUid)
    #expect(ref2?.lang == "pli")
    #expect(ref2?.author == "ms")
  }

  @Test("create() translator legacy field") func createTranslator() {
    let suttaUid = "thig1.1"
    let lang = "tst-lang"
    let translator = "tst-translator"
    let segnum = "0.1"

    let ref = SuttaRef.create([
      "sutta_uid": suttaUid,
      "lang": lang,
      "translator": translator,
      "segnum": segnum,
    ])
    #expect(ref?.suttaUid == suttaUid)
    #expect(ref?.lang == lang)
    #expect(ref?.author == translator)
    #expect(ref?.segnum == segnum)
  }

  @Test("toString()") func testToString() {
    let suttaUid = "thig1.1"
    let lang = "de"
    let translator = "sabbamitta"
    let segnum = "2.3"

    func testObj(_ obj: [String: Any], _ lang: String? = nil) -> String? {
      let ref = SuttaRef.create(obj, defaultLang: lang ?? "pli")
      return ref?.toString()
    }

    func testStr(_ str: String, _ lang: String? = nil) -> String? {
      let ref = SuttaRef.create(str, defaultLang: lang ?? "pli")
      return ref?.toString()
    }

    #expect(
      testObj([
        "sutta_uid": suttaUid,
        "lang": lang,
        "translator": translator,
      ])
        == "thig1.1/de/sabbamitta",
    )

    #expect(
      testObj([
        "sutta_uid": suttaUid,
        "lang": lang,
        "translator": translator,
        "segnum": segnum,
      ])
        == "thig1.1:2.3/de/sabbamitta",
    )

    #expect(
      testObj(["sutta_uid": "thig1.1:2.3/de/sabbamitta"])
        == "thig1.1:2.3/de/sabbamitta",
    )

    #expect(
      testObj(["sutta_uid": "thig1.1"]) == "thig1.1/pli/ms",
    )

    // String references
    #expect(testStr("thig1.1/en/soma") == "thig1.1/en/soma")
    #expect(testStr("thig1.1") == "thig1.1/pli/ms")
    #expect(testStr("thig1.1:2.3") == "thig1.1:2.3/pli/ms")
    #expect(testStr("thig1.1", "de") == "thig1.1/de/sabbamitta")
    #expect(testStr("thig1.1:2.3", "de") == "thig1.1:2.3/de/sabbamitta")
  }

  @Test("create() invalid reference") func createInvalid() {
    #expect(SuttaRef.create("xyz") == nil)
    #expect(SuttaRef.create("aaa") == nil)
    #expect(SuttaRef.create("test-bad!!!") == nil)
  }

  @Test("createWithError() throws") func testCreateWithError() {
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef.createWithError("xyz")
    }
  }

  @Test("create() creates copy") func createCopy() {
    let sref1 = SuttaRef.create("thig1.1")
    let sref2 = SuttaRef.create(sref1)

    #expect(sref1 == sref2)
    // Structs are values, not references, so === doesn't apply
    // Just verify they are equal and separate instances
  }

  @Test("Equatable and Hashable") func equatableHashable() {
    let ref1 = try? SuttaRef(
      suttaUid: "thig1.1",
      lang: "en",
      author: "soma",
    )
    let ref2 = try? SuttaRef(
      suttaUid: "thig1.1",
      lang: "en",
      author: "soma",
    )
    let ref3 = try? SuttaRef(
      suttaUid: "thig1.1",
      lang: "de",
      author: "sabbamitta",
    )

    // Equatable
    #expect(ref1 == ref2)
    #expect(ref1 != ref3)

    // Hashable (can be used in sets/dicts)
    if let r1 = ref1, let r2 = ref2, let r3 = ref3 {
      let set: Set<SuttaRef> = [r1, r3]
      #expect(set.contains(r2)) // r2 == r1, so should be in set
      #expect(set.count == 2)
    }
  }

  @Test("CustomStringConvertible") func description() {
    let ref = try? SuttaRef(
      suttaUid: "thig1.1",
      lang: "en",
      author: "soma",
      segnum: "2.3",
    )

    #expect(ref.map { String(describing: $0) } == "thig1.1:2.3/en/soma")
  }

  @Test(
    "createFromString with defaultAuthor parameter",
  ) func createFromStringWithDefaultAuthor() {
    // Test 1: Non-Pali with defaultAuthor uses provided author
    let ref1 = try? SuttaRef.createFromString(
      "mn1",
      defaultLang: "en",
      defaultAuthor: "soma",
    )
    #expect(ref1?.lang == "en")
    #expect(ref1?.author == "soma")

    // Test 2: Explicit lang, Pali still gets "ms"
    let ref2 = try? SuttaRef.createFromString(
      "mn1",
      defaultLang: "pli",
      defaultAuthor: "soma",
    )
    #expect(ref2?.lang == "pli")
    #expect(ref2?.author == "ms")

    // Test 3: Explicit author in query overrides defaultAuthor
    let ref3 = try? SuttaRef.createFromString(
      "mn1/en/other",
      defaultLang: "de",
      defaultAuthor: "soma",
    )
    #expect(ref3?.lang == "en")
    #expect(ref3?.author == "other")

    // Test 4: Non-Pali without defaultAuthor gets nil
    let ref4 = try? SuttaRef.createFromString(
      "mn1",
      defaultLang: "en",
      defaultAuthor: nil,
    )
    #expect(ref4?.lang == "en")
    #expect(ref4?.author == "sujato")
  }

  @Test(
    "abbreviation() method returns correct collection abbreviations",
  ) func abbreviation() {
    // Standard cases - uppercase with numbers
    #expect(SuttaRef.create("mn1")?.abbreviation() == "MN1")
    // an1.1 resolves to range document an1.1-10
    #expect(SuttaRef.create("an1.1")?.abbreviation() == "AN1.1-10")
    #expect(SuttaRef.create("sn22.1")?.abbreviation() == "SN22.1")
    #expect(SuttaRef.create("dn1")?.abbreviation() == "DN1")

    // Mixed case input - should normalize to lowercase
    #expect(SuttaRef.create("MN1")?.abbreviation() == "MN1")
    // An1.1 resolves to range document an1.1-10
    #expect(SuttaRef.create("An1.1")?.abbreviation() == "AN1.1-10")

    // Mixed case in mapping (snp -> Snp) - preserves case from mapping
    #expect(SuttaRef.create("snp1.1")?.abbreviation() == "Snp1.1")
    #expect(SuttaRef.create("SNP1.1")?.abbreviation() == "Snp1.1")

    // Complex numbers and ranges
    #expect(SuttaRef.create("an1.1-10")?.abbreviation() == "AN1.1-10")

    // Unknown prefix - invalid sutta returns nil
    #expect(SuttaRef.create("xyz123") == nil)
  }

  @Test("SuttaRef rejects invalid lang with path traversal")
  func invalidLangPathTraversal() {
    // Path traversal attempts
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "../", author: "test")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "..\\", author: "test")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "test/../../etc", author: "test")
    }
  }

  @Test("SuttaRef rejects invalid lang with special characters")
  func invalidLangSpecialChars() {
    // Special characters not allowed
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en!", author: "test")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en@test", author: "test")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en#", author: "test")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en$", author: "test")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en%", author: "test")
    }
  }

  @Test("SuttaRef rejects invalid author with path traversal")
  func invalidAuthorPathTraversal() {
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "../")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "..\\")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "test/../../../etc")
    }
  }

  @Test("SuttaRef rejects invalid author with special characters")
  func invalidAuthorSpecialChars() {
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "soma!")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "suju@to")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "soma#")
    }
  }

  @Test("SuttaRef accepts valid lang and author formats")
  func validLangAuthorFormats() {
    // Lowercase alphanumeric
    let ref1 = try? SuttaRef(suttaUid: "mn1", lang: "en", author: "soma")
    #expect(ref1?.lang == "en")
    #expect(ref1?.author == "soma")

    // With hyphens
    let ref2 = try? SuttaRef(
      suttaUid: "mn1",
      lang: "pt-pt",
      author: "test-author",
    )
    #expect(ref2?.lang == "pt-pt")
    #expect(ref2?.author == "test-author")

    // With underscores
    let ref3 = try? SuttaRef(
      suttaUid: "mn1",
      lang: "en_gb",
      author: "test_author",
    )
    #expect(ref3?.lang == "en_gb")
    #expect(ref3?.author == "test_author")

    // Mixed numbers and letters
    let ref4 = try? SuttaRef(
      suttaUid: "mn1",
      lang: "en123",
      author: "author456",
    )
    #expect(ref4?.lang == "en123")
    #expect(ref4?.author == "author456")

    // Nil author (optional)
    let ref5 = try? SuttaRef(suttaUid: "mn1", lang: "pli", author: nil)
    #expect(ref5?.lang == "pli")
    #expect(ref5?.author == nil)
  }

  @Test("SuttaRef rejects uppercase in lang and author")
  func rejectsUppercaseLangAuthor() {
    // Lang must be lowercase
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "EN", author: "test")
    }

    // Author must be lowercase
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "Soma")
    }

    // Mixed case in author
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "SoJa")
    }
  }

  @Test("SuttaRef rejects spaces in lang and author")
  func rejectsSpacesLangAuthor() {
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en us", author: "test")
    }
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef(suttaUid: "mn1", lang: "en", author: "soma test")
    }
  }

  @Test("create() accepts pli-tv-bi-* (bhikkhuni vinaya texts)")
  func createPaliVinayaBhikkhuni() {
    // pli-tv-bi-pm (bhikkhuni patimokkha)
    let ref1 = SuttaRef.create("pli-tv-bi-pm")
    #expect(ref1?.suttaUid == "pli-tv-bi-pm")
    #expect(ref1?.lang == "pli")
    #expect(ref1?.author == "ms")

    // pli-tv-bi-vb-pj1 (bhikkhuni parajika)
    let ref2 = SuttaRef.create("pli-tv-bi-vb-pj1")
    #expect(ref2?.suttaUid == "pli-tv-bi-vb-pj1")
    #expect(ref2?.lang == "pli")

    // With language and author specified
    let ref3 = SuttaRef.create("pli-tv-bi-vb-np5/en/brahmali")
    #expect(ref3?.suttaUid == "pli-tv-bi-vb-np5")
    #expect(ref3?.lang == "en")
    #expect(ref3?.author == "brahmali")
  }

  @Test("create() accepts pli-tv-bu-* (bhikkhu vinaya texts)")
  func createPaliVinayaBhikkhu() {
    // pli-tv-bu-pm (bhikkhu patimokkha)
    let ref1 = SuttaRef.create("pli-tv-bu-pm")
    #expect(ref1?.suttaUid == "pli-tv-bu-pm")
    #expect(ref1?.lang == "pli")

    // pli-tv-bu-vb-pj1 (bhikkhu parajika)
    let ref2 = SuttaRef.create("pli-tv-bu-vb-pj1")
    #expect(ref2?.suttaUid == "pli-tv-bu-vb-pj1")

    // With language and author
    let ref3 = SuttaRef.create("pli-tv-bu-vb-pc50/en/brahmali")
    #expect(ref3?.suttaUid == "pli-tv-bu-vb-pc50")
    #expect(ref3?.lang == "en")
    #expect(ref3?.author == "brahmali")
  }

  @Test("create() accepts pli-tv-kd-* (Khandhaka texts)")
  func createPaliKhandhaka() {
    // pli-tv-kd1 through pli-tv-kd22
    let ref1 = SuttaRef.create("pli-tv-kd1")
    #expect(ref1?.suttaUid == "pli-tv-kd1")
    #expect(ref1?.lang == "pli")

    let ref2 = SuttaRef.create("pli-tv-kd22/en/brahmali")
    #expect(ref2?.suttaUid == "pli-tv-kd22")
    #expect(ref2?.lang == "en")
    #expect(ref2?.author == "brahmali")
  }

  @Test("create() accepts pli-tv-pvr-* (Parivara texts)")
  func createPaliParivara() {
    // pli-tv-pvr1.1 through pli-tv-pvr11
    let ref1 = SuttaRef.create("pli-tv-pvr1.1")
    #expect(ref1?.suttaUid == "pli-tv-pvr1.1")
    #expect(ref1?.lang == "pli")

    let ref2 = SuttaRef.create("pli-tv-pvr11/en/brahmali")
    #expect(ref2?.suttaUid == "pli-tv-pvr11")
    #expect(ref2?.lang == "en")
    #expect(ref2?.author == "brahmali")
  }

  @Test("create() pali vinaya with custom lang/author")
  func createPaliVinayaCustom() {
    // Direct constructor with pli-tv-* UID
    let ref = try? SuttaRef(
      suttaUid: "pli-tv-bi-vb-np1",
      lang: "en",
      author: "brahmali",
    )
    #expect(ref?.suttaUid == "pli-tv-bi-vb-np1")
    #expect(ref?.lang == "en")
    #expect(ref?.author == "brahmali")
    #expect(ref?.scid == "pli-tv-bi-vb-np1")

    // With segment number
    let ref2 = try? SuttaRef(
      suttaUid: "pli-tv-bu-vb-pc1",
      lang: "en",
      author: "brahmali",
      segnum: "1.1",
    )
    #expect(ref2?.suttaUid == "pli-tv-bu-vb-pc1")
    #expect(ref2?.segnum == "1.1")
    #expect(ref2?.scid == "pli-tv-bu-vb-pc1:1.1")
  }

  @Test("toString() for pali vinaya texts")
  func toStringPaliVinaya() {
    let ref1 = SuttaRef.create("pli-tv-bi-pm")
    #expect(ref1?.toString() == "pli-tv-bi-pm/pli/ms")

    let ref2 = SuttaRef.create("pli-tv-bu-vb-pj1/en/brahmali")
    #expect(ref2?.toString() == "pli-tv-bu-vb-pj1/en/brahmali")

    let ref3 = SuttaRef.create("pli-tv-kd1/en/brahmali:1.5")
    #expect(ref3?.toString() == "pli-tv-kd1:1.5/en/brahmali")
  }

  @Test("documentsWithMultipleSuttaUids")
  func documentsWithMultipleSuttaUids() {
    let ref = SuttaRef.create("an1.1:0.2/de/sabbamitta")

    #expect(ref?.suttaUid == "an1.1-10")
    #expect(ref?.segnum == "0.2")
    #expect(ref?.lang == "de")
    #expect(ref?.author == "sabbamitta")
    #expect(ref?.scid == "an1.1:0.2")
    // toString() uses scid when present
    #expect(ref?.toString() == "an1.1:0.2/de/sabbamitta")
  }

  @Test("loadSortedSuids returns non-empty list of document UIDs")
  func loadSortedSuids() {
    let suids = SuttaRef.loadSortedSuids()

    // Should return non-empty list
    #expect(!suids.isEmpty)

    // Should contain expected range documents
    #expect(suids.contains("an1.1-10"))
    #expect(suids.contains("mn1"))

    // Should be sorted using same logic as SuidListBuilder
    for i in 0 ..< suids.count - 1 {
      let cmpLow = SuttaCentralId.compareLow(suids[i], suids[i + 1])
      let isSorted = if cmpLow != 0 {
        cmpLow < 0
      } else {
        SuttaCentralId.compareHigh(suids[i], suids[i + 1]) < 0
      }
      #expect(isSorted)
    }
  }

  @Test("findSuttaUidInRange resolves individual sutta to range document")
  func findSuttaUidInRange() {
    let suids = ["an1.1-10", "an1.11-20", "mn1"]

    // an1.1-10 should resolve to itself (exact match to a range document)
    let resultExact = try? SuttaRef.findSuttaUidInRange("an1.1-10", in: suids)
    #expect(resultExact == "an1.1-10")

    // an1.2-3 is a range within an1.1-10, should resolve to an1.1-10
    let resultRange = try? SuttaRef.findSuttaUidInRange("an1.2-3", in: suids)
    #expect(resultRange == "an1.1-10")

    // an1.1 should resolve to an1.1-10
    let result1 = try? SuttaRef.findSuttaUidInRange("an1.1", in: suids)
    #expect(result1 == "an1.1-10")

    // an1.5 should also resolve to an1.1-10
    let result2 = try? SuttaRef.findSuttaUidInRange("an1.5", in: suids)
    #expect(result2 == "an1.1-10")

    // an1.10 should resolve to an1.1-10 (edge case: at end of range)
    let result2b = try? SuttaRef.findSuttaUidInRange("an1.10", in: suids)
    #expect(result2b == "an1.1-10")

    // an1.15 should resolve to an1.11-20
    let result3 = try? SuttaRef.findSuttaUidInRange("an1.15", in: suids)
    #expect(result3 == "an1.11-20")

    // an1.11 should resolve to an1.11-20 (edge case: at start of range)
    let result3b = try? SuttaRef.findSuttaUidInRange("an1.11", in: suids)
    #expect(result3b == "an1.11-20")

    // an1.20 should resolve to an1.11-20 (edge case: at end of range)
    let result3c = try? SuttaRef.findSuttaUidInRange("an1.20", in: suids)
    #expect(result3c == "an1.11-20")

    // an1.5-11 spans multiple documents so it cannot be resolved (returns nil)
    let result5 = try? SuttaRef.findSuttaUidInRange("an1.5-11", in: suids)
    #expect(result5 == nil)

    // mn1 should resolve to itself (single-item range/non-range)
    let result4 = try? SuttaRef.findSuttaUidInRange("mn1", in: suids)
    #expect(result4 == "mn1")

    // an2.1 is out of range (after all documents)
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef.findSuttaUidInRange("an2.1", in: suids)
    }

    // an1.0 is out of range (before first document)
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef.findSuttaUidInRange("an1.0", in: suids)
    }

    // Empty suids list should throw
    #expect(throws: SuttaRefError.self) {
      _ = try SuttaRef.findSuttaUidInRange("an1.1", in: [])
    }
  }
}
