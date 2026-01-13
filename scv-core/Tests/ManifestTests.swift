//
//  ManifestTests.swift
//  scv-coreTests
//
//  Created by Claude on 2025-01-09.
//

import Foundation

@testable import scvCore
import Testing

@Suite struct ManifestTests {
  @Test("DatabaseManifest.shared contains expected databases")
  func sharedManifestNotEmpty() {
    let manifest = DatabaseManifest.shared
    #expect(
      manifest.databases.count > 0,
      "Manifest should contain at least one database",
    )
  }

  @Test("availableLanguages() returns non-empty list")
  func availableLanguages() {
    let manifest = DatabaseManifest.shared
    let languages = manifest.availableLanguages()
    #expect(languages.count > 0, "Should have at least one language")
    #expect(languages.contains("en"), "Should contain English")
    #expect(languages.contains("pli"), "Should contain Pali")
  }

  @Test("info(language:author:) returns DatabaseInfo for en/sujato")
  func infoEnSujato() {
    let manifest = DatabaseManifest.shared
    let info = manifest.info(language: "en", author: "sujato")

    #expect(info != nil, "Should find en/sujato in manifest")
    if let info {
      #expect(info.language == "en", "Language should be en")
      #expect(info.author == "sujato", "Author should be sujato")
      #expect(!info.authorName.isEmpty, "Author name should not be empty")
      #expect(
        !info.buildTimestamp.isEmpty,
        "Build timestamp should not be empty",
      )
      #expect(info.id == "en/sujato", "ID should be en/sujato")
    }
  }

  @Test("info(language:author:) returns DatabaseInfo for fr/noeismet")
  func infoFrNoeismet() {
    let manifest = DatabaseManifest.shared
    let info = manifest.info(language: "fr", author: "noeismet")

    #expect(info != nil, "Should find fr/noeismet in manifest")
    if let info {
      #expect(info.language == "fr", "Language should be fr")
      #expect(info.author == "noeismet", "Author should be noeismet")
      #expect(!info.authorName.isEmpty, "Author name should not be empty")
      #expect(
        !info.buildTimestamp.isEmpty,
        "Build timestamp should not be empty",
      )
      #expect(info.id == "fr/noeismet", "ID should be fr/noeismet")
    }
  }

  @Test("info(language:author:) returns nil for non-existent database")
  func infoNonExistent() {
    let manifest = DatabaseManifest.shared
    let info = manifest.info(language: "xx", author: "nonexistent")

    #expect(info == nil, "Should return nil for non-existent database")
  }

  @Test("authorsForLanguage() returns all authors for English")
  func authorsForLanguageEn() {
    let manifest = DatabaseManifest.shared
    let authors = manifest.authorsForLanguage("en")

    #expect(authors.count > 0, "Should find at least one English author")
    #expect(
      authors.contains { $0.author == "sujato" },
      "Should contain sujato",
    )
    #expect(
      authors.allSatisfy { $0.language == "en" },
      "All entries should be English",
    )
  }

  @Test("authorsForLanguage() returns all authors for French")
  func authorsForLanguageFr() {
    let manifest = DatabaseManifest.shared
    let authors = manifest.authorsForLanguage("fr")

    #expect(authors.count > 0, "Should find at least one French author")
    #expect(
      authors.contains { $0.author == "noeismet" },
      "Should contain noeismet",
    )
    #expect(
      authors.allSatisfy { $0.language == "fr" },
      "All entries should be French",
    )
  }

  @Test("authorsForLanguage() returns empty for non-existent language")
  func authorsForLanguageNonExistent() {
    let manifest = DatabaseManifest.shared
    let authors = manifest.authorsForLanguage("xx")

    #expect(authors.isEmpty, "Should return empty for non-existent language")
  }

  @Test("authorsForLanguageSortedByFiles() returns sorted by file count")
  func authorsForLanguageSortedByFiles() {
    let manifest = DatabaseManifest.shared
    let authors = manifest.authorsForLanguageSortedByFiles("en")

    #expect(authors.count > 0, "Should find at least one English author")

    // Verify sorting order (descending by file count)
    for i in 0 ..< authors.count - 1 {
      #expect(
        authors[i].files.total >= authors[i + 1].files.total,
        "Authors should be sorted by file count descending",
      )
    }
  }

  @Test("defaultAuthorForLanguage() returns most comprehensive author")
  func defaultAuthorForLanguage() {
    let manifest = DatabaseManifest.shared

    let enDefault = manifest.defaultAuthorForLanguage("en")
    #expect(enDefault != nil, "Should find default author for English")
    if let en = enDefault {
      #expect(en.language == "en", "Default should be English")
      // Verify it's the first (most comprehensive) from sorted list
      let sorted = manifest.authorsForLanguageSortedByFiles("en")
      #expect(en == sorted.first, "Default should be first in sorted list")
    }

    let frDefault = manifest.defaultAuthorForLanguage("fr")
    #expect(frDefault != nil, "Should find default author for French")
    if let fr = frDefault {
      #expect(fr.language == "fr", "Default should be French")
      // Verify it's the first from sorted list
      let sorted = manifest.authorsForLanguageSortedByFiles("fr")
      #expect(fr == sorted.first, "Default should be first in sorted list")
    }
  }

  @Test("defaultAuthorForLanguage() returns nil for non-existent language")
  func defaultAuthorForLanguageNonExistent() {
    let manifest = DatabaseManifest.shared
    let author = manifest.defaultAuthorForLanguage("xx")

    #expect(author == nil, "Should return nil for non-existent language")
  }

  @Test("suttaRefExists() returns true for valid en/sujato")
  func suttaRefExistsEnSujato() throws {
    let manifest = DatabaseManifest.shared
    let suttaRef = try SuttaRef(suttaUid: "mn1", lang: "en", author: "sujato")

    let exists = manifest.suttaRefExists(suttaRef)
    #expect(exists, "Should return true for valid en/sujato reference")
  }

  @Test("suttaRefExists() returns true for valid fr/noeismet")
  func suttaRefExistsFrNoeismet() throws {
    let manifest = DatabaseManifest.shared
    let suttaRef = try SuttaRef(suttaUid: "mn1", lang: "fr", author: "noeismet")

    let exists = manifest.suttaRefExists(suttaRef)
    #expect(exists, "Should return true for valid fr/noeismet reference")
  }

  @Test("suttaRefExists() returns false for nil author")
  func suttaRefExistsNilAuthor() throws {
    let manifest = DatabaseManifest.shared
    let suttaRef = try SuttaRef(suttaUid: "mn1", lang: "en", author: nil)

    let exists = manifest.suttaRefExists(suttaRef)
    #expect(exists == false, "Should return false for nil author")
  }

  @Test("suttaRefExists() returns false for non-existent database")
  func suttaRefExistsNonExistent() throws {
    let manifest = DatabaseManifest.shared
    let suttaRef = try SuttaRef(
      suttaUid: "mn1",
      lang: "xx",
      author: "nonexistent",
    )

    let exists = manifest.suttaRefExists(suttaRef)
    #expect(exists == false, "Should return false for non-existent database")
  }

  @Test("DatabaseInfo.id is constructed correctly")
  func databaseInfoId() {
    let info = DatabaseInfo(
      language: "en",
      author: "sujato",
      authorName: "Bhikkhu Sujato",
      buildTimestamp: "2025-01-09T00:00:00Z",
      files: FilesBreakdown(
        sutta: 100,
        vinaya: 50,
        abhidhamma: 75,
        other: 10,
        total: 235,
      ),
    )

    #expect(info.id == "en/sujato", "ID should be language/author format")
  }

  @Test("FilesBreakdown properties are accessible")
  func filesBreakdownProperties() {
    let files = FilesBreakdown(
      sutta: 100,
      vinaya: 50,
      abhidhamma: 75,
      other: 10,
      total: 235,
    )

    #expect(files.sutta == 100, "Sutta count should be 100")
    #expect(files.vinaya == 50, "Vinaya count should be 50")
    #expect(files.abhidhamma == 75, "Abhidhamma count should be 75")
    #expect(files.other == 10, "Other count should be 10")
    #expect(files.total == 235, "Total count should be 235")
  }

  @Test("FilesBreakdown defaults to zero")
  func filesBreakdownDefaults() {
    let files = FilesBreakdown()

    #expect(files.sutta == 0, "Sutta should default to 0")
    #expect(files.vinaya == 0, "Vinaya should default to 0")
    #expect(files.abhidhamma == 0, "Abhidhamma should default to 0")
    #expect(files.other == 0, "Other should default to 0")
    #expect(files.total == 0, "Total should default to 0")
  }

  @Test("DatabaseInfo is Identifiable")
  func databaseInfoIdentifiable() {
    let info1 = DatabaseInfo(
      language: "en",
      author: "sujato",
      authorName: "Bhikkhu Sujato",
      buildTimestamp: "2025-01-09T00:00:00Z",
      files: FilesBreakdown(total: 235),
    )

    let info2 = DatabaseInfo(
      language: "en",
      author: "sujato",
      authorName: "Bhikkhu Sujato",
      buildTimestamp: "2025-01-09T00:00:00Z",
      files: FilesBreakdown(total: 235),
    )

    // Both should have same ID
    #expect(info1.id == info2.id, "Same language/author should have same ID")
  }

  @Test("DatabaseInfo is Equatable")
  func databaseInfoEquatable() {
    let info1 = DatabaseInfo(
      language: "en",
      author: "sujato",
      authorName: "Bhikkhu Sujato",
      buildTimestamp: "2025-01-09T00:00:00Z",
      files: FilesBreakdown(total: 235),
    )

    let info2 = DatabaseInfo(
      language: "en",
      author: "sujato",
      authorName: "Bhikkhu Sujato",
      buildTimestamp: "2025-01-09T00:00:00Z",
      files: FilesBreakdown(total: 235),
    )

    let info3 = DatabaseInfo(
      language: "en",
      author: "soma",
      authorName: "Ayya Soma",
      buildTimestamp: "2025-01-09T00:00:00Z",
      files: FilesBreakdown(total: 100),
    )

    #expect(info1 == info2, "Same content should be equal")
    #expect(info1 != info3, "Different content should not be equal")
  }

  @Test("DatabaseInfo files field backward compatibility")
  func databaseInfoBackwardCompatibility() throws {
    // Test that DatabaseInfo can handle both FilesBreakdown and legacy Int
    // format
    let jsonLegacy = """
    {
      "language": "en",
      "author": "sujato",
      "authorName": "Bhikkhu Sujato",
      "buildTimestamp": "2025-01-09T00:00:00Z",
      "files": 235
    }
    """

    let decoder = JSONDecoder()
    let data = jsonLegacy.data(using: .utf8)!
    let info = try decoder.decode(DatabaseInfo.self, from: data)

    #expect(info.language == "en", "Language should decode correctly")
    #expect(info.author == "sujato", "Author should decode correctly")
    #expect(
      info.files.total == 235,
      "Legacy files int should convert to FilesBreakdown.total",
    )
  }

  @Test("DatabaseInfo extracts authorBaseUrl from json field")
  func extractAuthorBaseUrlFromJson() throws {
    let jsonWithUrl = """
    {
      "language": "en",
      "author": "sujato",
      "authorName": "Bhikkhu Sujato",
      "buildTimestamp": "2025-01-09T00:00:00Z",
      "files": {"sutta": 100, "vinaya": 50, "abhidhamma": 75, "other": 10, "total": 235},
      "json": "{\\"type\\":\\"translator\\",\\"name\\":\\"Bhikkhu Sujato\\",\\"authorBaseURL\\":\\"https://github.com/suttacentral/bilara-data/tree/published/translation/en/sujato\\"}"
    }
    """

    let decoder = JSONDecoder()
    let data = jsonWithUrl.data(using: .utf8)!
    let info = try decoder.decode(DatabaseInfo.self, from: data)

    #expect(
      info.authorBaseUrl != nil,
      "authorBaseUrl should be extracted from json field",
    )
    #expect(
      info
        .authorBaseUrl ==
        "https://github.com/suttacentral/bilara-data/tree/published/translation/en/sujato",
      "authorBaseUrl should match expected GitHub URL",
    )
  }

  @Test("DatabaseInfo authorBaseUrl direct field takes precedence")
  func authorBaseUrlDirectFieldPrecedence() throws {
    let directUrl = "https://github.com/direct/url"
    let jsonUrl = "https://github.com/json/url"

    let jsonWithBoth = """
    {
      "language": "en",
      "author": "sujato",
      "authorName": "Bhikkhu Sujato",
      "buildTimestamp": "2025-01-09T00:00:00Z",
      "files": {"sutta": 100, "vinaya": 50, "abhidhamma": 75, "other": 10, "total": 235},
      "authorBaseUrl": "\(directUrl)",
      "json": "{\\"authorBaseURL\\":\\"\(jsonUrl)\\"}"
    }
    """

    let decoder = JSONDecoder()
    let data = jsonWithBoth.data(using: .utf8)!
    let info = try decoder.decode(DatabaseInfo.self, from: data)

    #expect(
      info.authorBaseUrl == directUrl,
      "Direct authorBaseUrl field should take precedence over json field",
    )
  }

  @Test("DatabaseInfo authorBaseUrl nil when not present")
  func authorBaseUrlNilWhenNotPresent() throws {
    let jsonWithoutUrl = """
    {
      "language": "en",
      "author": "sujato",
      "authorName": "Bhikkhu Sujato",
      "buildTimestamp": "2025-01-09T00:00:00Z",
      "files": {"sutta": 100, "vinaya": 50, "abhidhamma": 75, "other": 10, "total": 235},
      "json": "{\\"type\\":\\"translator\\",\\"name\\":\\"Bhikkhu Sujato\\"}"
    }
    """

    let decoder = JSONDecoder()
    let data = jsonWithoutUrl.data(using: .utf8)!
    let info = try decoder.decode(DatabaseInfo.self, from: data)

    #expect(
      info.authorBaseUrl == nil,
      "authorBaseUrl should be nil when not in json",
    )
  }

  @Test("DatabaseInfo init with authorBaseUrl parameter")
  func initWithAuthorBaseUrl() {
    let url = "https://github.com/example/url"
    let info = DatabaseInfo(
      language: "en",
      author: "sujato",
      authorName: "Bhikkhu Sujato",
      buildTimestamp: "2025-01-09T00:00:00Z",
      files: FilesBreakdown(total: 235),
      authorBaseUrl: url,
    )

    #expect(
      info.authorBaseUrl == url,
      "authorBaseUrl should be set from init parameter",
    )
  }

  @Test("info(language:author:) includes authorBaseUrl for en/sujato")
  func infoEnSujatoProvidesAuthorBaseUrl() {
    let manifest = DatabaseManifest.shared
    let info = manifest.info(language: "en", author: "sujato")

    #expect(info != nil, "Should find en/sujato in manifest")
    if let info {
      #expect(info.authorBaseUrl != nil, "en/sujato should have authorBaseUrl")
      // en/sujato uses bilara-data
      let expectedUrl = "https://github.com/suttacentral/bilara-data/tree/published/translation/en/sujato"
      #expect(
        info.authorBaseUrl == expectedUrl,
        "authorBaseUrl should be bilara-data URL for en/sujato: \(expectedUrl)",
      )
    }
  }

  @Test("info(language:author:) includes authorBaseUrl for fr/noeismet")
  func infoFrNoeismetProvidesAuthorBaseUrl() {
    let manifest = DatabaseManifest.shared
    let info = manifest.info(language: "fr", author: "noeismet")

    #expect(info != nil, "Should find fr/noeismet in manifest")
    if let info {
      #expect(
        info.authorBaseUrl != nil,
        "fr/noeismet should have authorBaseUrl",
      )
      // fr/noeismet falls back to ebt-data (not bilara-data)
      let expectedUrl = "https://github.com/ebt-site/ebt-data/tree/published/translation/fr/noeismet"
      #expect(
        info.authorBaseUrl == expectedUrl,
        "authorBaseUrl should be ebt-data URL for fr/noeismet: \(expectedUrl)",
      )
    }
  }
}
