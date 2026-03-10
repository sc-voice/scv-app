//
//  SuttaRef.swift
//  scv-core
//
//  Created by Claude on 2025-11-20.
//  Ported from scv-esm/src/sutta-ref.mjs
//

import Foundation

/// Represents a parsed Sutta reference with language, author, and segment
/// information
/// Examples: "an1.1-10", "an1.1-10/en/sujato", "an1.1:1.1/en"
public struct SuttaRef: Equatable, Sendable, Codable, Hashable {
  static let cc = ColorConsole(#file, #function, dbg.SuttaRef.other)

  /// The sutta document identifier (e.g., "an1.1-10")
  public let suttaUid: String

  /// The translation language code (e.g., "en", "de", "pli")
  public var lang: String

  /// The translator/author identifier (e.g., "sujato", "sabbamitta")
  public var author: String?

  /// The segment number within the sutta (e.g., "1.1")
  public var segnum: String?

  /// The full segment ID combining sutta_uid and segnum (e.g., "an1.1:1.1")
  public var scid: String

  // MARK: - Initialization

  /// Creates a SuttaRef with validation
  /// - Parameters:
  ///   - suttaUid: Document identifier (must be non-empty, no "/" allowed)
  ///   - lang: Language code
  ///   - author: Translator identifier (optional)
  ///   - segnum: Segment number (optional)
  ///   - scid: Full segment ID (optional, auto-generated if nil)
  public init(
    suttaUid: String,
    lang: String = "pli",
    author: String? = nil,
    segnum: String? = nil,
    scid: String? = nil,
  ) throws {
    guard !suttaUid.isEmpty, !suttaUid.contains("/") else {
      throw SuttaRefError.invalidSuttaUid("use SuttaRef.create(\(suttaUid))")
    }

    // Validate lang: alphanumeric, hyphen, underscore only (prevent path
    // traversal)
    guard lang.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil
    else {
      throw SuttaRefError
        .invalidLang(
          "lang must be alphanumeric with hyphen/underscore: '\(lang)'",
        )
    }

    // Validate author: alphanumeric, hyphen, underscore only (prevent path
    // traversal)
    if let auth = author {
      guard auth.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil
      else {
        throw SuttaRefError
          .invalidAuthor(
            "author must be alphanumeric with hyphen/underscore: '\(auth)'",
          )
      }
    }

    self.suttaUid = suttaUid
    self.lang = lang
    self.author = author
    self.segnum = segnum

    // Auto-generate scid if not provided
    if let providedScid = scid {
      self.scid = providedScid
    } else {
      self.scid = segnum.map { "\(suttaUid):\($0)" } ?? suttaUid
    }
  }

  // MARK: - Static Methods

  /// Creates a SuttaRef from a string reference (e.g.,
  /// "an1.1-10/en/sujato:1.1")
  /// - Parameters:
  ///   - str: String in format "sutta_uid[/lang[/author]][:segnum]"
  ///   - defaultLang: Default language if not specified (default: "pli")
  ///   - defaultAuthor: Default author for non-Pali languages (default: nil)
  ///   - suids: Sorted array of known sutta UIDs (default: auto-loaded)
  /// - Returns: SuttaRef matching the string, or throws if validation fails
  public static func createFromString(
    _ str: String = "",
    defaultLang: String? = nil,
    defaultAuthor: String? = nil,
    suids: [String]? = nil,
  ) throws -> SuttaRef {
    let refLower = str.lowercased()

    // Extract segment number from the end (e.g., ":1.1")
    let segPattern = ":[\\-0-9.]*"
    let segRegex = try NSRegularExpression(pattern: segPattern)
    let segRange = NSRange(refLower.startIndex..., in: refLower)
    var segnum: String? = nil
    var ref = refLower

    if let match = segRegex.firstMatch(in: refLower, range: segRange) {
      if let range = Range(match.range, in: refLower) {
        let segPart = String(refLower[range])
        segnum = String(segPart.dropFirst()) // Remove leading ":"
        ref.replaceSubrange(range, with: "")
      }
    }

    // Parse the main reference parts (sutta_uid/lang/author)
    let parts = ref
      .replacingOccurrences(of: " ", with: "")
      .split(separator: "/")
      .map(String.init)

    let suttaUid = parts.indices.contains(0) ? parts[0] : ""
    let lang = parts.indices.contains(1) ? parts[1] : (defaultLang ?? "pli")
    var author = parts.indices.contains(2) ? parts[2] : nil

    if lang == "pli" {
      author = "ms"
    }
    if author == nil {
      if lang == defaultLang {
        author = defaultAuthor
      }
      if author == nil {
        author = DatabaseManifest.shared
          .defaultAuthorForLanguage(lang)?.author
      }
    }

    // Compute scidValue from original suttaUid and segnum BEFORE range
    // resolution
    let scidValue = segnum.map { "\(suttaUid):\($0)" } ?? suttaUid

    // Handle Pali root text IDs (pli-tv-*) which represent Tipitaka texts
    // These are valid database UIDs but don't match standard sutta reference
    // format
    let finalSuttaUid: String
    if suttaUid.starts(with: "pli-tv-") {
      finalSuttaUid = suttaUid
    } else {
      // Use provided suids or load default for standard sutta references
      let uidList = suids ?? SuttaRef.loadSortedSuids()

      // If we have a SUID list, validate via binary search
      if !uidList.isEmpty {
        finalSuttaUid = try SuttaRef.findSuttaUidInRange(suttaUid, in: uidList)
      } else if !suttaUid.isEmpty {
        // No SUID map; require basic SCID format validation
        guard SuttaCentralId.test(suttaUid) else {
          throw SuttaRefError.suttaNotFound("Invalid sutta_uid: \(suttaUid)")
        }
        finalSuttaUid = suttaUid
      } else {
        throw SuttaRefError.invalidSuttaUid("sutta_uid cannot be empty")
      }
    }

    return try SuttaRef(
      suttaUid: finalSuttaUid,
      lang: lang,
      author: author,
      segnum: segnum,
      scid: scidValue,
    )
  }

  /// Creates a SuttaRef from a dictionary/object
  /// - Parameters:
  ///   - obj: Dictionary containing sutta_uid, lang, author, etc.
  ///   - defaultLang: Default language if not specified (default: "pli")
  ///   - suids: Sorted array of known sutta UIDs (default: auto-loaded)
  /// - Returns: New SuttaRef instance
  public static func createFromObject(
    _ obj: [String: Any],
    defaultLang: String = "pli",
    suids: [String]? = nil,
  ) throws -> SuttaRef {
    // First parse sutta_uid if it's a string
    var parsed: SuttaRef? = nil

    if let suttaUidStr = obj["sutta_uid"] as? String {
      parsed = try? SuttaRef.createFromString(
        suttaUidStr,
        defaultLang: obj["lang"] as? String ?? defaultLang,
        suids: suids,
      )
    }

    let suttaUid = parsed?.suttaUid ?? (obj["sutta_uid"] as? String ?? "")
    let lang = (obj["lang"] as? String) ?? parsed?.lang ?? defaultLang
    var author = obj["author"] as? String ?? parsed?.author
    let segnum = (obj["segnum"] as? String) ?? parsed?.segnum
    let scid: String? = if let explicitScid = obj["scid"] as? String {
      explicitScid
    } else if let seg = segnum {
      "\(suttaUid):\(seg)"
    } else {
      parsed?.scid
    }

    // Handle legacy "translator" synonym
    if let translator = obj["translator"] as? String {
      author = translator
    }

    // Handle mlDoc's author_uid field
    if let authorUid = obj["author_uid"] as? String {
      author = authorUid
    }

    return try SuttaRef(
      suttaUid: suttaUid,
      lang: lang,
      author: author,
      segnum: segnum,
      scid: scid,
    )
  }

  /// Creates a SuttaRef from string or object, returning nil on error
  /// - Parameters:
  ///   - strOrObj: String or Dictionary
  ///   - defaultLang: Default language (default: "pli")
  ///   - defaultAuthor: Default author for non-Pali languages (default: nil)
  ///   - suids: Sorted sutta UIDs (default: auto-loaded)
  /// - Returns: SuttaRef or nil if parsing fails
  public static func create(
    _ strOrObj: Any?,
    defaultLang: String = "pli",
    defaultAuthor: String? = nil,
    suids: [String]? = nil,
  ) -> SuttaRef? {
    guard let input = strOrObj else { return nil }

    do {
      return try createWithError(
        input,
        defaultLang: defaultLang,
        defaultAuthor: defaultAuthor,
        suids: suids,
      )
    } catch {
      // Silently fail, returning nil
      Self.cc.bad1(#line, "create", error)
      return nil
    }
  }

  /// Creates a SuttaRef, throwing errors instead of returning nil
  /// - Parameters:
  ///   - strOrObj: String or Dictionary
  ///   - defaultLang: Default language (default: "pli")
  ///   - defaultAuthor: Default author for non-Pali languages (default: nil)
  ///   - suids: Sorted sutta UIDs (default: auto-loaded)
  /// - Returns: SuttaRef
  public static func createWithError(
    _ strOrObj: Any,
    defaultLang: String = "pli",
    defaultAuthor: String? = nil,
    suids: [String]? = nil,
  ) throws -> SuttaRef {
    if let str = strOrObj as? String {
      return try createFromString(
        str,
        defaultLang: defaultLang,
        defaultAuthor: defaultAuthor,
        suids: suids,
      )
    } else if let dict = strOrObj as? [String: Any] {
      return try createFromObject(dict, defaultLang: defaultLang, suids: suids)
    } else if let ref = strOrObj as? SuttaRef {
      // Create a copy
      return try SuttaRef(
        suttaUid: ref.suttaUid,
        lang: ref.lang,
        author: ref.author,
        segnum: ref.segnum,
        scid: ref.scid,
      )
    } else {
      throw SuttaRefError.invalidInput("Cannot parse \(type(of: strOrObj))")
    }
  }

  // MARK: - Instance Methods

  /// Returns the string representation of this SuttaRef
  /// Format: "sutta_uid[:segnum][/lang[/author]]"
  public func toString() -> String {
    var result = scid ?? suttaUid

    result += "/\(lang)"

    if let auth = author {
      result += "/\(auth)"
    }

    return result
  }

  // MARK: - Private Helpers

  /// Loads and sorts SUID list
  static func loadSortedSuids() -> [String] {
    guard let suids = loadSuidMap() else { return [] }
    return suids
  }

  /// Loads the SUID list from embedded JSON
  /// Returns array of suttauids sorted by SuttaCentralId.compareLow()
  private static func loadSuidMap() -> [String]? {
    // Try to find suid-list.json in bundle or file system
    var url: URL?

    // Method 1: Try Bundle.main
    url = Bundle.main.url(forResource: "suid-list", withExtension: "json")

    // Method 2: Try other bundles (for tests)
    if url == nil {
      for bundle in Bundle.allBundles {
        if let bundleUrl = bundle.url(
          forResource: "suid-list",
          withExtension: "json",
        ) {
          url = bundleUrl
          break
        }
      }
    }

    // Method 3: Try common file paths (for development/debugging)
    if url == nil {
      let paths = [
        "/Users/visakha/dev/scv-app/scv-core/Sources/Resources/suid-list.json",
      ]
      for path in paths {
        if FileManager.default.fileExists(atPath: path) {
          url = URL(fileURLWithPath: path)
          break
        }
      }
    }

    guard let fileUrl = url else {
      return nil
    }

    do {
      let data = try Data(contentsOf: fileUrl)
      let array = try JSONDecoder().decode([String].self, from: data)
      return array
    } catch {
      Self.cc.bad2(#line, "loadSuidMap", error)
      return nil
    }
  }

  /// Finds the sutta_uid in a range using binary search
  static func findSuttaUidInRange(
    _ uid: String,
    in suids: [String],
  ) throws -> String {
    let nSuids = suids.count
    var iLow = 0
    var iHigh = nSuids

    while iLow < iHigh {
      let i = (iLow + iHigh) / 2
      let suid = suids[i]
      let cmpLow = SuttaCentralId.compareLow(uid, suid)
      let cmpHigh = SuttaCentralId.compareHigh(uid, suid)

      if cmpLow >= 0, cmpHigh <= 0 {
        // uid is in range [suid.low, suid.high]
        return suid
      } else if cmpLow < 0 {
        iHigh = i
      } else {
        // cmpHigh > 0
        if iLow == i {
          throw SuttaRefError.suttaNotFound(
            "Cannot find \(uid) in range",
          )
        }
        iLow = i
      }
    }

    throw SuttaRefError.suttaNotFound(
      "Cannot find \(uid) in range",
    )
  }
}

// MARK: - CustomStringConvertible

extension SuttaRef: CustomStringConvertible {
  public var description: String {
    toString()
  }

  // MARK: - Abbreviation

  /// Returns the abbreviated suttaUid with expanded collection prefix
  /// Examples: "mn1" → "MN1", "an1.1-10" → "AN1.1-10", "sn22.1" → "SN22.1"
  /// Note: This computation may be expensive, consider caching the result
  public func abbreviation() -> String {
    let lowerUid = suttaUid.lowercased()
    let prefixLetters = lowerUid.prefix(while: { $0.isLetter })
    let suffix = String(lowerUid.dropFirst(prefixLetters.count))
    let abbrPrefix = SuttaCentralUid
      .abbrMapping[String(prefixLetters)] ?? String(prefixLetters).uppercased()
    return abbrPrefix + suffix
  }
}

// MARK: - Error Type

public enum SuttaRefError: LocalizedError {
  case invalidSuttaUid(String)
  case invalidInput(String)
  case suttaNotFound(String)
  case invalidLang(String)
  case invalidAuthor(String)

  public var errorDescription: String? {
    switch self {
    case let .invalidSuttaUid(msg):
      msg
    case let .invalidInput(msg):
      msg
    case let .suttaNotFound(msg):
      msg
    case let .invalidLang(msg):
      msg
    case let .invalidAuthor(msg):
      msg
    }
  }
}
