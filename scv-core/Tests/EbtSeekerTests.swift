//
//  EbtSeekerTests.swift
//  scv-core
//
//  Created by Claude on 2025-12-03.
//

@testable import scvCore
import Testing

@Suite("EbtSeeker Tests")
struct EbtSeekerTests {
  @Test("addSuttaInfo populates segment data for thig1.1")
  func addSuttaInfoThig11() async {
    // Search for thig1.1/en/soma using suttaref method
    var result = await EbtData.shared.search(
      query: "thig1.1/en/soma",
      docLang: "en",
      docAuthor: "soma",
    )

    // Verify search returned the expected result
    #expect(result.results.count == 1, "Expected 1 result for thig1.1/en/soma")
    #expect(result.results[0].suttaRef.suttaUid == "thig1.1")
    #expect(result.results[0].suttaRef.lang == "en")
    #expect(result.results[0].suttaRef.author == "soma")

    // Initially segmentCount and headerSegments should be empty/nil
    #expect(
      result.results[0].segmentCount == nil,
      "segmentCount should be nil before addSuttaInfo",
    )
    #expect(
      result.results[0].headerSegments.isEmpty,
      "headerSegments should be empty before addSuttaInfo",
    )

    // Call addSuttaInfo to populate segment data
    let success = await result.addSuttaInfo()
    #expect(success, "addSuttaInfo should succeed")

    // Verify segmentCount was populated
    #expect(
      result.results[0].segmentCount != nil,
      "segmentCount should be populated after addSuttaInfo",
    )
    #expect(
      result.results[0].segmentCount == 9,
      "thig1.1/en/soma should have 9 segments, got \(result.results[0].segmentCount ?? -1)",
    )

    // Verify headerSegments was populated with header segments (segments with
    // :0 in segment_id)
    let headerSegments = result.results[0].headerSegments
    #expect(!headerSegments.isEmpty, "thig1.1 should have header segments")

    // Verify header segment ids contain ":0"
    for segment in headerSegments {
      #expect(
        segment.scid.contains(":0"),
        "Header segment should contain ':0': \(segment.scid)",
      )
    }

    // Verify first three header segments based on actual data
    #expect(
      headerSegments.count >= 2,
      "thig1.1 should have at least 2 header segments, got \(headerSegments.count)",
    )

    // Verify first header segment (thig1.1:0.1)
    #expect(
      headerSegments[0].scid == "thig1.1:0.1",
      "First header segment should be thig1.1:0.1",
    )
    #expect(
      headerSegments[0].doc == "Verses of the Elder Bhikkhunīs ",
      "First header segment text mismatch",
    )

    // Verify second header segment (thig1.1:0.2)
    #expect(
      headerSegments[1].scid == "thig1.1:0.2",
      "Second header segment should be thig1.1:0.2",
    )
    #expect(
      headerSegments[1].doc == "Chapter of the Ones ",
      "Second header segment text mismatch",
    )
  }

  @Test("EbtSeeker.search() returns result for thig1.1")
  func seekerSearchThig11() async throws {
    // Get seeker for en/soma
    let seeker = try await EbtData.shared.getSeeker(lang: "en", author: "soma")

    // Call search on seeker with suttaref query
    let result = await seeker.search(query: "thig1.1/en/soma")

    // Verify search returned the expected result
    #expect(result.results.count == 1, "Expected 1 result for thig1.1")
    #expect(result.results[0].suttaRef.suttaUid == "thig1.1")
    #expect(result.results[0].suttaRef.lang == "en")
    #expect(result.results[0].suttaRef.author == "soma")

    // Verify metadata
    #expect(result.metadata.docLang == "en", "docLang should be en")
    #expect(result.metadata.docAuthor == "soma", "docAuthor should be soma")
  }

  @Test("getSeeker with invalid author throws error")
  func getSeekerInvalidAuthor() async throws {
    do {
      _ = try await EbtData.shared.getSeeker(lang: "en", author: "nonexistent")
      #expect(Bool(false), "Should have thrown error for invalid author")
    } catch EbtDataError.databaseNotFound {
      // Expected error
    }
  }

  @Test("getSeeker with invalid lang throws error")
  func getSeekerInvalidLang() async throws {
    do {
      _ = try await EbtData.shared.getSeeker(lang: "xx", author: "sujato")
      #expect(Bool(false), "Should have thrown error for invalid lang")
    } catch EbtDataError.databaseNotFound {
      // Expected error
    }
  }

  @Test("getSeeker with defaults uses pli and default author")
  func getSeekerDefaults() async throws {
    let seeker = try await EbtData.shared.getSeeker()

    // Verify metadata shows pli and default author
    let result = await seeker.search(query: "mn1/pli/ms")
    #expect(result.metadata.docLang == "pli", "docLang should be pli")
    #expect(!result.metadata.docAuthor.isEmpty, "docAuthor should not be empty")
  }

  @Test("EbtSeeker.search() with wrong lang/author returns error")
  func seekerSearchWrongLangAuthor() async throws {
    // Create seeker for en/soma
    let seeker = try await EbtData.shared.getSeeker(lang: "en", author: "soma")

    // Try to search for a sutta with wrong lang/author combination
    let wrongLangResult = await seeker.search(query: "mn1/de/sabbamitta")
    #expect(
      wrongLangResult.error != nil,
      "Search with wrong lang should return error"
    )

    // Try to search for a sutta with valid author (kelly) but not in en/soma database
    let wrongAuthorResult = await seeker.search(query: "mn1/en/kelly")
    #expect(
      wrongAuthorResult.error != nil,
      "Search with valid author not in database should return error"
    )

    // Try to search for a sutta with wrong lang code
    let wrongLangCodeResult = await seeker.search(query: "mn1/xx/soma")
    #expect(
      wrongLangCodeResult.error != nil,
      "Search with invalid lang code should return or error"
    )
  }

  @Test("EbtSeeker.search() with correct lang/author returns results")
  func seekerSearchCorrectLangAuthor() async throws {
    // Create seeker for en/soma
    let seeker = try await EbtData.shared.getSeeker(lang: "en", author: "soma")

    // Search for mn1/en/soma which should match seeker's database
    let result = await seeker.search(query: "mn1/en/soma")
    #expect(!result.results.isEmpty, "Search for mn1/en/soma should find results")
    #expect(result.results[0].suttaRef.lang == "en", "Result should have lang en")
    #expect(result.results[0].suttaRef.author == "soma", "Result should have author soma")
  }
}
