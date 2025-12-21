//
//  LemmatizerTests.swift
//  scv-core
//
//  Created by Claude on 2025-12-13.
//

import Foundation
import NaturalLanguage
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

  @Test(
    "Lemmatizer.clean() removes punctuation and lowercases EN text with contractions",
  )
  func cleanEN() {
    let l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)

    // From mn1/en/sujato actual text - with contractions and smart quotes
    #expect(l8r
      .clean("They've not seen the noble ones.") ==
      "they ve not seen the noble ones")
    #expect(l8r
      .clean("they conceive that 'earth is mine', they approve earth.") ==
      "they conceive that earth is mine they approve earth")
    #expect(l8r
      .clean("It's not possible that they would apply their body.") ==
      "it s not possible that they would apply their body")
  }

  @Test(
    "Lemmatizer.lemmatize() EN text with contractions produces split tokens",
  )
  func lemmatizeEN() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)

    // From mn1/en/sujato - contractions are split after clean() removes
    // apostrophe
    // "They've" → clean → "they ve" → lemmatize → ["they", "ve"]
    // Note: "seen" → "see", "ones" → "one" (correct English lemmatization)
    let text1 = "They've not seen the noble ones."
    let lemmas1 = l8r.lemmatize(text1)
    print("[LEMMATIZE EN: They've not seen...] \(lemmas1)")
    #expect(lemmas1 == ["they", "ve", "not", "see", "the", "noble", "one"])

    // From mn1/en/sujato - quoted phrase
    // Single quotes removed by clean()
    // Note: "is" lemmatizes to "be" (verb lemma), "mine" lemmatizes to "i"
    // (pronoun lemma)
    let text2 = "they conceive that 'earth is mine'"
    let lemmas2 = l8r.lemmatize(text2)
    print("[LEMMATIZE EN: they conceive that 'earth is mine'] \(lemmas2)")
    #expect(lemmas2 == ["they", "conceive", "that", "earth", "be", "i"])

    // From mn1/en/sujato - "It's" contraction
    // "It's" → clean → "it s" → lemmatize → ["it", "s"]
    let text3 = "It's not possible"
    let lemmas3 = l8r.lemmatize(text3)
    print("[LEMMATIZE EN: It's not possible] \(lemmas3)")
    #expect(lemmas3 == ["it", "s", "not", "possible"])
  }

  @Test(
    "Lemmatizer.clean() preserves German diacriticals and Pali marks while removing punctuation",
  )
  func cleanDE() {
    let l8r = Lemmatizer(lang: "de", cacheDir: testCacheDir)

    // German diacriticals: ä, ö, ü, ß (lowercase), Ä, Ö, Ü (uppercase →
    // lowercased)
    // Pali marks: ā, ī, ṅ, ṭ, ṇ, ṣ, Ā
    // Punctuation to remove: . , : - ' " „ " < > … = ? ! – ; { } ( ) /

    // From mn1/de/sabbamitta actual text
    #expect(l8r
      .clean(Lemmatizer
        .DOUBLE_LOW_QUOTATION_MARK + "Mönche und Nonnen" + Lemmatizer
        .RIGHT_DOUBLE_QUOTATION_MARK) == "mönche und nonnen")
    #expect(l8r
      .clean("Ehrwürdiger Herr, antworteten sie.") ==
      "ehrwürdiger herr antworteten sie")
    #expect(l8r
      .clean("überreicher Frucht als die von überreicher Frucht wahr.") ==
      "überreicher frucht als die von überreicher frucht wahr")
    #expect(l8r.clean("Salbaumes auf.") == "salbaumes auf")

    // German diacriticals with mixed punctuation
    #expect(l8r
      .clean("strahlendem Glanz " + Lemmatizer.EN_DASH + " überall.") ==
      "strahlendem glanz überall")
    #expect(l8r
      .clean("allumfassender Schönheit, (Teil 1)") ==
      "allumfassender schönheit teil 1")
    #expect(l8r.clean("Größe; [Häuser]") == "größe häuser")

    // German diacriticals with Pali marks
    #expect(l8r
      .clean("abhängig entstehen: Ukkaṭṭhā") == "abhängig entstehen ukkaṭṭhā")
    #expect(l8r
      .clean("Ānanda" + Lemmatizer.EM_DASH + "Überblick; sūkṣma") ==
      "ānanda überblick sūkṣma")

    // Pali marks preservation with German text
    #expect(l8r.clean("niṭṭha-ṇa, größe-sīla") == "niṭṭha ṇa größe sīla")
    #expect(l8r
      .clean("Ātman " + Lemmatizer.EN_DASH + " sūkṣma; ṣaḍ-aṅga") ==
      "ātman sūkṣma ṣaḍ aṅga")
  }

  @Test(
    "Lemmatizer.lemmatize() preserves German diacriticals through lemmatization",
  )
  func lemmatizeDE() {
    var l8r = Lemmatizer(lang: "de", cacheDir: testCacheDir)

    // From mn1/de/sabbamitta actual text - verify diacriticals preserved
    // through full lemmatization
    let text1 = Lemmatizer
      .DOUBLE_LOW_QUOTATION_MARK + "Mönche und Nonnen" + Lemmatizer
      .RIGHT_DOUBLE_QUOTATION_MARK
    let lemmas1 = l8r.lemmatize(text1)
    print("[LEMMATIZE DE: Mönche und Nonnen] \(lemmas1)")
    // Note: German lemmatizer produces singular forms (mönch, nonne)
    #expect(lemmas1 == ["mönch", "und", "nonne"])

    let text2 = "Ehrwürdiger Herr, antworteten sie."
    let lemmas2 = l8r.lemmatize(text2)
    print("[LEMMATIZE DE: Ehrwürdiger Herr, antworteten sie.] \(lemmas2)")
    #expect(lemmas2 == ["ehrwürdiger", "herr", "antworten", "sie"])

    let text3 = "überreicher Frucht als die von überreicher Frucht wahr."
    let lemmas3 = l8r.lemmatize(text3)
    print(
      "[LEMMATIZE DE: überreicher Frucht als die von überreicher Frucht wahr.] \(lemmas3)",
    )
    #expect(lemmas3 == [
      "überreich",
      "frucht",
      "als",
      "der",
      "von",
      "überreich",
      "frucht",
      "wahr",
    ])

    // German diacriticals with search query - this is critical for lemma search
    let text4 = "abhängig entstehen"
    let lemmas4 = l8r.lemmatize(text4)
    print("[LEMMATIZE DE: abhängig entstehen] \(lemmas4)")
    #expect(lemmas4 == ["abhängig", "entstehen"])

    let segmentText = "Da untersucht ein Mönch anhand der Elemente, der Sinnesfelder und des abhängigen Entstehens."
    let lemmasSegment = l8r.lemmatize(segmentText)
    print("[LEMMATIZE DE: sn22.57:18.2 segment] \(lemmasSegment)")
    // Note: "Elemente" → "element" (singular), "des" included, "der" (not
    // "des")
    #expect(lemmasSegment == [
      "da",
      "untersuchen",
      "ein",
      "mönch",
      "anhand",
      "der",
      "element",
      "der",
      "sinnesfelder",
      "und",
      "der",
      "abhängig",
      "entstehen",
    ])

    // German verb conjugation: past participle → infinitive
    // This is why searching for "entstehen" matches segments with "entstanden"
    // (e.g., an10.93/de/sabbamitta)
    let text5 = "abhängige entstanden"
    let lemmas5 = l8r.lemmatize(text5)
    print("[LEMMATIZE DE: abhängige entstanden] \(lemmas5)")
    #expect(lemmas5 == ["abhängig", "entstehen"])

    // German adjective: unfruitful (comparative/superlative forms)
    let text6 = "unfruchtbar"
    let lemmas6 = l8r.lemmatize(text6)
    print("[LEMMATIZE DE: unfruchtbar] \(lemmas6)")
    #expect(lemmas6 == ["unfruchtbar"])
  }

  @Test("Lemmatizer lemmatizes EN test texts with test cache dir")
  func lemmatizeENTestCache() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)

    // Text 1: "For desire is the root of suffering."
    let lemmas1 = l8r.lemmatize(sn42112_11)
    print("[LEMMATIZE TEXT 1] \(lemmas1)")
    // Note: "is" lemmatizes to "be" (verb lemma)
    #expect(lemmas1 == ["for", "desire", "be", "the", "root", "of", "suffer"])

    // Text 2: "For desire is the root of suffering.\'\""
    let lemmas2 = l8r.lemmatize(sn42112_13)
    print("[LEMMATIZE TEXT 2] \(lemmas2)")
    #expect(lemmas2 == lemmas1)

    // Text 3: "Take another individual who, understanding that attachment is
    // the root of suffering,"
    let lemmas3 = l8r.lemmatize(mn66_17_1)
    print("[LEMMATIZE TEXT 3] \(lemmas3)")
    // Note: "is" lemmatizes to "be" (verb lemma)
    #expect(lemmas3 == [
      "take",
      "another",
      "individual",
      "who",
      "understand",
      "that",
      "attachment",
      "be",
      "the",
      "root",
      "of",
      "suffer",
    ])

    // Text 4: "The root of suffering is cut off,"
    let lemmas4 = l8r.lemmatize("The root of suffering is cut off,")
    print("[LEMMATIZE TEXT 4] \(lemmas4)")
    // Note: "is" lemmatizes to "be" (verb lemma)
    #expect(lemmas4 == ["the", "root", "of", "suffer", "be", "cut", "off"])
  }

  @Test("Lemmatizer handles sn42.11:2.11-17")
  func lemmatizeSn42112_11() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)
    let lemmas11 = l8r.lemmatize(sn42112_11)
    let lemmas13 = l8r.lemmatize(sn42112_13)
    let lemmas17 = l8r.lemmatize(sn42112_17)

    // Note: "is" lemmatizes to "be" (verb lemma)
    #expect(lemmas11 == ["for", "desire", "be", "the", "root", "of", "suffer"])
    #expect(lemmas11 == lemmas13)
    #expect(lemmas11 == lemmas17)
  }

  @Test("Lemmatizer handles mn66:17.1")
  func lemmatizeMn66_17_1() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)
    let lemmas = l8r.lemmatize(mn66_17_1)

    // Note: "is" lemmatizes to "be" (verb lemma)
    #expect(lemmas == [
      "take",
      "another",
      "individual",
      "who",
      "understand",
      "that",
      "attachment",
      "be",
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

    // Note: "is" → "be", "are" → "be", "attachments" → "attachment" (singular)
    #expect(lemmas == [
      "understand",
      "that",
      "attachment",
      "be",
      "the",
      "root",
      "of",
      "suffer",
      "they",
      "be",
      "free",
      "with",
      "the",
      "end",
      "of",
      "attachment",
      "it",
      "s",
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

  // TODO: Fix German umlaut handling in lemmatizer
  // Expected: ["da", "untersuchen", "ein", "mnch", "anhand", "der", "elemente",
  //            "der", "sinnesfelder", "und", "des", "abhangige", "entstehen"]
  // Actual:   ["da", "untersuchen", "ein", "mnch", "anhand", "der", "elemente",
  //           "der", "sinnesfelder", "und", "des", "abhngigen", "Entstehen"]
  // Issue: Umlaut stripping inconsistency and capitalization handling
  /*
   @Test("DE Lemmatizer output for sn22.57:18.2 segment")
   func deLemmatizerSegmentSn22_57() {
     var l8r = Lemmatizer(lang: "de", cacheDir: testCacheDir)
     let segmentText = "Da untersucht ein Mönch anhand der Elemente, der Sinnesfelder und des abhängigen Entstehens."
     let lemmas = l8r.lemmatize(segmentText)
     print("[LEMMATIZE DE sn22.57:18.2] \(lemmas)")

     // NOTE: Lemmatizer is stripping umlauts from German words
     // Input: "Mönch" → Output: "mnch" (ö stripped)
     // Input: "abhängigen" → Output: "abhngigen" (ä stripped)
     #expect(lemmas == [
       "da", "untersuchen", "ein", "mnch", "anhand", "der", "elemente",
       "der", "sinnesfelder", "und", "des", "abhangige", "entstehen"
     ])
   }
   */

  /*
   @Test("DE Lemmatizer output without cache")
   func deLemmatizerSegmentSn22_57NoCache() {
     // Disable cache by using /dev/null as cache dir
     var l8r = Lemmatizer(lang: "de", cacheDir: "/dev/null")
     let segmentText = "Da untersucht ein Mönch anhand der Elemente, der Sinnesfelder und des abhängigen Entstehens."
     let lemmas = l8r.lemmatize(segmentText)
     print("[LEMMATIZE DE sn22.57:18.2 NO CACHE] \(lemmas)")
   }
   */

  @Test("NLTagger lemmatizes English words correctly without cache")
  func enNLTaggerTest() {
    let tagger = NLTagger(tagSchemes: [.lemma])
    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

    // Test cases: (input word, expected lemma)
    let testCases: [(String, String)] = [
      ("accumulate", "accumulate"),
      ("abdicate", "abdicate"),
      ("desire", "desire"),
      ("suffering", "suffer"),
      ("attachment", "attachment"),
      ("understanding", "understand"),
      ("root", "root"),
      ("cut", "cut"),
      ("off", "off"),
      ("freed", "free"),
      ("apply", "apply"),
      ("interest", "interest"),
    ]

    for (word, expectedLemma) in testCases {
      var actualLemma = word
      tagger.string = word
      tagger.setLanguage(.english, range: word.startIndex ..< word.endIndex)

      tagger.enumerateTags(
        in: word.startIndex ..< word.endIndex,
        unit: .word,
        scheme: .lemma,
        options: options,
      ) { tag, _ in
        if let tag {
          actualLemma = tag.rawValue
        } else {
          actualLemma = word
        }
        return true
      }

      actualLemma = actualLemma.lowercased()
      print("[NLTagger EN: \(word)] → \(actualLemma)")
      #expect(actualLemma == expectedLemma)
    }
  }

  @Test("Lemmatizer lemmatizes English words with same test cases as NLTagger")
  func enLemmatizerTest() {
    var l8r = Lemmatizer(lang: "en", cacheDir: testCacheDir)

    // Test cases: (input word, expected lemma)
    let testCases: [(String, String)] = [
      ("accumulate", "accumulate"),
      ("abdicate", "abdicate"),
      ("desire", "desire"),
      ("suffering", "suffer"),
      ("attachment", "attachment"),
      ("understanding", "understand"),
      ("root", "root"),
      ("cut", "cut"),
      ("off", "off"),
      ("freed", "free"),
      ("apply", "apply"),
      ("interest", "interest"),
    ]

    for (word, expectedLemma) in testCases {
      let lemmas = l8r.lemmatize(word)
      let actualLemma = lemmas.first ?? word
      print("[Lemmatizer EN: \(word)] → \(actualLemma)")
      #expect(actualLemma == expectedLemma)
    }
  }
}
