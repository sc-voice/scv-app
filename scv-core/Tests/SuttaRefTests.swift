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
    #expect(testStr("thig1.1", "de") == "thig1.1/de")
    #expect(testStr("thig1.1:2.3", "de") == "thig1.1:2.3/de")
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

  @Test("createOpts() creates copy") func createOptsCopy() {
    let sref1 = SuttaRef.createOpts("thig1.1")
    let sref2 = SuttaRef.createOpts(sref1)

    #expect(sref1 == sref2)
    // Structs are values, not references, so === doesn't apply
    // Just verify they are equal and separate instances
  }

  @Test("createOpts() with undefined") func createOptsUndefined() {
    let result1 = SuttaRef.createOpts(nil)
    #expect(result1 == nil)

    let result2 = SuttaRef.createOpts(nil, opts: [:])
    #expect(result2 == nil)
  }

  @Test("createOpts() preserves parameters") func createOptsPreserves() {
    let opts1 = SuttaRef.createOpts("an1.31-40/jpn/kaz")
    let create1 = SuttaRef.create("an1.31-40/jpn/kaz")
    #expect(opts1 == create1)

    let opts2 = SuttaRef.createOpts("an1.31-40/jpn")
    let create2 = SuttaRef.create("an1.31-40/jpn")
    #expect(opts2 == create2)

    let opts3 = SuttaRef.createOpts("thig1.1/en/soma")
    let create3 = SuttaRef.create("thig1.1/en/soma")
    #expect(opts3 == create3)
  }

  @Test("createOpts() with defaultLang") func createOptsDefaultLang() {
    let defaultLang = "de"
    let opts = SuttaRef.createOpts(
      "thig1.1",
      opts: ["defaultLang": defaultLang],
    )
    let create = SuttaRef.create("thig1.1", defaultLang: defaultLang)

    #expect(opts == create)
    #expect(opts?.lang == "de")
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
      var set: Set<SuttaRef> = [r1, r3]
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
}
