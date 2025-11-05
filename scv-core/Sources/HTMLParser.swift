//
//  HTMLParser.swift
//  scv-core
//
//  Created by Visakha on 05/11/2025.
//

import Foundation

// MARK: - HTML Span

public struct HTMLSpan {
  public let text: String
  public let isMatched: Bool

  public init(text: String, isMatched: Bool) {
    self.text = text
    self.isMatched = isMatched
  }
}

// MARK: - HTML Parse Result

public struct HTMLParseResult {
  public let plainText: String
  public let hasMatches: Bool
  public let spans: [HTMLSpan]

  public init(plainText: String, hasMatches: Bool = false, spans: [HTMLSpan] = []) {
    self.plainText = plainText
    self.hasMatches = hasMatches
    self.spans = spans
  }
}

// MARK: - HTML Parser

public class HTMLParser {
  /// Parse HTML string and extract plain text with match indicator
  /// Supports: <span class="scv-matched">text</span> for highlighted text
  /// Color application is handled by the UI layer (SuttaView)
  /// - Parameter htmlString: HTML string containing segment text
  /// - Returns: HTMLParseResult with plain text, match indicator, and individual spans
  public static func parse(htmlString: String) -> HTMLParseResult {
    let plainText = stripHTML(htmlString)
    let hasMatches = htmlString.contains("scv-matched")
    let spans = parseSpans(htmlString)
    return HTMLParseResult(plainText: plainText, hasMatches: hasMatches, spans: spans)
  }

  /// Parse HTML string into individual spans with match indicators
  private static func parseSpans(_ html: String) -> [HTMLSpan] {
    var spans: [HTMLSpan] = []
    let pattern = #"<span class="scv-matched">([^<]*)</span>|([^<]+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return [HTMLSpan(text: html, isMatched: false)]
    }

    let nsString = html as NSString
    regex.enumerateMatches(in: html, range: NSRange(location: 0, length: nsString.length)) { match, _, _ in
      guard let match = match else { return }
      if let range = Range(match.range(at: 1), in: html) {
        spans.append(HTMLSpan(text: String(html[range]), isMatched: true))
      } else if let range = Range(match.range(at: 2), in: html) {
        spans.append(HTMLSpan(text: String(html[range]), isMatched: false))
      }
    }
    return spans.isEmpty ? [HTMLSpan(text: html, isMatched: false)] : spans
  }

  /// Strip HTML tags and return plain text
  public static func stripHTML(_ htmlString: String) -> String {
    let pattern = "<[^>]+>"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return htmlString
    }

    let range = NSRange(htmlString.startIndex..<htmlString.endIndex, in: htmlString)
    let plainText = regex.stringByReplacingMatches(in: htmlString, options: [], range: range, withTemplate: "")
    return plainText
  }
}
