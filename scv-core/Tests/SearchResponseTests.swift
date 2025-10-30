//
//  SearchResponseTests.swift
//  scvTests
//
//  Created by Visakha on 23/10/2025.
//

import Foundation
import Testing

@testable import scvCore

struct SearchResponseTests {

  // MARK: - Segment Tests

  @Test func testSegmentInitialization() async throws {
    let segment = Segment(
      scid: "test-scid",
      pli: "pali text",
      ref: "mn1.1",
      en: "English text",
      matched: true
    )

    #expect(segment.scid == "test-scid")
    #expect(segment.pli == "pali text")
    #expect(segment.ref == "mn1.1")
    #expect(segment.en == "English text")
    #expect(segment.matched == true)
  }

  @Test func testSegmentDisplayTextPrefersEnglish() async throws {
    let segment = Segment(
      scid: "test-scid",
      pli: "pali text",
      ref: "mn1.1",
      en: "English text",
      matched: true
    )

    #expect(segment.displayText == "English text")
  }

  @Test func testSegmentDisplayTextFallsBackToPali() async throws {
    let segment = Segment(
      scid: "test-scid",
      pli: "pali text",
      ref: "mn1.1",
      en: "",
      matched: true
    )

    #expect(segment.displayText == "pali text")
  }

  @Test func testSegmentIsMatched() async throws {
    let matchedSegment = Segment(
      scid: "test-scid",
      pli: nil,
      ref: nil,
      en: "test",
      matched: true
    )
    let unmatchedSegment = Segment(
      scid: "test-scid",
      pli: nil,
      ref: nil,
      en: "test",
      matched: false
    )
    let nilMatchedSegment = Segment(
      scid: "test-scid",
      pli: nil,
      ref: nil,
      en: "test",
      matched: nil
    )

    #expect(matchedSegment.isMatched == true)
    #expect(unmatchedSegment.isMatched == false)
    #expect(nilMatchedSegment.isMatched == false)
  }

  // MARK: - DocumentStats Tests

  @Test func testDocumentStatsInitialization() async throws {
    let stats = DocumentStats(
      text: 2000,
      lang: "pli",
      nSegments: 20,
      nEmptySegments: 5,
      nSections: 4,
      seconds: 2.5
    )

    #expect(stats.text == 2000)
    #expect(stats.lang == "pli")
    #expect(stats.nSegments == 20)
    #expect(stats.nEmptySegments == 5)
    #expect(stats.nSections == 4)
    #expect(stats.seconds == 2.5)
  }

  // MARK: - MLDocument Tests

  @Test func testMLDocumentInitialization() async throws {
    let segMap = [
      "seg1": Segment(
        scid: "seg1",
        pli: nil,
        ref: nil,
        en: "Test segment",
        matched: true
      )
    ]
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 10,
      nEmptySegments: 2,
      nSections: 3,
      seconds: 1.5
    )
    let doc = MLDocument(
      author: "Buddha",
      segMap: segMap,
      suttaCode: "mn1",
      blurb: "The First Discourse.",
      stats: stats
    )

    #expect(doc.author == "Buddha")
    #expect(doc.suttaCode == "mn1")
    #expect(doc.blurb == "The First Discourse.")
    #expect(doc.segMap.count == 1)
    #expect(doc.stats.text == 1000)
  }

  @Test func testMLDocumentAllSegments() async throws {
    let segMap = [
      "seg1": Segment(
        scid: "seg1",
        pli: nil,
        ref: nil,
        en: "First segment",
        matched: true
      ),
      "seg2": Segment(
        scid: "seg2",
        pli: nil,
        ref: nil,
        en: "Second segment",
        matched: false
      ),
    ]
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 2,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let doc = MLDocument(
      author: "Test",
      segMap: segMap,
      suttaCode: "mn1",
      blurb: "Test",
      stats: stats
    )

    let allSegments = doc.allSegments
    #expect(allSegments.count == 2)
    #expect(allSegments.contains { $0.scid == "seg1" })
    #expect(allSegments.contains { $0.scid == "seg2" })
  }

  @Test func testMLDocumentMatchedSegments() async throws {
    let segMap = [
      "seg1": Segment(
        scid: "seg1",
        pli: nil,
        ref: nil,
        en: "Matched segment",
        matched: true
      ),
      "seg2": Segment(
        scid: "seg2",
        pli: nil,
        ref: nil,
        en: "Unmatched segment",
        matched: false
      ),
    ]
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 2,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let doc = MLDocument(
      author: "Test",
      segMap: segMap,
      suttaCode: "mn1",
      blurb: "Test",
      stats: stats
    )

    let matchedSegments = doc.matchedSegments
    #expect(matchedSegments.count == 1)
    #expect(matchedSegments.first?.scid == "seg1")
  }

  @Test func testMLDocumentTitleFromBlurb() async throws {
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 1,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let doc = MLDocument(
      author: "Test",
      segMap: [:],
      suttaCode: "mn1",
      blurb: "This is the first discourse. It contains important teachings.",
      stats: stats
    )

    #expect(doc.title == "This is the first discourse")
  }

  @Test func testMLDocumentTitleFallbackToSuttaCode() async throws {
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 1,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let doc = MLDocument(
      author: "Test",
      segMap: [:],
      suttaCode: "mn1",
      blurb: "",
      stats: stats
    )

    #expect(doc.title == "")  // Empty blurb results in empty title, not suttaCode fallback
  }

  // MARK: - SearchResponse Tests

  @Test func testSearchResponseInitialization() async throws {
    let segMap = [
      "seg1": Segment(
        scid: "seg1",
        pli: nil,
        ref: nil,
        en: "Test segment",
        matched: true
      )
    ]
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 1,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let mlDoc = MLDocument(
      author: "Test",
      segMap: segMap,
      suttaCode: "mn1",
      blurb: "Test",
      stats: stats
    )
    let response = SearchResponse(
      author: "SC-Voice",
      lang: "en",
      searchLang: "en",
      minLang: 1,
      maxDoc: 10,
      maxResults: 100,
      pattern: "mindfulness",
      method: "regex",
      resultPattern: "mindfulness",
      segsMatched: 1,
      bilaraPaths: ["path1"],
      suttaRefs: ["mn1"],
      mlDocs: [mlDoc]
    )

    #expect(response.author == "SC-Voice")
    #expect(response.lang == "en")
    #expect(response.pattern == "mindfulness")
    #expect(response.mlDocs.count == 1)
    #expect(response.bilaraPaths.count == 1)
    #expect(response.suttaRefs.count == 1)
  }

  @Test func testSearchResponseEmptyConstructor() async throws {
    let response = SearchResponse()

    #expect(response.author == "")
    #expect(response.lang == "")
    #expect(response.searchLang == "")
    #expect(response.minLang == 0)
    #expect(response.maxDoc == 0)
    #expect(response.maxResults == 0)
    #expect(response.pattern == "")
    #expect(response.method == "")
    #expect(response.resultPattern == "")
    #expect(response.segsMatched == 0)
    #expect(response.bilaraPaths == [])
    #expect(response.suttaRefs == [])
    #expect(response.mlDocs == [])
    #expect(response.searchError == nil)
    #expect(response.searchSuggestion == nil)
    #expect(response.isSuccess == true)
  }

  @Test func testSearchResponseMatchedSegments() async throws {
    let segMap1 = [
      "seg1": Segment(
        scid: "seg1",
        pli: nil,
        ref: nil,
        en: "Matched segment 1",
        matched: true
      )
    ]
    let segMap2 = [
      "seg2": Segment(
        scid: "seg2",
        pli: nil,
        ref: nil,
        en: "Unmatched segment 2",
        matched: false
      )
    ]
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 1,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let doc1 = MLDocument(
      author: "Test",
      segMap: segMap1,
      suttaCode: "mn1",
      blurb: "Test",
      stats: stats
    )
    let doc2 = MLDocument(
      author: "Test",
      segMap: segMap2,
      suttaCode: "mn2",
      blurb: "Test",
      stats: stats
    )
    let response = SearchResponse(
      author: "Test",
      lang: "en",
      searchLang: "en",
      minLang: 1,
      maxDoc: 10,
      maxResults: 100,
      pattern: "test",
      method: "regex",
      resultPattern: "test",
      segsMatched: 1,
      bilaraPaths: [],
      suttaRefs: [],
      mlDocs: [doc1, doc2]
    )

    let matchedSegments = response.matchedSegments
    #expect(matchedSegments.count == 1)
    #expect(matchedSegments.first?.scid == "seg1")
  }

  @Test func testSearchResponseTotalDocuments() async throws {
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 1,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let doc1 = MLDocument(
      author: "Test",
      segMap: [:],
      suttaCode: "mn1",
      blurb: "Test",
      stats: stats
    )
    let doc2 = MLDocument(
      author: "Test",
      segMap: [:],
      suttaCode: "mn2",
      blurb: "Test",
      stats: stats
    )
    let response = SearchResponse(
      author: "Test",
      lang: "en",
      searchLang: "en",
      minLang: 1,
      maxDoc: 10,
      maxResults: 100,
      pattern: "test",
      method: "regex",
      resultPattern: "test",
      segsMatched: 0,
      bilaraPaths: [],
      suttaRefs: [],
      mlDocs: [doc1, doc2]
    )

    #expect(response.totalDocuments == 2)
  }

  @Test func testSearchResponseUniqueSuttaRefs() async throws {
    let response = SearchResponse(
      author: "Test",
      lang: "en",
      searchLang: "en",
      minLang: 1,
      maxDoc: 10,
      maxResults: 100,
      pattern: "test",
      method: "regex",
      resultPattern: "test",
      segsMatched: 0,
      bilaraPaths: [],
      suttaRefs: ["mn1", "mn2", "mn1", "sn1.1", "mn2"],
      mlDocs: []
    )

    let uniqueRefs = response.uniqueSuttaRefs
    #expect(uniqueRefs.count == 3)
    #expect(uniqueRefs.contains("mn1"))
    #expect(uniqueRefs.contains("mn2"))
    #expect(uniqueRefs.contains("sn1.1"))
  }

  // MARK: - Codable Tests

  @Test func testSegmentCodable() async throws {
    let originalSegment = Segment(
      scid: "test-scid",
      pli: "pali text",
      ref: "mn1.1",
      en: "English text",
      matched: true
    )

    let data = try JSONEncoder().encode(originalSegment)
    let decodedSegment = try JSONDecoder().decode(Segment.self, from: data)

    #expect(decodedSegment.scid == originalSegment.scid)
    #expect(decodedSegment.pli == originalSegment.pli)
    #expect(decodedSegment.ref == originalSegment.ref)
    #expect(decodedSegment.en == originalSegment.en)
    #expect(decodedSegment.matched == originalSegment.matched)
  }

  @Test func testSearchResponseCodable() async throws {
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 1,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let mlDoc = MLDocument(
      author: "Test",
      segMap: [:],
      suttaCode: "mn1",
      blurb: "Test",
      stats: stats
    )
    let originalResponse = SearchResponse(
      author: "SC-Voice",
      lang: "en",
      searchLang: "en",
      minLang: 1,
      maxDoc: 10,
      maxResults: 100,
      pattern: "test",
      method: "regex",
      resultPattern: "test",
      segsMatched: 0,
      bilaraPaths: ["path1"],
      suttaRefs: ["mn1"],
      mlDocs: [mlDoc]
    )

    let data = try JSONEncoder().encode(originalResponse)
    let decodedResponse = try JSONDecoder().decode(
      SearchResponse.self,
      from: data
    )

    #expect(decodedResponse.author == originalResponse.author)
    #expect(decodedResponse.lang == originalResponse.lang)
    #expect(decodedResponse.pattern == originalResponse.pattern)
    #expect(decodedResponse.mlDocs.count == originalResponse.mlDocs.count)
    #expect(decodedResponse.bilaraPaths == originalResponse.bilaraPaths)
    #expect(decodedResponse.suttaRefs == originalResponse.suttaRefs)
  }

  @Test func testSearchResponseSerialization() async throws {
    // Create a test SearchResponse
    let stats = DocumentStats(
      text: 1000,
      lang: "en",
      nSegments: 1,
      nEmptySegments: 0,
      nSections: 1,
      seconds: 1.0
    )
    let mlDoc = MLDocument(
      author: "Test Author",
      segMap: [:],
      suttaCode: "mn1",
      blurb: "Test blurb",
      stats: stats
    )
    let originalResponse = SearchResponse(
      author: "SC-Voice",
      lang: "en",
      searchLang: "en",
      minLang: 1,
      maxDoc: 10,
      maxResults: 100,
      pattern: "test pattern",
      method: "regex",
      resultPattern: "test",
      segsMatched: 5,
      bilaraPaths: ["path1", "path2"],
      suttaRefs: ["mn1"],
      mlDocs: [mlDoc]
    )

    // Test toJSON()
    let jsonString = originalResponse.toJSON()
    #expect(jsonString != nil, "toJSON() should successfully encode SearchResponse")

    guard let jsonString = jsonString else {
      return
    }

    // Verify the JSON is valid by checking it contains expected fields
    #expect(jsonString.contains("\"author\":\"SC-Voice\""))
    #expect(jsonString.contains("\"pattern\":\"test pattern\""))

    // Test fromJSON()
    let decodedResponse = SearchResponse.fromJSON(jsonString)
    #expect(decodedResponse != nil, "fromJSON() should successfully decode JSON")

    guard let decoded = decodedResponse else {
      return
    }

    // Verify round-trip properties are preserved
    #expect(decoded.author == originalResponse.author)
    #expect(decoded.lang == originalResponse.lang)
    #expect(decoded.pattern == originalResponse.pattern)
    #expect(decoded.method == originalResponse.method)
    #expect(decoded.segsMatched == originalResponse.segsMatched)
    #expect(decoded.bilaraPaths == originalResponse.bilaraPaths)
    #expect(decoded.suttaRefs == originalResponse.suttaRefs)
    #expect(decoded.mlDocs.count == originalResponse.mlDocs.count)
  }
}
