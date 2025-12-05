//
//  Segment.swift
//  scv-core
//
//  Created by Claude on 2025-12-03.
//

import Foundation

// MARK: - Segment

/// Represents a single segment (verse) within a Buddhist scripture
public struct Segment: Codable, Equatable, Sendable {
  /// Segment ID (SCID - Sutta Central ID, e.g., "mn1:0.1")
  public let scid: String

  /// Text in MLDocument's language
  public let doc: String?

  /// Reference language text
  public let ref: String?

  /// Pali text
  public let pli: String?

  /// Whether this segment matched the search pattern
  public let matched: Bool

  public init(
    scid: String,
    doc: String? = nil,
    ref: String? = nil,
    pli: String? = nil,
    matched: Bool = false,
  ) {
    self.scid = scid
    self.doc = doc
    self.ref = ref
    self.pli = pli
    self.matched = matched
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let scid = try container.decode(String.self, forKey: .scid)
    let pli = try container.decodeIfPresent(String.self, forKey: .pli)
    let ref = try container.decodeIfPresent(String.self, forKey: .ref)
    let matched = try container
      .decodeIfPresent(Bool.self, forKey: .matched) ?? false

    // Map language field to doc based on docLang from decoder context
    let docLang = decoder
      .userInfo[CodingUserInfoKey(rawValue: "docLang")!] as? String ?? "en"
    let languageKey = CodingKeys(stringValue: docLang) ?? .en
    var doc = try container.decodeIfPresent(String.self, forKey: languageKey)

    // Fallback to .doc key if language-specific key not found
    if doc == nil {
      doc = try container.decodeIfPresent(String.self, forKey: .doc)
    }

    self.init(scid: scid, doc: doc, ref: ref, pli: pli, matched: matched)
  }

  enum CodingKeys: String, CodingKey {
    case scid, doc
    case en, de, pt, es, fr, ru, it
    case ref, pli
    case matched
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(scid, forKey: .scid)
    try container.encodeIfPresent(doc, forKey: .doc)
    try container.encodeIfPresent(ref, forKey: .ref)
    try container.encodeIfPresent(pli, forKey: .pli)
    try container.encode(matched, forKey: .matched)
  }
}

// MARK: - Segment Extensions

public extension Segment {
  /// Returns the best available text (prefers doc, falls back to Pali)
  var displayText: String {
    if let doc, !doc.isEmpty {
      return doc
    } else if let pli, !pli.isEmpty {
      return pli
    } else if let ref, !ref.isEmpty {
      return ref
    }
    return scid
  }

  /// Returns true if this segment contains the search match
  var isMatched: Bool {
    matched
  }
}
