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
      doc: "English text",
      ref: "mn1.1",
      pli: "pali text",
      matched: true
    )

    #expect(segment.scid == "test-scid")
    #expect(segment.doc == "English text")
    #expect(segment.ref == "mn1.1")
    #expect(segment.pli == "pali text")
    #expect(segment.matched == true)
  }

  @Test func testSegmentDisplayTextPrefersEnglish() async throws {
    let segment = Segment(
      scid: "test-scid",
      doc: "English text",
      ref: "mn1.1",
      pli: "pali text",
      matched: true
    )

    #expect(segment.displayText == "English text")
  }

  @Test func testSegmentDisplayTextFallsBackToPali() async throws {
    let segment = Segment(
      scid: "test-scid",
      doc: "",
      ref: "mn1.1",
      pli: "pali text",
      matched: true
    )

    #expect(segment.displayText == "pali text")
  }

  @Test func testSegmentIsMatched() async throws {
    let matchedSegment = Segment(
      scid: "test-scid",
      doc: "test",
      matched: true
    )
    let unmatchedSegment = Segment(
      scid: "test-scid",
      doc: "test",
      matched: false
    )
    let nilMatchedSegment = Segment(
      scid: "test-scid",
      doc: "test"
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
        doc: "Test segment",
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
      blurb: "The First Discourse.",
      stats: stats,
      sutta_uid: "mn1"
    )

    #expect(doc.author == "Buddha")
    #expect(doc.sutta_uid == "mn1")
    #expect(doc.blurb == "The First Discourse.")
    #expect(doc.segMap.count == 1)
    #expect(doc.stats?.text == 1000)
  }

  @Test func testMLDocumentAllSegments() async throws {
    let segMap = [
      "seg1": Segment(
        scid: "seg1",
        doc: "First segment",
        matched: true
      ),
      "seg2": Segment(
        scid: "seg2",
        doc: "Second segment",
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
      blurb: "Test",
      stats: stats,
      sutta_uid: "mn1"
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
        doc: "Matched segment",
        matched: true
      ),
      "seg2": Segment(
        scid: "seg2",
        doc: "Unmatched segment",
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
      blurb: "Test",
      stats: stats,
      sutta_uid: "mn1"
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
      blurb: "This is the first discourse. It contains important teachings.",
      stats: stats,
      sutta_uid: "mn1"
    )

    #expect(doc.computedTitle == "This is the first discourse")
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
      blurb: "",
      stats: stats,
      sutta_uid: "mn1"
    )

    #expect(doc.computedTitle == "mn1")  // Empty blurb falls back to sutta_uid
  }

  // MARK: - SearchResponse Tests

  @Test func testSearchResponseInitialization() async throws {
    let segMap = [
      "seg1": Segment(
        scid: "seg1",
        doc: "Test segment",
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
    #expect(response.mlDocs.isEmpty)
    #expect(response.searchError == nil)
    #expect(response.searchSuggestion == "")
    #expect(response.isSuccess == true)
  }

  @Test func testSearchResponseMatchedSegments() async throws {
    let segMap1 = [
      "seg1": Segment(
        scid: "seg1",
        doc: "Matched segment 1",
        matched: true
      )
    ]
    let segMap2 = [
      "seg2": Segment(
        scid: "seg2",
        doc: "Unmatched segment 2",
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
      blurb: "Test",
      stats: stats,
      sutta_uid: "mn1"
    )
    let doc2 = MLDocument(
      author: "Test",
      segMap: segMap2,
      blurb: "Test",
      stats: stats,
      sutta_uid: "mn2"
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
      blurb: "Test",
      stats: stats,
      sutta_uid: "mn1"
    )
    let doc2 = MLDocument(
      author: "Test",
      segMap: [:],
      blurb: "Test",
      stats: stats,
      sutta_uid: "mn2"
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
      doc: "English text",
      ref: "mn1.1",
      pli: "pali text",
      matched: true
    )

    let data = try JSONEncoder().encode(originalSegment)
    let decodedSegment = try JSONDecoder().decode(Segment.self, from: data)

    #expect(decodedSegment.scid == originalSegment.scid)
    #expect(decodedSegment.doc == originalSegment.doc)
    #expect(decodedSegment.ref == originalSegment.ref)
    #expect(decodedSegment.pli == originalSegment.pli)
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

  // MARK: - Factory Method Tests

  @Test func testCreateMockResponse() async throws {
    // Load mock response from bundle resource (default English)
    let mockResponse = SearchResponse.createMockResponse()

    // Verify it loaded successfully
    #expect(mockResponse != nil, "createMockResponse() should load mock-response-en.json")

    guard let response = mockResponse else {
      return
    }

    // Verify core properties from mock-response-en.json
    #expect(response.pattern == "root of suffering")
    #expect(response.segsMatched == 14)
    #expect(response.mlDocs.count == 1)
    #expect(response.author == "sujato")
    #expect(response.lang == "en")
    #expect(response.searchLang == "en")
    #expect(response.method == "phrase")
  }

  @Test func testCreateMockResponseIdempotency() async throws {
    // Call factory method multiple times
    let mockResponse1 = SearchResponse.createMockResponse()
    let mockResponse2 = SearchResponse.createMockResponse()

    // Both should load successfully
    #expect(mockResponse1 != nil)
    #expect(mockResponse2 != nil)

    // Results should be equal (idempotent)
    #expect(mockResponse1 == mockResponse2)
  }

  @Test func testCreateMockResponseGerman() async throws {
    // Load German mock response
    let mockResponse = SearchResponse.createMockResponse(language: "de")

    // Verify it loaded successfully
    #expect(mockResponse != nil, "createMockResponse(language: \"de\") should load mock-response-de.json")

    guard let response = mockResponse else {
      return
    }

    // Verify it's a valid SearchResponse with German content
    #expect(response.mlDocs.count > 0, "German mock response should have documents")
    #expect(response.segsMatched > 0, "German mock response should have matched segments")
  }

  @Test func testCreateMockResponseLanguageFallback() async throws {
    // Request non-existent language should fall back to English
    let mockResponse = SearchResponse.createMockResponse(language: "fr")

    // Should fall back to English
    #expect(mockResponse != nil, "createMockResponse() should fall back to English for unsupported language")

    guard let response = mockResponse else {
      return
    }

    // Should have English properties
    #expect(response.lang == "en", "Fallback response should be English")
    #expect(response.author == "sujato", "Fallback response should be from mock-response-en.json")
  }

  @Test func testCreateMockResponseDocuments() async throws {
    let mockResponse = SearchResponse.createMockResponse()

    guard let response = mockResponse else {
      #expect(Bool(false), "createMockResponse() should load successfully")
      return
    }

    // Verify mlDocs structure is properly decoded
    let firstDoc = response.mlDocs.first
    #expect(firstDoc != nil)

    guard let doc = firstDoc else {
      return
    }

    // Verify document contains segments
    #expect(doc.segMap.count > 0, "Document should have segments from MockResponse.json")

    // Verify matched segments exist
    let matchedSegments = doc.matchedSegments
    #expect(matchedSegments.count > 0, "Document should have matched segments")
  }

  // MARK: - Segments Method Tests

  @Test func testMLDocumentSegmentsSorting() async throws {
    let mockResponse = SearchResponse.createMockResponse()

    guard let response = mockResponse, let doc = response.mlDocs.first else {
      #expect(Bool(false), "createMockResponse() should load successfully")
      return
    }

    let sortedSegments = doc.segments()

    // Verify segments are returned
    #expect(sortedSegments.count > 0, "Document should have segments")

    // Verify they're sorted in SuttaCentralId order
    for i in 0..<(sortedSegments.count - 1) {
      let current = sortedSegments[i].key
      let next = sortedSegments[i + 1].key

      let cmp = SuttaCentralId.compareLow(current, next)
      #expect(
        cmp < 0,
        "Segments should be sorted in order: \(current) should come before \(next)"
      )
    }
  }

  @Test func testMLDocumentSegmentsOrderForSn4211() async throws {
    let mockResponse = SearchResponse.createMockResponse()

    guard let response = mockResponse, let doc = response.mlDocs.first else {
      #expect(Bool(false), "createMockResponse() should load successfully")
      return
    }

    let sortedSegments = doc.segments()

    // Verify first three segments are in correct order for sn42.11
    #expect(sortedSegments.count >= 3)
    #expect(sortedSegments[0].key == "sn42.11:0.1")
    #expect(sortedSegments[1].key == "sn42.11:0.2")
    #expect(sortedSegments[2].key == "sn42.11:0.3")
  }

  @Test func testMLDocumentSegmentsPreservesContent() async throws {
    let mockResponse = SearchResponse.createMockResponse()

    guard let response = mockResponse, let doc = response.mlDocs.first else {
      #expect(Bool(false), "createMockResponse() should load successfully")
      return
    }

    let sortedSegments = doc.segments()
    let firstSeg = sortedSegments.first

    // Verify segment content is preserved
    #expect(firstSeg?.value.scid == "sn42.11:0.1")
    #expect(
      firstSeg?.value.displayText.contains("Linked Discourses") ?? false,
      "Segment content should be preserved"
    )
  }

  // MARK: - MLDocument Segment Selection Tests (Objective 03)

  @Test func testMLDocumentDefaultCurrentScidIsNil() async throws {
    let doc = MLDocument()
    #expect(doc.currentScid == nil)
  }

  @Test func testMLDocumentCanSetCurrentScid() async throws {
    var doc = MLDocument()
    doc.currentScid = "sn42.11:2.11"
    #expect(doc.currentScid == "sn42.11:2.11")
  }

  @Test func testMLDocumentCurrentScidCanBeCleared() async throws {
    var doc = MLDocument(currentScid: "sn42.11:2.11")
    #expect(doc.currentScid == "sn42.11:2.11")
    doc.currentScid = nil
    #expect(doc.currentScid == nil)
  }

  @Test func testMLDocumentCurrentScidInitializer() async throws {
    let doc = MLDocument(
      sutta_uid: "sn42.11",
      currentScid: "sn42.11:2.11"
    )
    #expect(doc.currentScid == "sn42.11:2.11")
  }

  @Test func testMLDocumentCurrentScidEncodingAndDecoding() async throws {
    let originalDoc = MLDocument(
      sutta_uid: "sn42.11",
      title: "Test Sutta",
      currentScid: "sn42.11:2.11"
    )

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(originalDoc)

    let decoder = JSONDecoder()
    let decodedDoc = try decoder.decode(MLDocument.self, from: jsonData)

    #expect(decodedDoc.currentScid == "sn42.11:2.11")
    #expect(decodedDoc.sutta_uid == "sn42.11")
  }

  @Test func testMLDocumentCurrentScidNotInEncodedJSON() async throws {
    let doc = MLDocument(
      sutta_uid: "sn42.11",
      currentScid: nil
    )

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(doc)

    let decodedDoc = try JSONDecoder().decode(MLDocument.self, from: jsonData)
    #expect(decodedDoc.currentScid == nil)
  }

  @Test func testMLDocumentMultipleSelectionsIndependent() async throws {
    var doc1 = MLDocument(sutta_uid: "sn42.11")
    var doc2 = MLDocument(sutta_uid: "mn10")

    doc1.currentScid = "sn42.11:2.11"
    doc2.currentScid = "mn10:1.1"

    #expect(doc1.currentScid == "sn42.11:2.11")
    #expect(doc2.currentScid == "mn10:1.1")

    // Change doc1 selection
    doc1.currentScid = "sn42.11:3.5"
    #expect(doc1.currentScid == "sn42.11:3.5")
    #expect(doc2.currentScid == "mn10:1.1")
  }

  @Test func testMLDocumentWithMockResponseCurrentScid() async throws {
    guard let mockResponse = SearchResponse.createMockResponse() else {
      #expect(Bool(false), "Failed to load mock response")
      return
    }

    // Create document with currentScid from mock response data
    var doc = mockResponse.mlDocs[0]
    doc.currentScid = "sn42.11:2.11"

    #expect(doc.currentScid == "sn42.11:2.11")
    #expect(doc.segMap["sn42.11:2.11"] != nil)
  }

  @Test func testMLDocumentCurrentScidRoundTripWithSearchResponse() async throws {
    let mockDoc = MLDocument(
      author: "Test Author",
      segMap: [:],
      sutta_uid: "sn42.11",
      title: "Test Sutta",
      currentScid: "sn42.11:2.11"
    )

    let response = SearchResponse(mlDocs: [mockDoc])

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(response)

    let decoder = JSONDecoder()
    let decodedResponse = try decoder.decode(SearchResponse.self, from: jsonData)

    #expect(decodedResponse.mlDocs.count == 1)
    #expect(decodedResponse.mlDocs[0].currentScid == "sn42.11:2.11")
  }
}
