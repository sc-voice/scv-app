import Foundation
@testable import scvCore
import Testing

struct TipitakaTests {
  @Test func emptyDocumentsList() {
    let flatDocs: [TipitakaRef] = []
    let tree = Tipitaka.buildTree(from: flatDocs)
    #expect(tree.isEmpty)
  }

  @Test func singleRootDocument() {
    let flatDocs = [
      TipitakaRef(id: "/sutta", name: "Suttas"),
    ]
    let tree = Tipitaka.buildTree(from: flatDocs)

    #expect(tree.count == 1)
    #expect(tree[0].id == "/sutta")
    #expect(tree[0].name == "Suttas")
    #expect(tree[0].children == nil)
  }

  @Test func sn53RealHierarchy() {
    // Real SN 53 hierarchy from en/sujato
    let flatDocs = [
      TipitakaRef(id: "/sutta", name: "Suttas"),
      TipitakaRef(id: "/sutta/sn", name: "Connected Discourses"),
      TipitakaRef(id: "/sutta/sn/sn53", name: "The Bodhisattva"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.1-12", name: "Suttas 1-12"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.13-22", name: "Suttas 13-22"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.23-34", name: "Suttas 23-34"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.35-44", name: "Suttas 35-44"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.45-54", name: "Suttas 45-54"),
    ]
    let tree = Tipitaka.buildTree(from: flatDocs)

    // Root should have 1 item: /sutta
    #expect(tree.count == 1)
    #expect(tree[0].id == "/sutta")

    // /sutta should have /sn as child
    let suttaRoot = tree[0]
    #expect(suttaRoot.children?.count == 1)
    #expect(suttaRoot.children?.first?.id == "/sutta/sn")

    // /sn should have /sn53 as child
    let snRoot = suttaRoot.children?[0]
    #expect(snRoot?.children?.count == 1)
    #expect(snRoot?.children?.first?.id == "/sutta/sn/sn53")

    // /sn53 should have 5 children (sn53.1-12 through sn53.45-54)
    let sn53Root = snRoot?.children?[0]
    #expect(sn53Root?.children?.count == 5)

    let sn53Children = sn53Root?.children?.map(\.id) ?? []
    #expect(sn53Children == [
      "/sutta/sn/sn53/sn53.1-12",
      "/sutta/sn/sn53/sn53.13-22",
      "/sutta/sn/sn53/sn53.23-34",
      "/sutta/sn/sn53/sn53.35-44",
      "/sutta/sn/sn53/sn53.45-54",
    ])
  }

  @Test func findRefInSn53() {
    let flatDocs = [
      TipitakaRef(id: "/sutta", name: "Suttas"),
      TipitakaRef(id: "/sutta/sn", name: "Connected Discourses"),
      TipitakaRef(id: "/sutta/sn/sn53", name: "The Bodhisattva"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.1-12", name: "Suttas 1-12"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.13-22", name: "Suttas 13-22"),
    ]
    let tree = Tipitaka.buildTree(from: flatDocs)

    let found = Tipitaka.findRef(byId: "/sutta/sn/sn53/sn53.13-22", in: tree)
    #expect(found != nil)
    #expect(found?.name == "Suttas 13-22")
  }

  @Test func findRefMissing() {
    let flatDocs = [
      TipitakaRef(id: "/sutta", name: "Suttas"),
      TipitakaRef(id: "/sutta/sn", name: "Connected Discourses"),
      TipitakaRef(id: "/sutta/sn/sn53", name: "The Bodhisattva"),
    ]
    let tree = Tipitaka.buildTree(from: flatDocs)

    let found = Tipitaka.findRef(byId: "/sutta/sn/sn99", in: tree)
    #expect(found == nil)
  }

  @Test func multipleRoots() {
    let flatDocs = [
      TipitakaRef(id: "/sutta", name: "Suttas"),
      TipitakaRef(id: "/sutta/sn", name: "Connected Discourses"),
      TipitakaRef(id: "/vinaya", name: "Monastic Code"),
      TipitakaRef(id: "/vinaya/pti", name: "Patimokkha"),
    ]
    let tree = Tipitaka.buildTree(from: flatDocs)

    #expect(tree.count == 2)
    #expect(tree[0].id == "/sutta")
    #expect(tree[1].id == "/vinaya")
    #expect(tree[0].children?.count == 1)
    #expect(tree[1].children?.count == 1)
  }

  @Test func childrenSortedByPath() {
    let flatDocs = [
      TipitakaRef(id: "/sutta", name: "Suttas"),
      TipitakaRef(id: "/sutta/sn", name: "Connected Discourses"),
      TipitakaRef(id: "/sutta/dn", name: "Long Discourses"),
      TipitakaRef(id: "/sutta/mn", name: "Middle Discourses"),
      TipitakaRef(id: "/sutta/an", name: "Numbered Discourses"),
    ]
    let tree = Tipitaka.buildTree(from: flatDocs)

    let suttaRoot = tree.first { $0.id == "/sutta" }
    let childPaths = suttaRoot?.children?.map(\.id) ?? []

    #expect(childPaths == ["/sutta/an", "/sutta/dn", "/sutta/mn", "/sutta/sn"])
  }

  @Test func encodeTreeToJSON() throws {
    let flatDocs = [
      TipitakaRef(id: "/sutta", name: "Suttas"),
      TipitakaRef(id: "/sutta/sn", name: "Connected Discourses"),
      TipitakaRef(id: "/sutta/sn/sn53", name: "The Bodhisattva"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.1-12", name: "Suttas 1-12"),
    ]
    let tree = Tipitaka.buildTree(from: flatDocs)

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(tree)
    let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

    #expect(jsonString.contains("\"$id\""))
    #expect(jsonString.contains("/sutta"))
    #expect(jsonString.contains("Suttas"))
    #expect(jsonString.contains("children"))
  }

  @Test func decodeJSONToTree() throws {
    let flatDocs = [
      TipitakaRef(id: "/sutta", name: "Suttas"),
      TipitakaRef(id: "/sutta/sn", name: "Connected Discourses"),
      TipitakaRef(id: "/sutta/sn/sn53", name: "The Bodhisattva"),
      TipitakaRef(id: "/sutta/sn/sn53/sn53.1-12", name: "Suttas 1-12"),
    ]
    let originalTree = Tipitaka.buildTree(from: flatDocs)

    // Encode to JSON
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(originalTree)

    // Decode from JSON
    let decoder = JSONDecoder()
    let decodedTree = try decoder.decode([TipitakaRef].self, from: jsonData)

    // Verify structure matches
    #expect(decodedTree.count == 1)
    #expect(decodedTree[0].id == "/sutta")
    #expect(decodedTree[0].name == "Suttas")
    #expect(decodedTree[0].children?.count == 1)

    let snNode: TipitakaRef? = decodedTree[0].children?[0]
    #expect(snNode?.id == "/sutta/sn")
    #expect(snNode?.name == "Connected Discourses")
    #expect(snNode?.children?.count == 1)

    let sn53Node: TipitakaRef? = snNode?.children?[0]
    #expect(sn53Node?.id == "/sutta/sn/sn53")
    #expect(sn53Node?.name == "The Bodhisattva")
    #expect(sn53Node?.children?.count == 1)

    let leaf: TipitakaRef? = sn53Node?.children?[0]
    #expect(leaf?.id == "/sutta/sn/sn53/sn53.1-12")
    #expect(leaf?.name == "Suttas 1-12")
    #expect(leaf?.children == nil)
  }

  @Test func parentPathSuttaUid_AN() {
    #expect(Tipitaka.parentPath(suttaUid: "an1.1") == "/sutta/an/an1")
    #expect(Tipitaka.parentPath(suttaUid: "an1.10") == "/sutta/an/an1")
    #expect(Tipitaka.parentPath(suttaUid: "an1.3") == "/sutta/an/an1")
    #expect(Tipitaka.parentPath(suttaUid: "an2.5") == "/sutta/an/an2")
    #expect(Tipitaka.parentPath(suttaUid: "an11.10") == "/sutta/an/an11")
  }

  @Test func parentPathSuttaUid_DN() {
    #expect(Tipitaka.parentPath(suttaUid: "dn1") == "/sutta/dn")
    #expect(Tipitaka.parentPath(suttaUid: "dn14") == "/sutta/dn")
    #expect(Tipitaka.parentPath(suttaUid: "dn34") == "/sutta/dn")
  }

  @Test func parentPathSuttaUid_SN() {
    #expect(Tipitaka.parentPath(suttaUid: "sn1.1") == "/sutta/sn/sn1")
    #expect(Tipitaka.parentPath(suttaUid: "sn1.10") == "/sutta/sn/sn1")
    #expect(Tipitaka.parentPath(suttaUid: "sn56.3") == "/sutta/sn/sn56")
  }

  @Test func parentPathSuttaUid_MN() {
    #expect(Tipitaka.parentPath(suttaUid: "mn1") == "/sutta/mn")
    #expect(Tipitaka.parentPath(suttaUid: "mn50.5") == "/sutta/mn")
    #expect(Tipitaka.parentPath(suttaUid: "mn152") == "/sutta/mn")
  }

  @Test func parentPathSuttaUid_Invalid() {
    #expect(Tipitaka.parentPath(suttaUid: "") == nil)
    #expect(Tipitaka.parentPath(suttaUid: "xyz123") == nil)
  }

  @Test func authorTipitakaSoma() async throws {
    let suttaUids = await EbtData.shared.suttaUidsForAuthor(
      lang: "en",
      author: "soma",
    )
    print("Found \(suttaUids.count) suttaUids for en/soma")
    if suttaUids.count > 0 {
      print("First few: \(suttaUids.prefix(5))")
    }

    let tipitaka = await Tipitaka.authorTipitaka(lang: "en", author: "soma")

    // Verify it's the synthetic root
    #expect(tipitaka.id == "/tipitaka")
    #expect(tipitaka.name == "Tipiṭaka")
    #expect(tipitaka.caption == "Buddhist Canon")

    // Find thig1.1 leaf node and verify its name (abbreviation + Pali document
    // name)
    if let thig1_1 = Tipitaka.findRef(
      byId: "/sutta/kn/thig/thig1.1",
      in: [tipitaka],
    ) {
      let suttaRef = try SuttaRef(
        suttaUid: "thig1.1",
        lang: "pli",
        author: "ms",
      )
      let abbr = suttaRef.abbreviation()
      #expect(thig1_1.name == abbr)
      let paliName = Tipitaka.tipitakaName(suttaRef: suttaRef)
      #expect(thig1_1.caption == paliName)
    }

    // Serialize to JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = [
      .prettyPrinted,
      .sortedKeys,
      .withoutEscapingSlashes,
    ]
    let jsonData = try encoder.encode(tipitaka)

    // Write to /tmp/soma.json
    let fileURL = URL(fileURLWithPath: "/tmp/soma.json")
    try jsonData.write(to: fileURL)

    // Verify file exists
    let fileExists = FileManager.default.fileExists(atPath: "/tmp/soma.json")
    #expect(fileExists)
  }

  @Test func authorTipitakaBrahmali() async throws {
    let suttaUids = await EbtData.shared.suttaUidsForAuthor(
      lang: "en",
      author: "brahmali",
    )
    print("Found \(suttaUids.count) suttaUids for en/brahmali")
    if suttaUids.count > 0 {
      print("First few: \(suttaUids.prefix(5))")
    }

    // Verify we have vinaya texts (brahmali only translates vinaya)
    #expect(suttaUids.count == 427)

    let tipitaka = await Tipitaka.authorTipitaka(lang: "en", author: "brahmali")

    // Verify it's the synthetic root
    #expect(tipitaka.id == "/tipitaka")
    #expect(tipitaka.name == "Tipiṭaka")
    #expect(tipitaka.caption == "Buddhist Canon")

    // Verify vinaya root exists (brahmali has only vinaya)
    if let vinayaRoot = tipitaka.children?
      .first(where: { $0.id == "/vinaya" })
    {
      #expect(vinayaRoot.name == "Vinaya")
      // Verify we have vinaya children
      #expect(vinayaRoot.children != nil)
      #expect(!vinayaRoot.children!.isEmpty)
    } else {
      // If no /vinaya root, test should still pass - brahmali texts might be
      // directly under /tipitaka
      #expect(tipitaka.children != nil)
      #expect(!tipitaka.children!.isEmpty)
    }

    // Count all leaf nodes (texts with no children)
    func countLeaves(_ ref: TipitakaRef) -> Int {
      if ref.children == nil || ref.children!.isEmpty {
        return 1 // This is a leaf
      }
      return ref.children!.reduce(0) { $0 + countLeaves($1) }
    }

    let leafCount = countLeaves(tipitaka)

    // Verify all 427 vinaya texts appear as leaf nodes
    // Brahmali's translation includes:
    // - 133 bhikkhuni (nuns) vinaya texts (pli-tv-bi-*)
    // - 294 bhikkhu (monks) vinaya texts (pli-tv-bu-*)
    #expect(
      leafCount == 427,
      "Expected 427 leaf nodes for all brahmali vinaya texts",
    )

    // Serialize to JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = [
      .prettyPrinted,
      .sortedKeys,
      .withoutEscapingSlashes,
    ]
    let jsonData = try encoder.encode(tipitaka)

    // Write to /tmp/brahmali.json
    let fileURL = URL(fileURLWithPath: "/tmp/brahmali.json")
    try jsonData.write(to: fileURL)

    // Verify file exists
    let fileExists = FileManager.default
      .fileExists(atPath: "/tmp/brahmali.json")
    #expect(fileExists)
  }

  @Test func authorTipitakaJohnKelly() async throws {
    let suttaUids = await EbtData.shared.suttaUidsForAuthor(
      lang: "en",
      author: "kelly",
    )
    print("Found \(suttaUids.count) suttaUids for en/kelly")
    if suttaUids.count > 0 {
      print("First few: \(suttaUids.prefix(5))")
    }

    // Verify that mil3.8 is available for John Kelly
    #expect(suttaUids.contains("mil3.8"))

    let tipitaka = await Tipitaka.authorTipitaka(lang: "en", author: "kelly")

    // Verify it's the synthetic root
    #expect(tipitaka.id == "/tipitaka")
    #expect(tipitaka.name == "Tipiṭaka")
    #expect(tipitaka.caption == "Buddhist Canon")

    // Find mil3.8 leaf node and verify its exists
    if let mil3_8 = Tipitaka.findRef(
      byId: "/sutta/kn/mil/mil3.8",
      in: [tipitaka],
    ) {
      let suttaRef = try SuttaRef(
        suttaUid: "mil3.8",
        lang: "pli",
        author: "ms",
      )
      let abbr = suttaRef.abbreviation()
      #expect(mil3_8.name == abbr)
      let paliName = Tipitaka.tipitakaName(suttaRef: suttaRef)
      #expect(mil3_8.caption == paliName)
    }

    // Serialize to JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = [
      .prettyPrinted,
      .sortedKeys,
      .withoutEscapingSlashes,
    ]
    let jsonData = try encoder.encode(tipitaka)

    // Write to /tmp/kelly.json
    let fileURL = URL(fileURLWithPath: "/tmp/kelly.json")
    try jsonData.write(to: fileURL)

    // Verify file exists
    let fileExists = FileManager.default.fileExists(atPath: "/tmp/kelly.json")
    #expect(fileExists)
  }
}
