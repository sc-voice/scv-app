//
//  SearchResponse.swift
//  SC-Voice
//
//  Created by Visakha on 22/10/2025.
//

import Foundation

// MARK: - Codable Defaults
private let NIL_STRING_DEFAULT = ""
private let NIL_INT_DEFAULT = 0
private let NIL_DOUBLE_DEFAULT = 0.0
private let NIL_BOOL_DEFAULT = false

// MARK: - Main Search Response
public struct SearchResponse: Codable, Equatable {
  let author: String
  let lang: String
  let searchLang: String
  let minLang: Int
  let maxDoc: Int
  let maxResults: Int
  let pattern: String
  let method: String
  let resultPattern: String
  let segsMatched: Int
  let bilaraPaths: [String]
  let suttaRefs: [String]
  let mlDocs: [MLDocument]

  // Error handling fields
  let searchError: SearchErrorInfo?
  let searchSuggestion: String

  // Computed properties
  var isSuccess: Bool { searchError == nil }

  // Custom initializer with defaults
  init(
    author: String = NIL_STRING_DEFAULT,
    lang: String = NIL_STRING_DEFAULT,
    searchLang: String = NIL_STRING_DEFAULT,
    minLang: Int = NIL_INT_DEFAULT,
    maxDoc: Int = NIL_INT_DEFAULT,
    maxResults: Int = NIL_INT_DEFAULT,
    pattern: String = NIL_STRING_DEFAULT,
    method: String = NIL_STRING_DEFAULT,
    resultPattern: String = NIL_STRING_DEFAULT,
    segsMatched: Int = NIL_INT_DEFAULT,
    bilaraPaths: [String] = [],
    suttaRefs: [String] = [],
    mlDocs: [MLDocument] = [],
    searchError: SearchErrorInfo? = nil,
    searchSuggestion: String = NIL_STRING_DEFAULT
  ) {
    self.author = author
    self.lang = lang
    self.searchLang = searchLang
    self.minLang = minLang
    self.maxDoc = maxDoc
    self.maxResults = maxResults
    self.pattern = pattern
    self.method = method
    self.resultPattern = resultPattern
    self.segsMatched = segsMatched
    self.bilaraPaths = bilaraPaths
    self.suttaRefs = suttaRefs
    self.mlDocs = mlDocs
    self.searchError = searchError
    self.searchSuggestion = searchSuggestion
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case author, lang, searchLang, minLang, maxDoc, maxResults
    case pattern, method, resultPattern, segsMatched
    case bilaraPaths, suttaRefs, mlDocs
    case searchError, searchSuggestion
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let author = try container.decodeIfPresent(String.self, forKey: .author) ?? NIL_STRING_DEFAULT
    let lang = try container.decodeIfPresent(String.self, forKey: .lang) ?? NIL_STRING_DEFAULT
    let searchLang = try container.decodeIfPresent(String.self, forKey: .searchLang) ?? NIL_STRING_DEFAULT
    let minLang = try container.decodeIfPresent(Int.self, forKey: .minLang) ?? NIL_INT_DEFAULT
    let maxDoc = try container.decodeIfPresent(Int.self, forKey: .maxDoc) ?? NIL_INT_DEFAULT
    let maxResults = try container.decodeIfPresent(Int.self, forKey: .maxResults) ?? NIL_INT_DEFAULT
    let pattern = try container.decodeIfPresent(String.self, forKey: .pattern) ?? NIL_STRING_DEFAULT
    let method = try container.decodeIfPresent(String.self, forKey: .method) ?? NIL_STRING_DEFAULT
    let resultPattern = try container.decodeIfPresent(String.self, forKey: .resultPattern) ?? NIL_STRING_DEFAULT
    let segsMatched = try container.decodeIfPresent(Int.self, forKey: .segsMatched) ?? NIL_INT_DEFAULT
    let bilaraPaths = try container.decodeIfPresent([String].self, forKey: .bilaraPaths) ?? []
    let suttaRefs = try container.decodeIfPresent([String].self, forKey: .suttaRefs) ?? []
    let mlDocs = try container.decodeIfPresent([MLDocument].self, forKey: .mlDocs) ?? []
    let searchError = try container.decodeIfPresent(SearchErrorInfo.self, forKey: .searchError)
    let searchSuggestion = try container.decodeIfPresent(String.self, forKey: .searchSuggestion) ?? NIL_STRING_DEFAULT

    self.init(
      author: author,
      lang: lang,
      searchLang: searchLang,
      minLang: minLang,
      maxDoc: maxDoc,
      maxResults: maxResults,
      pattern: pattern,
      method: method,
      resultPattern: resultPattern,
      segsMatched: segsMatched,
      bilaraPaths: bilaraPaths,
      suttaRefs: suttaRefs,
      mlDocs: mlDocs,
      searchError: searchError,
      searchSuggestion: searchSuggestion
    )
  }

  // MARK: - Equatable

  public static func == (lhs: SearchResponse, rhs: SearchResponse) -> Bool {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      let lhsData = try encoder.encode(lhs)
      let rhsData = try encoder.encode(rhs)
      let lhsString = String(data: lhsData, encoding: .utf8) ?? ""
      let rhsString = String(data: rhsData, encoding: .utf8) ?? ""
      return lhsString == rhsString
    } catch {
      return false
    }
  }

  // MARK: - JSON Serialization

  /// Creates a SearchResponse from a JSON string
  /// - Parameter jsonString: A JSON string representation of SearchResponse
  /// - Returns: A decoded SearchResponse, or nil if decoding fails
  public static func fromJSON(_ jsonString: String) -> SearchResponse? {
    guard let data = jsonString.data(using: .utf8) else {
      return nil
    }
    do {
      return try JSONDecoder().decode(SearchResponse.self, from: data)
    } catch {
      return nil
    }
  }

  /// Converts SearchResponse to a JSON string
  /// - Returns: A JSON string representation of SearchResponse, or nil if encoding fails
  public func toJSON() -> String? {
    do {
      let data = try JSONEncoder().encode(self)
      return String(data: data, encoding: .utf8)
    } catch {
      return nil
    }
  }
}

// MARK: - Search Error Info
public struct SearchErrorInfo: Codable, Equatable {
  let code: String
  let message: String
}

// MARK: - ML Document
public struct MLDocument: Codable, Equatable {
  let author: String
  let segMap: [String: Segment]
  let blurb: String
  let stats: DocumentStats?

  // Additional fields from MockResponse
  let author_uid: String
  let bilaraPaths: [String]
  let category: String
  let footer: String
  let hyphen: String
  let lang: String
  let langSegs: [String: Int]
  let maxWord: Int
  let minWord: Int
  let score: Double
  let segsMatched: Int
  let sutta_uid: String
  let title: String
  let type: String
  let trilingual: Bool
  let docLang: String
  let docAuthor: String
  let docAuthorName: String
  let docFooter: String
  let refLang: String
  let refAuthor: String
  let refAuthorName: String
  let refFooter: String

  init(
    author: String = NIL_STRING_DEFAULT,
    segMap: [String: Segment] = [:],
    blurb: String = NIL_STRING_DEFAULT,
    stats: DocumentStats? = nil,
    author_uid: String = NIL_STRING_DEFAULT,
    bilaraPaths: [String] = [],
    category: String = NIL_STRING_DEFAULT,
    footer: String = NIL_STRING_DEFAULT,
    hyphen: String = NIL_STRING_DEFAULT,
    lang: String = NIL_STRING_DEFAULT,
    langSegs: [String: Int] = [:],
    maxWord: Int = NIL_INT_DEFAULT,
    minWord: Int = NIL_INT_DEFAULT,
    score: Double = NIL_DOUBLE_DEFAULT,
    segsMatched: Int = NIL_INT_DEFAULT,
    sutta_uid: String = NIL_STRING_DEFAULT,
    title: String = NIL_STRING_DEFAULT,
    type: String = NIL_STRING_DEFAULT,
    trilingual: Bool = NIL_BOOL_DEFAULT,
    docLang: String = NIL_STRING_DEFAULT,
    docAuthor: String = NIL_STRING_DEFAULT,
    docAuthorName: String = NIL_STRING_DEFAULT,
    docFooter: String = NIL_STRING_DEFAULT,
    refLang: String = NIL_STRING_DEFAULT,
    refAuthor: String = NIL_STRING_DEFAULT,
    refAuthorName: String = NIL_STRING_DEFAULT,
    refFooter: String = NIL_STRING_DEFAULT
  ) {
    self.author = author
    self.segMap = segMap
    self.blurb = blurb
    self.stats = stats
    self.author_uid = author_uid
    self.bilaraPaths = bilaraPaths
    self.category = category
    self.footer = footer
    self.hyphen = hyphen
    self.lang = lang
    self.langSegs = langSegs
    self.maxWord = maxWord
    self.minWord = minWord
    self.score = score
    self.segsMatched = segsMatched
    self.sutta_uid = sutta_uid
    self.title = title
    self.type = type
    self.trilingual = trilingual
    self.docLang = docLang
    self.docAuthor = docAuthor
    self.docAuthorName = docAuthorName
    self.docFooter = docFooter
    self.refLang = refLang
    self.refAuthor = refAuthor
    self.refAuthorName = refAuthorName
    self.refFooter = refFooter
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let author = try container.decodeIfPresent(String.self, forKey: .author) ?? NIL_STRING_DEFAULT
    let segMap = try container.decodeIfPresent([String: Segment].self, forKey: .segMap) ?? [:]
    let blurb = try container.decodeIfPresent(String.self, forKey: .blurb) ?? NIL_STRING_DEFAULT
    let stats = try container.decodeIfPresent(DocumentStats.self, forKey: .stats)
    let author_uid = try container.decodeIfPresent(String.self, forKey: .author_uid) ?? NIL_STRING_DEFAULT
    let bilaraPaths = try container.decodeIfPresent([String].self, forKey: .bilaraPaths) ?? []
    let category = try container.decodeIfPresent(String.self, forKey: .category) ?? NIL_STRING_DEFAULT
    let footer = try container.decodeIfPresent(String.self, forKey: .footer) ?? NIL_STRING_DEFAULT
    let hyphen = try container.decodeIfPresent(String.self, forKey: .hyphen) ?? NIL_STRING_DEFAULT
    let lang = try container.decodeIfPresent(String.self, forKey: .lang) ?? NIL_STRING_DEFAULT
    let langSegs = try container.decodeIfPresent([String: Int].self, forKey: .langSegs) ?? [:]
    let maxWord = try container.decodeIfPresent(Int.self, forKey: .maxWord) ?? NIL_INT_DEFAULT
    let minWord = try container.decodeIfPresent(Int.self, forKey: .minWord) ?? NIL_INT_DEFAULT
    let score = try container.decodeIfPresent(Double.self, forKey: .score) ?? NIL_DOUBLE_DEFAULT
    let segsMatched = try container.decodeIfPresent(Int.self, forKey: .segsMatched) ?? NIL_INT_DEFAULT
    let sutta_uid = try container.decodeIfPresent(String.self, forKey: .sutta_uid) ?? NIL_STRING_DEFAULT
    let title = try container.decodeIfPresent(String.self, forKey: .title) ?? NIL_STRING_DEFAULT
    let type = try container.decodeIfPresent(String.self, forKey: .type) ?? NIL_STRING_DEFAULT
    let trilingual = try container.decodeIfPresent(Bool.self, forKey: .trilingual) ?? NIL_BOOL_DEFAULT
    let docLang = try container.decodeIfPresent(String.self, forKey: .docLang) ?? NIL_STRING_DEFAULT
    let docAuthor = try container.decodeIfPresent(String.self, forKey: .docAuthor) ?? NIL_STRING_DEFAULT
    let docAuthorName = try container.decodeIfPresent(String.self, forKey: .docAuthorName) ?? NIL_STRING_DEFAULT
    let docFooter = try container.decodeIfPresent(String.self, forKey: .docFooter) ?? NIL_STRING_DEFAULT
    let refLang = try container.decodeIfPresent(String.self, forKey: .refLang) ?? NIL_STRING_DEFAULT
    let refAuthor = try container.decodeIfPresent(String.self, forKey: .refAuthor) ?? NIL_STRING_DEFAULT
    let refAuthorName = try container.decodeIfPresent(String.self, forKey: .refAuthorName) ?? NIL_STRING_DEFAULT
    let refFooter = try container.decodeIfPresent(String.self, forKey: .refFooter) ?? NIL_STRING_DEFAULT

    self.init(
      author: author,
      segMap: segMap,
      blurb: blurb,
      stats: stats,
      author_uid: author_uid,
      bilaraPaths: bilaraPaths,
      category: category,
      footer: footer,
      hyphen: hyphen,
      lang: lang,
      langSegs: langSegs,
      maxWord: maxWord,
      minWord: minWord,
      score: score,
      segsMatched: segsMatched,
      sutta_uid: sutta_uid,
      title: title,
      type: type,
      trilingual: trilingual,
      docLang: docLang,
      docAuthor: docAuthor,
      docAuthorName: docAuthorName,
      docFooter: docFooter,
      refLang: refLang,
      refAuthor: refAuthor,
      refAuthorName: refAuthorName,
      refFooter: refFooter
    )
  }

  enum CodingKeys: String, CodingKey {
    case author
    case segMap
    case blurb
    case stats
    case author_uid
    case bilaraPaths
    case category
    case footer
    case hyphen
    case lang
    case langSegs
    case maxWord
    case minWord
    case score
    case segsMatched
    case sutta_uid
    case title
    case type
    case trilingual
    case docLang
    case docAuthor
    case docAuthorName
    case docFooter
    case refLang
    case refAuthor
    case refAuthorName
    case refFooter
  }
}

// MARK: - Segment
public struct Segment: Codable, Equatable {
  let scid: String
  let pli: String
  let ref: String
  let en: String
  let matched: Bool

  init(
    scid: String,
    pli: String = NIL_STRING_DEFAULT,
    ref: String = NIL_STRING_DEFAULT,
    en: String = NIL_STRING_DEFAULT,
    matched: Bool = NIL_BOOL_DEFAULT
  ) {
    self.scid = scid
    self.pli = pli
    self.ref = ref
    self.en = en
    self.matched = matched
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let scid = try container.decode(String.self, forKey: .scid)
    let pli = try container.decodeIfPresent(String.self, forKey: .pli) ?? NIL_STRING_DEFAULT
    let ref = try container.decodeIfPresent(String.self, forKey: .ref) ?? NIL_STRING_DEFAULT
    let en = try container.decodeIfPresent(String.self, forKey: .en) ?? NIL_STRING_DEFAULT
    let matched = try container.decodeIfPresent(Bool.self, forKey: .matched) ?? NIL_BOOL_DEFAULT

    self.init(scid: scid, pli: pli, ref: ref, en: en, matched: matched)
  }

  enum CodingKeys: String, CodingKey {
    case scid
    case pli
    case ref
    case en
    case matched
  }
}

// MARK: - Document Stats
public struct DocumentStats: Codable, Equatable {
  let text: Int
  let lang: String
  let nSegments: Int
  let nEmptySegments: Int
  let nSections: Int
  let seconds: Double

  init(
    text: Int = NIL_INT_DEFAULT,
    lang: String = NIL_STRING_DEFAULT,
    nSegments: Int = NIL_INT_DEFAULT,
    nEmptySegments: Int = NIL_INT_DEFAULT,
    nSections: Int = NIL_INT_DEFAULT,
    seconds: Double = NIL_DOUBLE_DEFAULT
  ) {
    self.text = text
    self.lang = lang
    self.nSegments = nSegments
    self.nEmptySegments = nEmptySegments
    self.nSections = nSections
    self.seconds = seconds
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let text = try container.decodeIfPresent(Int.self, forKey: .text) ?? NIL_INT_DEFAULT
    let lang = try container.decodeIfPresent(String.self, forKey: .lang) ?? NIL_STRING_DEFAULT
    let nSegments = try container.decodeIfPresent(Int.self, forKey: .nSegments) ?? NIL_INT_DEFAULT
    let nEmptySegments = try container.decodeIfPresent(Int.self, forKey: .nEmptySegments) ?? NIL_INT_DEFAULT
    let nSections = try container.decodeIfPresent(Int.self, forKey: .nSections) ?? NIL_INT_DEFAULT
    let seconds = try container.decodeIfPresent(Double.self, forKey: .seconds) ?? NIL_DOUBLE_DEFAULT

    self.init(text: text, lang: lang, nSegments: nSegments, nEmptySegments: nEmptySegments, nSections: nSections, seconds: seconds)
  }

  enum CodingKeys: String, CodingKey {
    case text
    case lang
    case nSegments
    case nEmptySegments
    case nSections
    case seconds
  }
}

// MARK: - Search Response Extensions
extension SearchResponse {
  /// Returns all segments that matched the search pattern
  var matchedSegments: [Segment] {
    return mlDocs.flatMap { doc in
      doc.segMap.values.filter { $0.matched == true }
    }
  }
  
  /// Returns the total number of documents
  var totalDocuments: Int {
    return mlDocs.count
  }
  
  /// Returns all unique sutta references
  var uniqueSuttaRefs: [String] {
    return Array(Set(suttaRefs))
  }
  
  /// Creates a failure SearchResponse with error information
  /// - Parameters:
  ///   - code: Error code (e.g., "file_not_found", "network_error")
  ///   - message: Human-readable error message
  ///   - suggestion: Optional remediation advice
  ///   - pattern: The search pattern that was attempted
  /// - Returns: A SearchResponse representing a failed search
  static func failure(
    code: String,
    message: String,
    suggestion: String? = nil,
    pattern: String
  ) -> SearchResponse {
    return SearchResponse(
      author: "",
      lang: "",
      searchLang: "",
      minLang: 0,
      maxDoc: 0,
      maxResults: 0,
      pattern: pattern,
      method: "",
      resultPattern: "",
      segsMatched: 0,
      bilaraPaths: [],
      suttaRefs: [],
      mlDocs: [],
      searchError: SearchErrorInfo(code: code, message: message),
      searchSuggestion: suggestion ?? NIL_STRING_DEFAULT
    )
  }

  /// Creates a mock SearchResponse from MockResponse.json resource file
  /// Works in both production and test environments
  /// - Returns: A SearchResponse loaded from the resource, or nil if loading fails
  static func createMockResponse() -> SearchResponse? {
    guard let resourceURL = Bundle.module.url(forResource: "MockResponse", withExtension: "json"),
          let data = try? Data(contentsOf: resourceURL) else {
      return nil
    }

    do {
      return try JSONDecoder().decode(SearchResponse.self, from: data)
    } catch {
      return nil
    }
  }
}

// MARK: - ML Document Extensions
extension MLDocument {
  /// Returns all segments for this document
  var allSegments: [Segment] {
    return Array(segMap.values)
  }

  /// Returns only matched segments for this document
  var matchedSegments: [Segment] {
    return segMap.values.filter { $0.matched == true }
  }

  /// Returns the document computed title from the blurb (if title field is empty)
  var computedTitle: String {
    // Use provided title if available
    if !title.isEmpty {
      return title
    }
    // Extract title from blurb or use sutta_uid as fallback
    if let firstSentence = blurb.components(separatedBy: ".").first {
      let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        return trimmed
      }
    }
    return sutta_uid
  }
}

// MARK: - Segment Extensions
extension Segment {
  /// Returns the best available text (prefers English, falls back to Pali)
  var displayText: String {
    if !en.isEmpty {
      return en
    } else if !pli.isEmpty {
      return pli
    } else if !ref.isEmpty {
      return ref
    }
    return scid
  }

  /// Returns true if this segment contains the search match
  var isMatched: Bool {
    return matched
  }
}
