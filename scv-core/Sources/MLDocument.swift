//
//  MLDocument.swift
//  SC-Voice
//
//  Core application object representing a multi-language document
//  Created by Visakha on 22/10/2025.
//

import Foundation
import SwiftData

// MARK: - ML Document
@Model
public final class MLDocument: Codable {
  public var author: String
  public var segMap: [String: Segment]
  public var blurb: String
  public var stats: DocumentStats?

  // Additional fields from MockResponse
  public var author_uid: String
  public var bilaraPaths: [String]
  public var category: String
  public var footer: String
  public var hyphen: String
  public var lang: String
  public var langSegs: [String: Int]
  public var maxWord: Int
  public var minWord: Int
  public var score: Double
  public var segsMatched: Int
  public var sutta_uid: String
  public var title: String
  public var type: String
  public var trilingual: Bool
  public var docLang: String
  public var docAuthor: String
  public var docAuthorName: String
  public var docFooter: String
  public var refLang: String
  public var refAuthor: String
  public var refAuthorName: String
  public var refFooter: String

  // Selection tracking
  public var currentScid: String?

  public init(
    author: String = "",
    segMap: [String: Segment] = [:],
    blurb: String = "",
    stats: DocumentStats? = nil,
    author_uid: String = "",
    bilaraPaths: [String] = [],
    category: String = "",
    footer: String = "",
    hyphen: String = "",
    lang: String = "",
    langSegs: [String: Int] = [:],
    maxWord: Int = 0,
    minWord: Int = 0,
    score: Double = 0.0,
    segsMatched: Int = 0,
    sutta_uid: String = "",
    title: String = "",
    type: String = "",
    trilingual: Bool = false,
    docLang: String = "",
    docAuthor: String = "",
    docAuthorName: String = "",
    docFooter: String = "",
    refLang: String = "",
    refAuthor: String = "",
    refAuthorName: String = "",
    refFooter: String = "",
    currentScid: String? = nil
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
    self.currentScid = currentScid
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
    segMap = try container.decodeIfPresent([String: Segment].self, forKey: .segMap) ?? [:]
    blurb = try container.decodeIfPresent(String.self, forKey: .blurb) ?? ""
    stats = try container.decodeIfPresent(DocumentStats.self, forKey: .stats)
    author_uid = try container.decodeIfPresent(String.self, forKey: .author_uid) ?? ""
    bilaraPaths = try container.decodeIfPresent([String].self, forKey: .bilaraPaths) ?? []
    category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
    footer = try container.decodeIfPresent(String.self, forKey: .footer) ?? ""
    hyphen = try container.decodeIfPresent(String.self, forKey: .hyphen) ?? ""
    lang = try container.decodeIfPresent(String.self, forKey: .lang) ?? ""
    langSegs = try container.decodeIfPresent([String: Int].self, forKey: .langSegs) ?? [:]
    maxWord = try container.decodeIfPresent(Int.self, forKey: .maxWord) ?? 0
    minWord = try container.decodeIfPresent(Int.self, forKey: .minWord) ?? 0
    score = try container.decodeIfPresent(Double.self, forKey: .score) ?? 0.0
    segsMatched = try container.decodeIfPresent(Int.self, forKey: .segsMatched) ?? 0
    sutta_uid = try container.decodeIfPresent(String.self, forKey: .sutta_uid) ?? ""
    title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
    trilingual = try container.decodeIfPresent(Bool.self, forKey: .trilingual) ?? false
    docLang = try container.decodeIfPresent(String.self, forKey: .docLang) ?? ""
    docAuthor = try container.decodeIfPresent(String.self, forKey: .docAuthor) ?? ""
    docAuthorName = try container.decodeIfPresent(String.self, forKey: .docAuthorName) ?? ""
    docFooter = try container.decodeIfPresent(String.self, forKey: .docFooter) ?? ""
    refLang = try container.decodeIfPresent(String.self, forKey: .refLang) ?? ""
    refAuthor = try container.decodeIfPresent(String.self, forKey: .refAuthor) ?? ""
    refAuthorName = try container.decodeIfPresent(String.self, forKey: .refAuthorName) ?? ""
    refFooter = try container.decodeIfPresent(String.self, forKey: .refFooter) ?? ""
    currentScid = try container.decodeIfPresent(String.self, forKey: .currentScid)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(author, forKey: .author)
    try container.encode(segMap, forKey: .segMap)
    try container.encode(blurb, forKey: .blurb)
    try container.encodeIfPresent(stats, forKey: .stats)
    try container.encode(author_uid, forKey: .author_uid)
    try container.encode(bilaraPaths, forKey: .bilaraPaths)
    try container.encode(category, forKey: .category)
    try container.encode(footer, forKey: .footer)
    try container.encode(hyphen, forKey: .hyphen)
    try container.encode(lang, forKey: .lang)
    try container.encode(langSegs, forKey: .langSegs)
    try container.encode(maxWord, forKey: .maxWord)
    try container.encode(minWord, forKey: .minWord)
    try container.encode(score, forKey: .score)
    try container.encode(segsMatched, forKey: .segsMatched)
    try container.encode(sutta_uid, forKey: .sutta_uid)
    try container.encode(title, forKey: .title)
    try container.encode(type, forKey: .type)
    try container.encode(trilingual, forKey: .trilingual)
    try container.encode(docLang, forKey: .docLang)
    try container.encode(docAuthor, forKey: .docAuthor)
    try container.encode(docAuthorName, forKey: .docAuthorName)
    try container.encode(docFooter, forKey: .docFooter)
    try container.encode(refLang, forKey: .refLang)
    try container.encode(refAuthor, forKey: .refAuthor)
    try container.encode(refAuthorName, forKey: .refAuthorName)
    try container.encode(refFooter, forKey: .refFooter)
    try container.encodeIfPresent(currentScid, forKey: .currentScid)
  }

  /// Returns segments sorted in SuttaCentralId order
  public func segments() -> [(key: String, value: Segment)] {
    segMap.sorted { lhs, rhs in
      SuttaCentralId.compareLow(lhs.key, rhs.key) < 0
    }
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
    case currentScid
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

  /// Returns the index of a segment with the given scid in the sorted segments array
  func indexOfScid(_ scid: String) -> Int? {
    let sortedSegments = segments()
    return sortedSegments.firstIndex { $0.key == scid }
  }
}
