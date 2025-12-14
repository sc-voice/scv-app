//
//  LemmatizerTests.swift
//  scv-core
//
//  Created by Claude on 2025-12-13.
//

import Foundation
@testable import scvCore
import Testing

@Suite("Lemmatizer Tests")
struct LemmatizerTests {
  let sn42112_11 = "For desire is the root of suffering. "
  let sn42112_13 = "For desire is the root of suffering.'\""
  let sn42112_17 = "For desire is the root of suffering.'"
  let mn66_17_1 = "Take another individual who, understanding that attachment is the root of suffering, "
  let mn105_29_9 = "Understanding that attachment is the root of suffering, they are freed with the ending of attachments. It's not possible that they would apply their body or interest their mind in any attachment. "
  let testCacheDir = NSTemporaryDirectory()

  @Test("Lemmatizer.clean() removes punctuation and lowercases")
  func cleanRemovesPunctuation() {
    let l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)

    #expect(l8r.clean(sn42112_11) == "for desire is the root of suffering")
    #expect(l8r.clean(sn42112_13) == "for desire is the root of suffering")
    #expect(l8r
      .clean(
        "Take another individual who, understanding that attachment is the root of suffering,",
      ) ==
      "take another individual who understanding that attachment is the root of suffering")
    #expect(l8r
      .clean("The root of suffering is cut off,") ==
      "the root of suffering is cut off")
  }

  @Test("Lemmatizer lemmatizes EN test texts with test cache dir")
  func lemmatizeENTestCache() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)

    // Text 1: "For desire is the root of suffering."
    let lemmas1 = l8r.lemmatize(sn42112_11)
    print("[LEMMATIZE TEXT 1] \(lemmas1)")
    #expect(lemmas1 == ["for", "desire", "is", "the", "root", "of", "suffer"])

    // Text 2: "For desire is the root of suffering.\'\""
    let lemmas2 = l8r.lemmatize(sn42112_13)
    print("[LEMMATIZE TEXT 2] \(lemmas2)")
    #expect(lemmas2 == lemmas1)

    // Text 3: "Take another individual who, understanding that attachment is
    // the root of suffering,"
    let lemmas3 = l8r.lemmatize(mn66_17_1)
    print("[LEMMATIZE TEXT 3] \(lemmas3)")
    #expect(lemmas3 == [
      "take",
      "another",
      "individual",
      "who",
      "understand",
      "that",
      "attachment",
      "is",
      "the",
      "root",
      "of",
      "suffer",
    ])

    // Text 4: "The root of suffering is cut off,"
    let lemmas4 = l8r.lemmatize("The root of suffering is cut off,")
    print("[LEMMATIZE TEXT 4] \(lemmas4)")
    #expect(lemmas4 == ["the", "root", "of", "suffer", "is", "cut", "off"])
  }

  @Test("Lemmatizer handles sn42.11:2.11-17")
  func lemmatizeSn42112_11() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)
    let lemmas11 = l8r.lemmatize(sn42112_11)
    let lemmas13 = l8r.lemmatize(sn42112_13)
    let lemmas17 = l8r.lemmatize(sn42112_17)

    #expect(lemmas11 == ["for", "desire", "is", "the", "root", "of", "suffer"])
    #expect(lemmas11 == lemmas13)
    #expect(lemmas11 == lemmas17)
  }

  @Test("Lemmatizer handles mn66:17.1")
  func lemmatizeMn66_17_1() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)
    let lemmas = l8r.lemmatize(mn66_17_1)

    #expect(lemmas == [
      "take",
      "another",
      "individual",
      "who",
      "understand",
      "that",
      "attachment",
      "is",
      "the",
      "root",
      "of",
      "suffer",
    ])
  }

  @Test("Lemmatizer handles mn105:29.9")
  func lemmatizeMn105_29_9() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)
    let lemmas = l8r.lemmatize(mn105_29_9)

    #expect(lemmas == [
      "understand",
      "that",
      "attachment",
      "is",
      "the",
      "root",
      "of",
      "suffer",
      "they",
      "are",
      "free",
      "with",
      "the",
      "end",
      "of",
      "attachments",
      "its",
      "not",
      "possible",
      "that",
      "they",
      "would",
      "apply",
      "their",
      "body",
      "or",
      "interest",
      "their",
      "mind",
      "in",
      "any",
      "attachment",
    ])
  }

  @Test("Lemmatizer for SQL data storage")
  func lemmatizeForSqlData() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)
    let padded = l8r.lemmatizeForSqlData(sn42112_11)

    #expect(padded.starts(with: " "), "Should start with space")
    #expect(padded.hasSuffix(" "), "Should end with space")
    #expect(
      padded.contains(" root "),
      "Should contain ' root ' for LIKE matching",
    )
    #expect(
      padded.contains(" suffer "),
      "Should contain ' suffer ' for LIKE matching",
    )
  }
}
