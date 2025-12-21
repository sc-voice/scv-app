import CoreFoundation
import Foundation
import NaturalLanguage
@testable import scvCore
import Testing

@Suite("EbtData Tests")
struct EbtDataTests {
  let cc = ColorConsole(#file, #function, dbg.EbtData.other)

  @Test("searchSuttaRef returns single result for valid sutta reference")
  func searchSuttaRefValid() async {
    await EbtData.shared.clearDatabaseCache()
    let initResult = await EbtData.shared.initSeekerResult(
      "mn1",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
    )
    let result = await EbtData.shared.searchSuttaRef(initResult)

    #expect(result.items.count == 1)
    #expect(result.items[0].suttaRef.suttaUid == "mn1")
    #expect(result.items[0].score == 1.0)
    #expect(result.metadata.method == .suttaref)
    #expect(result.metadata.query == "mn1")
    #expect(result.error == nil)
  }

  @Test("searchSuttaRef with full reference mn1/en/sujato")
  func searchSuttaRefFull() async {
    let initResult = await EbtData.shared.initSeekerResult(
      "mn1/en/sujato",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
    )
    let result = await EbtData.shared.searchSuttaRef(initResult)

    #expect(result.items.count == 1)
    #expect(result.items[0].suttaRef.suttaUid == "mn1")
    #expect(result.metadata.method == .suttaref)
    #expect(result.error == nil)
  }

  @Test("searchSuttaRef with invalid reference returns error")
  func searchSuttaRefInvalid() async {
    let initResult = await EbtData.shared.initSeekerResult(
      "not-a-valid-sutta-ref!!!",
      docLang: "en",
      docAuthor: "sujato",
      refLang: "pli",
      refAuthor: "ms",
      maxResults: 10,
      method: .suttaref,
    )
    let result = await EbtData.shared.searchSuttaRef(initResult)

    #expect(result.items.isEmpty)
    #expect(result.error != nil)
    #expect(result.metadata.method == .suttaref)
  }

  #if false
    @Test(
      "searchKeywords returns SeekerResult with correct ordering for root of suffering",
    )
    func searchKeywordsRootOfSuffering() async {
      await EbtData.shared.clearDatabaseCache()
      let initResult = await EbtData.shared.initSeekerResult(
        "root of suffering",
        docLang: "en",
        docAuthor: "sujato",
        refLang: "pli",
        refAuthor: "ms",
        maxResults: 10,
        method: .keyword,
      )
      let result = await EbtData.shared.searchKeywords(initResult)

      let expectedKeys = [
        "sn42.11/en/sujato",
        "mn105/en/sujato",
        "mn1/en/sujato",
        "an4.257/en/sujato",
        "sn56.21/en/sujato",
        "mn116/en/sujato",
        "mn9/en/sujato",
        "mn66/en/sujato",
        "dn16/en/sujato",
      ]

      // Validate SeekerResult structure
      #expect(result.error == nil)
      #expect(result.items.count == 9)

      // Validate metadata
      #expect(result.metadata.method == .keyword)
      #expect(result.metadata.query == "root of suffering")
      #expect(result.metadata.docLang == "en")
      #expect(result.metadata.docAuthor == "sujato")
      #expect(result.metadata.elapsedTime > 0)

      // Validate exact ordering and keys
      let resultStrings = result.items.map { "\($0.suttaRef)" }
      for (i, expected) in expectedKeys.enumerated() {
        #expect(
          i < resultStrings.count,
          "Result count \(resultStrings.count) less than expected \(expectedKeys.count)",
        )
        #expect(
          resultStrings[i] == expected,
          "Result at index \(i): got '\(resultStrings[i])' expected '\(expected)'",
        )
      }

      // Validate all scores are positive
      for item in result.items {
        #expect(item.score > 0, "Score should be positive for \(item.suttaRef)")
      }
    }
  #endif

  @Test("asSuttaCentralJson matches source file formatting")
  func asSuttaCentralJsonFormatting() async {
    guard let suttaRef = SuttaRef.create("an1.1-10/en/sujato") else {
      Issue.record("Failed to create SuttaRef")
      return
    }
    let mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)

    #expect(mlDoc != nil)
    guard let mlDoc else { return }

    // Load source file to compare formatting
    let sourceFile = "/Users/visakha/dev/scv-app/local/ebt-data/translation/en/sujato/sutta/an/an1/an1.1-10_translation-en-sujato.json"
    guard let sourceJson = try? String(
      contentsOfFile: sourceFile,
      encoding: .utf8,
    ) else {
      print("ERROR: Cannot read source file")
      return
    }

    // Get generated JSON
    guard let generatedJson = mlDoc.asSuttaCentralJson() else {
      print("ERROR: Failed to serialize to JSON")
      return
    }

    // Check formatting: source uses "key": value, generated uses "key" : value
    let sourceHasNoSpaceAroundColon = sourceJson.contains("\":") && !sourceJson
      .contains("\" :")
    let generatedHasSpaceAroundColon = generatedJson.contains("\" :")

    print(
      "\nSource formatting: \(sourceHasNoSpaceAroundColon ? "\"key\":value" : "\"key\" : value")",
    )
    print(
      "Generated formatting: \(generatedHasSpaceAroundColon ? "\"key\" : value" : "\"key\":value")",
    )

    // This test detects the mismatch
    #expect(
      sourceHasNoSpaceAroundColon == !generatedHasSpaceAroundColon,
      "JSON formatting mismatch: source uses compact format, generated uses spaced format",
    )
  }

  @Test("getMLDocument(suttaRef:) returns MLDocument with matching fields")
  func getMLDocumentFromSuttaRefMatchesFields() async {
    guard let suttaRef = SuttaRef.create("an1.1-10/en/sujato") else {
      Issue.record("Failed to create SuttaRef")
      return
    }
    let mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)

    #expect(mlDoc != nil)
    guard let mlDoc else { return }

    // Verify MLDocument fields match SuttaRef properties
    #expect(mlDoc.sutta_uid == suttaRef.suttaUid)
    #expect(mlDoc.docLang == suttaRef.lang)
    #expect(mlDoc.docAuthor == suttaRef.author)
    #expect(mlDoc.author == suttaRef.author)
    #expect(!mlDoc.segMap.isEmpty)

    // Verify segment data matches known content from source JSON
    let testSegmentId = "an1.1:2.2"
    let expectedTextFragment = "sight of a woman occupies"

    guard let segment = mlDoc.segMap[testSegmentId] else {
      Issue.record("Segment not found")
      return
    }
    #expect(segment.doc != nil)
    #expect(segment.doc!.contains(expectedTextFragment))
  }

  @Test("Database schema_version matches EbtData.schemaVersion")
  func databaseSchemaVersionMatch() async throws {
    let expectedVersion = String(EbtData.schemaVersion)

    // Query database for actual schema_version
    let dbVersion = try await EbtData.shared.getDatabaseSchemaVersion(
      lang: "en",
      author: "soma",
    )

    #expect(
      dbVersion == expectedVersion,
      "Database schema_version '\(dbVersion)' does not match EbtData.schemaVersion '\(expectedVersion)'",
    )
  }

  @Test("Files breakdown: sujato has at least 4167 sutta files")
  func filesBreakdownSujato() throws {
    let manifest = DatabaseManifest.shared
    guard let sujato = manifest.info(language: "en", author: "sujato") else {
      #expect(Bool(false), "Could not load sujato from manifest")
      return
    }

    #expect(
      sujato.files.total >= 4167,
      "en/sujato should have at least 4167 files, got \(sujato.files.total)",
    )
  }

  @Test("Files breakdown: sabbamitta has at least 4055 sutta files")
  func filesBreakdownSabbamitta() throws {
    let manifest = DatabaseManifest.shared
    guard let sabbamitta = manifest.info(language: "de", author: "sabbamitta")
    else {
      #expect(Bool(false), "Could not load sabbamitta from manifest")
      return
    }

    #expect(
      sabbamitta.files.total >= 4055,
      "de/sabbamitta should have at least 4055 files, got \(sabbamitta.files.total)",
    )
  }

  @Test("Files breakdown: brahmali has at least 427 vinaya files")
  func filesBreakdownBrahmali() throws {
    let manifest = DatabaseManifest.shared
    guard let brahmali = manifest.info(language: "en", author: "brahmali")
    else {
      #expect(Bool(false), "Could not load brahmali from manifest")
      return
    }

    #expect(
      brahmali.files.vinaya >= 427,
      "en/brahmali should have at least 427 vinaya files, got \(brahmali.files.vinaya)",
    )
  }

  @Test("getMLDocument(dn16) => bilingual MLDocument doc:english/pli")
  func getMLDocumentdn16() async {
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()
    guard let suttaRef = SuttaRef.create("dn16/en/sujato") else {
      Issue.record("Failed to create SuttaRef for dn16")
      return
    }

    let mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)

    #expect(mlDoc != nil)
    guard let mlDoc else { return }

    // Verify MLDocument fields match SuttaRef properties
    #expect(mlDoc.sutta_uid == "dn16")
    #expect(mlDoc.docLang == "en")
    #expect(mlDoc.docAuthor == "sujato")
    #expect(mlDoc.author == "sujato")
    #expect(!mlDoc.segMap.isEmpty)

    // Verify segment count (dn16 should have 1664 segments)
    let segmentCount = mlDoc.segMap.count
    #expect(segmentCount == 1664)

    // Verify known segment exists (first true segment after header)
    guard let firstSegment = mlDoc.segMap["dn16:1.1.1"] else {
      Issue.record("First segment (dn16:1.1.1) not found")
      return
    }
    #expect(firstSegment.pli == "Evaṁ me sutaṁ—")
    #expect(firstSegment.doc == "So I have heard. ")
    let msElapsed = Int((CFAbsoluteTimeGetCurrent() - elapsedAtStart) * 1000)
    #expect(msElapsed < 100)
  }

  @Test("EN lemma search: root of suffering performance")
  func enLemmaSearchPerformance() async throws {
    // Get seeker to access lemmatization
    let seeker = try await EbtData.shared.getSeeker(
      lang: "en",
      author: "sujato",
    )

    // Lemmatize the query
    let lemmaWords = await seeker.lemmatize("root of suffering")

    // Time the EbtData search directly
    let elapsedAtStart = CFAbsoluteTimeGetCurrent()
    let result = await EbtData.shared.searchLemma(
      lang: "en",
      author: "sujato",
      lemmaWords: lemmaWords,
      query: "root of suffering",
    )
    let msElapsed = (CFAbsoluteTimeGetCurrent() - elapsedAtStart) * 1000

    #expect(result.error == nil)
    #expect(result.items.count > 0)
    cc.ok1(#line, #function, "msElapsed:", msElapsed)
  }

  @Test("verifyDatabaseInfo detects matching gitHash")
  func verifyDatabaseInfoMatching() async {
    // Get manifest info for en/sujato
    guard let dbInfo = DatabaseManifest.shared.info(
      language: "en",
      author: "sujato",
    ) else {
      Issue.record("en/sujato not found in manifest")
      return
    }

    // Ensure database is loaded into cache
    _ = try? await EbtData.shared.getSeeker(lang: "en", author: "sujato")

    // Verify with correct gitHash should succeed
    let matches = await EbtData.shared.verifyDatabaseInfo(dbInfo)
    #expect(matches)
  }

  @Test("verifyDatabaseInfo detects mismatched gitHash")
  func verifyDatabaseInfoMismatch() async {
    // Get manifest info for en/sujato
    guard let dbInfo = DatabaseManifest.shared.info(
      language: "en",
      author: "sujato",
    ) else {
      Issue.record("en/sujato not found in manifest")
      return
    }

    // Ensure database is loaded into cache
    _ = try? await EbtData.shared.getSeeker(lang: "en", author: "sujato")

    // Create a modified DatabaseInfo with different gitHash
    let modifiedInfo = DatabaseInfo(
      language: dbInfo.language,
      author: dbInfo.author,
      authorName: dbInfo.authorName,
      buildTimestamp: dbInfo.buildTimestamp,
      files: dbInfo.files,
      gitHash: "00000000000000000000000000000000", // Changed hash
      json: dbInfo.json,
    )

    // Verify with mismatched gitHash should fail
    let matches = await EbtData.shared.verifyDatabaseInfo(modifiedInfo)
    #expect(!matches)
  }

  @Test("verifyCachedDBs detects mismatches and repairs cache")
  func verifyCachedDBsDetectsMismatches() async {
    // Ensure key databases are loaded into cache
    _ = try? await EbtData.shared.getSeeker(lang: "en", author: "sujato")
    _ = try? await EbtData.shared.getSeeker(lang: "pli", author: "ms")

    // Verify all cached databases match manifest
    // repair=true (default) will clear any mismatched databases from cache
    let mismatched = await EbtData.shared.verifyCachedDBs()

    // With correct semantics:
    // - Cached databases with matching git_hash: verified (not in mismatched
    // list)
    // - Uncached databases (never decompressed): verified (not mismatched -
    // will be fresh from bundle)
    // Only cached databases with stale git_hash are mismatched
    // In this test, loaded databases match, so mismatched list should be empty
    #expect(mismatched.isEmpty)
  }
}
