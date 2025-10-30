//
//  SearchResponse.swift
//  SC-Voice
//
//  Created by Visakha on 22/10/2025.
//

import Foundation

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
  let searchSuggestion: String?

  // Computed properties
  var isSuccess: Bool { searchError == nil }

  // Custom initializer with defaults
  init(
    author: String = "",
    lang: String = "",
    searchLang: String = "",
    minLang: Int = 0,
    maxDoc: Int = 0,
    maxResults: Int = 0,
    pattern: String = "",
    method: String = "",
    resultPattern: String = "",
    segsMatched: Int = 0,
    bilaraPaths: [String] = [],
    suttaRefs: [String] = [],
    mlDocs: [MLDocument] = [],
    searchError: SearchErrorInfo? = nil,
    searchSuggestion: String? = nil
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

  // MARK: - Equatable

  public static func == (lhs: SearchResponse, rhs: SearchResponse) -> Bool {
    do {
      let lhsData = try JSONEncoder().encode(lhs)
      let rhsData = try JSONEncoder().encode(rhs)
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
  let suttaCode: String
  let blurb: String
  let stats: DocumentStats
}

// MARK: - Segment
public struct Segment: Codable, Equatable {
  let scid: String
  let pli: String?
  let ref: String?
  let en: String?
  let matched: Bool?

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
      searchSuggestion: suggestion
    )
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
  
  /// Returns the document title from the blurb
  var title: String {
    // Extract title from blurb or use suttaCode as fallback
    if let firstSentence = blurb.components(separatedBy: ".").first {
      return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return suttaCode
  }
}

// MARK: - Segment Extensions
extension Segment {
  /// Returns the best available text (prefers English, falls back to Pali)
  var displayText: String {
    if let english = en, !english.isEmpty {
      return english
    } else if let pali = pli, !pali.isEmpty {
      return pali
    } else if let ref = ref, !ref.isEmpty {
      return ref
    }
    return scid
  }
  
  /// Returns true if this segment contains the search match
  var isMatched: Bool {
    return matched == true
  }
}
