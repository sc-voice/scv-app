//
//  SuttaCentralId.swift
//  scv-core
//
//  Created by Claude on 2025-11-01.
//  Ported from scv-esm/src/sutta-central-id.mjs
//

import Foundation

/// Represents a Sutta Central ID identifier for Buddhist suttas
/// Examples: "mn1.1", "sn45.8:1.2", "thig1.1"
public class SuttaCentralId: CustomStringConvertible {
  public let scid: String

  // MARK: - Initialization

  public init(_ scid: String?) throws {
    guard let scid = scid else {
      throw SuttaCentralIdError
        .invalidId("required scid:\(String(describing: scid))")
    }
    self.scid = scid
  }

  // MARK: - Static Methods

  /// Extracts the last path component (filename)
  static func basename(_ filePath: String) -> String {
    return filePath.components(separatedBy: "/").last ?? filePath
  }

  /// Matches a SCID against a pattern (supports ranges and comma-separated
  /// patterns)
  static func match(_ scid: String, _ pattern: String) -> Bool {
    let id = pattern.contains(":") ? scid : scid.components(separatedBy: ":")[0]

    // Handle multiple patterns separated by commas
    let patterns = pattern.components(separatedBy: ", ")
    if patterns.count > 1 {
      return patterns.reduce(false) { acc, p in
        acc || Self.match(scid, p)
      }
    }

    // Normalize pattern: remove language/translator and spaces
    let scidPat = pattern
      .replacingOccurrences(of: "/[^:]*", with: "", options: .regularExpression)
      .replacingOccurrences(of: " ", with: "")

    let scidLow = Self.rangeLow(id)
    let scidHigh = Self.rangeHigh(id)
    let matchLow = Self.rangeLow(scidPat)
    let matchHigh = Self.rangeHigh(scidPat)

    let cmpL = Self.compareLow(scidHigh, matchLow)
    let cmpH = Self.compareHigh(scidLow, matchHigh)

    return cmpL >= 0 && cmpH <= 0
  }

  /// Extracts the high end of a range (e.g., "mn1-5" -> "mn5.9999")
  static func rangeHigh(_ scid: String) -> String {
    let slashParts = scid.components(separatedBy: "/")
    var scidMain = slashParts[0]
    let suffix = slashParts.count > 1 ? slashParts.dropFirst()
      .joined(separator: "/") : ""

    let extRanges = scidMain.components(separatedBy: "--")
    guard extRanges.count <= 2 else {
      // Error case, but we'll return what we have
      scidMain = extRanges.last ?? scidMain
      return suffix.isEmpty ? scidMain : "\(scidMain)/\(suffix)"
    }

    let c0Parts = extRanges[0].components(separatedBy: ":")
    let c1Parts = extRanges.count > 1 ? extRanges[1]
      .components(separatedBy: ":") : []

    var result = extRanges.last ?? scidMain

    if c1Parts.count > 0 && c0Parts.count > 1 && c1Parts.count < 2 {
      result = "\(c0Parts[0]):\(result)"
    }

    if c0Parts.count > 1 {
      result = result.replacingOccurrences(
        of: "[0-9]+-",
        with: "",
        options: .regularExpression
      )
      result = "\(result).9999"
    } else {
      result = result.replacingOccurrences(
        of: "[0-9]+-",
        with: "",
        options: .regularExpression
      )
    }

    return suffix.isEmpty ? result : "\(result)/\(suffix)"
  }

  /// Extracts the low end of a range (e.g., "mn1-5" -> "mn1")
  static func rangeLow(_ scid: String) -> String {
    let slashParts = scid.components(separatedBy: "/")
    let scidMain = slashParts[0]
    let suffix = slashParts.count > 1 ? slashParts.dropFirst()
      .joined(separator: "/") : ""

    var result = scidMain.components(separatedBy: "--")[0]
    result = result.replacingOccurrences(
      of: "-[0-9]+",
      with: "",
      options: .regularExpression
    )

    return suffix.isEmpty ? result : "\(result)/\(suffix)"
  }

  /// Tests if a string is a valid SCID format
  static func test(_ text: String) -> Bool {
    let commaParts = text
      .lowercased()
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }

    return commaParts.reduce(true) { acc, part in
      let normalized = part.replacingOccurrences(
        of: #"\. *"#,
        with: ".",
        options: .regularExpression
      )
      let pattern = #"^[-a-z]+ ?[0-9]+[-0-9a-z.:/]*$"#
      let regex = try? NSRegularExpression(
        pattern: pattern,
        options: .caseInsensitive
      )
      let range = NSRange(normalized.startIndex..., in: normalized)
      let isValid = regex?.firstMatch(in: normalized, range: range) != nil
      return acc && isValid
    }
  }

  /// Extracts language codes from a SCID string (format: scid/lang)
  static func languages(_ text: String) -> [String] {
    guard test(text) else { return [] }

    let commaParts = text
      .lowercased()
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }

    return commaParts.reduce([]) { acc, part in
      let cparts = part.components(separatedBy: "/")
      guard cparts.count > 1, let lang = cparts[safe: 1] else { return acc }
      return acc.contains(lang) ? acc : acc + [lang]
    }
  }

  /// Converts a glob pattern to a regex pattern
  static func scidRegExp(_ pattern: String?) -> NSRegularExpression? {
    guard let pattern = pattern, !pattern.isEmpty else {
      return try? NSRegularExpression(pattern: ".*")
    }

    let regexPattern = pattern
      .replacingOccurrences(of: ".", with: "\\.")
      .replacingOccurrences(of: "*", with: ".*")
      .replacingOccurrences(of: "?", with: ".")
      .replacingOccurrences(of: "$", with: "\\$")
      .replacingOccurrences(of: "^", with: "\\^")

    return try? NSRegularExpression(pattern: regexPattern)
  }

  /// Parses a part identifier (handles ranges like "1-5" and letter suffixes
  /// like "1a")
  static func partNumber(_ part: String, _ id: String) throws -> [Int] {
    if let n = Int(part) {
      return [n]
    }

    let caretParts = part.components(separatedBy: "^")
    let c0 = caretParts[0]

    if caretParts.count == 1 {
      // No caret, parse letter format (e.g., "1a")
      let c0dig = String(c0.filter { $0.isNumber })
      let c0let = String(c0.filter { $0.isLetter }).lowercased()

      guard let n0 = Int(c0dig) else {
        throw SuttaCentralIdError
          .parseError("partNumber() cannot parse \(part) in \(id)")
      }

      if let firstChar = c0let.first {
        let n1 = Int(firstChar.asciiValue ?? 0) - Int(UInt8(ascii: "a")) + 1
        return [n0, n1]
      } else {
        return [n0]
      }
    } else {
      // With caret
      let c1 = caretParts[1]
      guard let n0 = Int(c0) else {
        throw SuttaCentralIdError
          .parseError("partNumber() cannot parse \(part) in \(id)")
      }

      if let firstChar = c1.first {
        let n1 = Int(firstChar.asciiValue ?? 0) - Int(UInt8(ascii: "z")) - 1
        return [n0, n1]
      } else {
        return [n0]
      }
    }
  }

  /// Extracts the low numeric parts of a SCID
  static func scidNumbersLow(_ idOrPath: String) throws -> [Int] {
    let scid = Self.extractScidFromPath(idOrPath)
    let colonParts = scid.replacingOccurrences(
      of: "^[-a-z]*",
      with: "",
      options: .regularExpression
    ).components(separatedBy: ":")

    let dotParts = colonParts.reduce([String]()) { acc, c in
      acc + c.components(separatedBy: ".")
    }

    let nums = try dotParts.reduce([Int]()) { acc, n in
      let lowPart = n.components(separatedBy: "-")[0]
      return try acc + (Self.partNumber(lowPart, idOrPath))
    }

    return nums
  }

  /// Extracts the high numeric parts of a SCID
  static func scidNumbersHigh(_ idOrPath: String) throws -> [Int] {
    let scid = Self.extractScidFromPath(idOrPath)
    let colonParts = scid.replacingOccurrences(
      of: "^[-a-z]*",
      with: "",
      options: .regularExpression
    ).components(separatedBy: ":")

    let dotParts = colonParts.reduce([String]()) { acc, c in
      acc + c.components(separatedBy: ".")
    }

    let nums = try dotParts.reduce([Int]()) { acc, n in
      let highPart = n.components(separatedBy: "-").last ?? n
      return try acc + (Self.partNumber(highPart, idOrPath))
    }

    return nums
  }

  /// Compares two SCIDs using their high values
  static func compareHigh(_ a: String, _ b: String) -> Int {
    let abase = Self.basename(a)
    let bbase = Self.basename(b)

    let aprefix = Self.extractPrefix(abase)
    let bprefix = Self.extractPrefix(bbase)

    let cmp = aprefix.compare(bprefix, options: .literal)

    if cmp == .orderedSame {
      do {
        let adig = try Self.scidNumbersHigh(a)
        let bdig = try Self.scidNumbersHigh(b)
        let n = max(adig.count, bdig.count)

        for i in 0 ..< n {
          let ai = adig[safe: i]
          let bi = bdig[safe: i]

          if ai == bi {
            continue
          }

          if ai == nil {
            return -(bi ?? 0) != 0 ? -(bi ?? 0) : -1
          }

          if bi == nil {
            return (ai ?? 0) != 0 ? (ai ?? 0) : 1
          }

          return (ai ?? 0) - (bi ?? 0)
        }
      } catch {
        return 0
      }
    }

    return cmp == .orderedAscending ? -1 : (cmp == .orderedDescending ? 1 : 0)
  }

  /// Compares two SCIDs using their low values
  static func compareLow(_ a: String, _ b: String) -> Int {
    let abase = Self.basename(a)
    let bbase = Self.basename(b)

    let adigit = Self.firstDigitIndex(abase)
    let bdigit = Self.firstDigitIndex(bbase)

    let aprefix = adigit < 0 ? abase : String(abase.prefix(adigit))
    let bprefix = bdigit < 0 ? bbase : String(bbase.prefix(bdigit))

    let cmp = aprefix.compare(bprefix, options: .literal)

    if cmp == .orderedSame {
      do {
        let adig = try Self.scidNumbersLow(abase)
        let bdig = try Self.scidNumbersLow(bbase)
        let n = max(adig.count, bdig.count)

        for i in 0 ..< n {
          let ai = adig[safe: i]
          let bi = bdig[safe: i]

          if ai == bi {
            continue
          }

          if ai == nil {
            return -(bi ?? 0) != 0 ? -(bi ?? 0) : -1
          }

          if bi == nil {
            return (ai ?? 0) != 0 ? (ai ?? 0) : 1
          }

          return (ai ?? 0) - (bi ?? 0)
        }
      } catch {
        return 0
      }
    }

    return cmp == .orderedAscending ? -1 : (cmp == .orderedDescending ? 1 : 0)
  }

  // MARK: - Computed Properties

  /// Returns the groups within this SCID (the part after the colon)
  public var groups: [String]? {
    guard let tokens = scid.components(separatedBy: ":") as [String]?,
          tokens.count > 1
    else {
      return nil
    }
    return tokens[1].components(separatedBy: ".")
  }

  /// Returns the nikaya (collection) abbreviation
  public var nikaya: String {
    guard let sutta = sutta else { return "" }
    return sutta.replacingOccurrences(
      of: "[-0-9.]*$",
      with: "",
      options: .regularExpression
    )
  }

  /// Returns the main sutta identifier (part before the colon)
  public var sutta: String? {
    let parts = scid.components(separatedBy: ":")
    return parts.first
  }

  /// Returns the parent SCID in the hierarchy
  public var parent: SuttaCentralId? {
    guard var groups = groups else { return nil }

    // Remove trailing empty part: !groups.pop() && groups.pop()
    let lastPopped = groups.popLast()
    if lastPopped?.isEmpty ?? true {
      _ = groups.popLast()
    }

    if groups.isEmpty {
      guard let suttaVal = sutta else { return nil }
      return try? SuttaCentralId("\(suttaVal):")
    }

    guard let suttaVal = sutta else { return nil }
    return try? SuttaCentralId("\(suttaVal):\(groups.joined(separator: ".")).")
  }

  // MARK: - Instance Methods

  /// Converts abbreviations to standard form (e.g., "mn" -> "MN")
  public func standardForm() -> String {
    let std: [String: String] = [
      "sn": "SN",
      "mn": "MN",
      "dn": "DN",
      "an": "AN",
      "thig": "Thig",
      "thag": "Thag",
    ]

    var result = scid
    for (key, value) in std {
      result = result.replacingOccurrences(of: key, with: value)
    }
    return result
  }

  /// Splits the main sutta part by dots
  public func sectionParts() -> [String] {
    return scid.components(separatedBy: ":")[0].components(separatedBy: ".")
  }

  /// Splits the segment part (after colon) by dots
  public func segmentParts() -> [String]? {
    let parts = scid.components(separatedBy: ":")
    guard parts.count > 1 else { return nil }
    return parts[1].components(separatedBy: ".")
  }

  /// Adds numeric increments to the SCID
  public func add(_ increments: Int...) throws -> SuttaCentralId {
    guard let nikayaVal = nikaya as String? else {
      throw SuttaCentralIdError.parseError("Cannot determine nikaya")
    }

    var id = String(scid.dropFirst(nikayaVal.count))
    let colonParts = id.components(separatedBy: ":")

    if colonParts.count > 1 {
      // Segment ID case
      var dotParts = colonParts[1].components(separatedBy: ".")
      for i in 0 ..< dotParts.count {
        if let increment = increments[safe: i], let current = Int(dotParts[i]) {
          dotParts[i] = String(current + increment)
        } else {
          dotParts[i] = "0"
        }
      }
      id = "\(colonParts[0]):\(dotParts.joined(separator: "."))"
    } else {
      // Document ID case
      var dotParts = colonParts[0].components(separatedBy: ".")
      let n = min(increments.count, dotParts.count)
      for i in 0 ..< n {
        if let current = Int(dotParts[i]) {
          dotParts[i] = String(current + increments[i])
        }
      }
      id = dotParts.joined(separator: ".")
    }

    return try SuttaCentralId("\(nikayaVal)\(id)")
  }

  public var description: String {
    return scid
  }

  // MARK: - Private Helpers

  /// Extracts SCID from a bilara path
  private static func extractScidFromPath(_ idOrPath: String) -> String {
    let parts = idOrPath.components(separatedBy: "/")
    guard let filename = parts.last else { return idOrPath }
    // Remove the file extension suffix (everything after the first underscore)
    return filename.components(separatedBy: "_")[0]
  }

  /// Finds the index of the first digit in a string
  private static func firstDigitIndex(_ str: String) -> Int {
    for (index, char) in str.enumerated() {
      if char.isNumber {
        return index
      }
    }
    return -1
  }

  /// Extracts the prefix before the first digit
  private static func extractPrefix(_ str: String) -> String {
    let index = firstDigitIndex(str)
    return index < 0 ? str : String(str.prefix(index))
  }
}

// MARK: - Error Type

enum SuttaCentralIdError: LocalizedError {
  case invalidId(String)
  case parseError(String)

  var errorDescription: String? {
    switch self {
    case let .invalidId(msg):
      return msg
    case let .parseError(msg):
      return msg
    }
  }
}

// MARK: - Array Safe Access Extension

extension Array {
  subscript(safe index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
