//
//  HTMLParserTests.swift
//  scv-coreTests
//
//  Created by Visakha on 05/11/2025.
//

@testable import scvCore
import Testing

@Suite
struct HTMLParserTests {
  @Test
  func parseSimpleText() {
    let html = "For desire is the root of suffering."
    let result = HTMLParser.parse(htmlString: html)

    #expect(result.hasMatches == false)
    #expect(result.plainText == html)
  }

  @Test
  func parseTextWithMatch() {
    let html = "For desire is the <span class=\"scv-matched\">root of suffering</span>."
    let result = HTMLParser.parse(htmlString: html)

    #expect(result.hasMatches == true)
    #expect(result.plainText == "For desire is the root of suffering.")
  }

  @Test
  func parseMultipleMatches() {
    let html = "The <span class=\"scv-matched\">root</span> of <span class=\"scv-matched\">suffering</span> is desire."
    let result = HTMLParser.parse(htmlString: html)

    #expect(result.hasMatches == true)
    #expect(result.plainText == "The root of suffering is desire.")
  }

  @Test
  func testStripHTML() {
    let html = "For desire is the <span class=\"scv-matched\">root of suffering</span>."
    let plain = HTMLParser.stripHTML(html)

    #expect(plain == "For desire is the root of suffering.")
  }

  @Test
  func parseEmptyString() {
    let html = ""
    let result = HTMLParser.parse(htmlString: html)

    #expect(result.hasMatches == false)
    #expect(result.plainText == "")
  }

  @Test
  func parseOnlyMatch() {
    let html = "<span class=\"scv-matched\">root of suffering</span>"
    let result = HTMLParser.parse(htmlString: html)

    #expect(result.hasMatches == true)
    #expect(result.plainText == "root of suffering")
  }

  @Test
  func parseSpans() {
    let html = "For desire is the <span class=\"scv-matched\">root of suffering</span>."
    let result = HTMLParser.parse(htmlString: html)

    #expect(result.spans.count == 3)
    #expect(result.spans[0].text == "For desire is the ")
    #expect(result.spans[0].isMatched == false)
    #expect(result.spans[1].text == "root of suffering")
    #expect(result.spans[1].isMatched == true)
    #expect(result.spans[2].text == ".")
    #expect(result.spans[2].isMatched == false)
  }

  @Test
  func parseMultipleSpans() {
    let html = "The <span class=\"scv-matched\">root</span> of <span class=\"scv-matched\">suffering</span>."
    let result = HTMLParser.parse(htmlString: html)

    #expect(result.spans.count == 5)
    #expect(result.spans[0].text == "The ")
    #expect(result.spans[0].isMatched == false)
    #expect(result.spans[1].text == "root")
    #expect(result.spans[1].isMatched == true)
    #expect(result.spans[2].text == " of ")
    #expect(result.spans[2].isMatched == false)
    #expect(result.spans[3].text == "suffering")
    #expect(result.spans[3].isMatched == true)
    #expect(result.spans[4].text == ".")
    #expect(result.spans[4].isMatched == false)
  }
}
