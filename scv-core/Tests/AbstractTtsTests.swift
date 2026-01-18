@testable import scvCore
import Testing

@Suite
struct AbstractTtsTests {
  let BREAK = "<break time=\"0.001s\"/>"

  @Test
  func breaks() {
    let tts = AbstractTts()
    #expect(tts.break(0) == "<break time=\"0.001s\"/>")
    #expect(tts.break(1) == "<break time=\"0.1s\"/>")
    #expect(tts.break(4) == "<break time=\"1s\"/>")
    #expect(tts.sectionBreak() == "<break time=\"1s\"/>")

    let ttsCustom = AbstractTts(breaks: [0.5, 1.5, 2.5])
    #expect(ttsCustom.break(0) == "<break time=\"0.5s\"/>")
    #expect(ttsCustom.break(1) == "<break time=\"1.5s\"/>")
    #expect(ttsCustom.break(2) == "<break time=\"2.5s\"/>")
  }

  @Test
  func ipaWord() {
    let tts = AbstractTts()

    // Consonant start - no leading break
    #expect(tts
      .ipa_word("bɪkuːz", "bhikkhus") ==
      "<phoneme alphabet=\"ipa\" ph=\"bɪkuːz\">bhikkhus</phoneme>\(BREAK)")

    // Vowel starts - with leading break
    #expect(tts
      .ipa_word("ɐˈɺɪjɐ", "ariyasacca") ==
      "\(BREAK)<phoneme alphabet=\"ipa\" ph=\"ɐˈɺɪjɐ\">ariyasacca</phoneme>\(BREAK)")
    #expect(tts
      .ipa_word("aɪoʊ", "test") ==
      "\(BREAK)<phoneme alphabet=\"ipa\" ph=\"aɪoʊ\">test</phoneme>\(BREAK)")
    #expect(tts
      .ipa_word("ɛst", "est") ==
      "\(BREAK)<phoneme alphabet=\"ipa\" ph=\"ɛst\">est</phoneme>\(BREAK)")
    #expect(tts
      .ipa_word("ɪnt", "int") ==
      "\(BREAK)<phoneme alphabet=\"ipa\" ph=\"ɪnt\">int</phoneme>\(BREAK)")
    #expect(tts
      .ipa_word("ɔst", "ost") ==
      "\(BREAK)<phoneme alphabet=\"ipa\" ph=\"ɔst\">ost</phoneme>\(BREAK)")
    #expect(tts
      .ipa_word("ʌst", "ust") ==
      "\(BREAK)<phoneme alphabet=\"ipa\" ph=\"ʌst\">ust</phoneme>\(BREAK)")
  }

  @Test
  func customVowels() {
    let tts = AbstractTts(syllableVowels: "aeiouāīū")
    let result = tts.ipa_word("ā", "word")
    let expected = "\(BREAK)<phoneme alphabet=\"ipa\" ph=\"ā\">word</phoneme>\(BREAK)"
    #expect(result == expected)
  }

  @Test
  func paliDetectionWithDiacritics() {
    // Words with Pali diacritics should be detected as Pali
    #expect(Pali.shared.isPali("āriyasacca"))
    #expect(Pali.shared.isPali("bhikkhu"))
    #expect(Pali.shared.isPali("Nibbāna"))
  }

  @Test
  func paliDetectionWithoutDiacritics() {
    // Known Pali words in nonDiacriticalDict should be detected (if length >= 4)
    #expect(Pali.shared.isPali("arahant"))
    #expect(Pali.shared.isPali("bhikkhu"))

    // Short undiacritical words should not be detected as Pali
    #expect(!Pali.shared.isPali("me"))
    #expect(!Pali.shared.isPali("a"))
  }

  @Test
  func englishWordsNotPali() {
    // English words should not be detected as Pali
    #expect(!Pali.shared.isPali("hello"))
    #expect(!Pali.shared.isPali("world"))
    #expect(!Pali.shared.isPali("test"))
  }

  @Test
  func paliDetectionWithPunctuation() {
    // Punctuation should be trimmed before checking
    #expect(Pali.shared.isPali("āriyasacca."))
    #expect(Pali.shared.isPali("arahant,"))
  }

  @Test
  func wordInfoCustomWords() {
    // Migrated from abstract-tts.cjs:149-207
    let customWords: [String: [String: Any]] = [
      "godzilla": ["language": "en"],
      "deutsch": ["language": "de"],
    ]
    let tts = AbstractTts(language: "en", customWords: customWords)

    // Custom words from customWords dict
    #expect(tts.wordInfo("godzilla") == WordInfo(language: "en", ipa: nil))
    #expect(tts.wordInfo("deutsch") == WordInfo(language: "de", ipa: nil))
  }

  @Test
  func wordInfoCustomWordCaseInsensitive() {
    // Case insensitive lookup
    let customWords: [String: [String: Any]] = [
      "godzilla": ["language": "en"],
    ]
    let tts = AbstractTts(language: "en", customWords: customWords)

    #expect(tts.wordInfo("Godzilla") == WordInfo(language: "en", ipa: nil))
    #expect(tts.wordInfo("GODZILLA") == WordInfo(language: "en", ipa: nil))
  }

  @Test
  func wordInfoPaliDetection() {
    // Migrated: Pali words detected by diacritics or nonDiacriticalDict
    let tts = AbstractTts(language: "en")

    // Pali words with diacritics → language "pli"
    #expect(tts.wordInfo("āriyasacca") == WordInfo(language: "pli", ipa: nil))
    #expect(tts.wordInfo("Nibbāna") == WordInfo(language: "pli", ipa: nil))

    // Pali words without diacritics but in nonDiacriticalDict → language "pli"
    #expect(tts.wordInfo("arahant") == WordInfo(language: "pli", ipa: nil))
    #expect(tts.wordInfo("bhikkhu") == WordInfo(language: "pli", ipa: nil))

    // Non-Pali English words → language "en"
    #expect(tts.wordInfo("hello") == WordInfo(language: "en", ipa: nil))
    #expect(tts.wordInfo("identity") == WordInfo(language: "en", ipa: nil))
  }

  @Test
  func wordInfoWithCustomIPA() {
    // Migrated: custom words can override language and provide IPA
    let customWords: [String: [String: Any]] = [
      "bhikkhu": ["language": "pli", "ipa": "bɪkuːz"],
      "occupies": ["language": "en", "ipa": "ɒkʊpaɪz"],
    ]
    let tts = AbstractTts(language: "en", customWords: customWords)

    // Custom word with IPA override
    #expect(tts.wordInfo("occupies") == WordInfo(language: "en", ipa: "ɒkʊpaɪz"))

    // Pali word with custom IPA override
    #expect(tts.wordInfo("bhikkhu") == WordInfo(language: "pli", ipa: "bɪkuːz"))
  }

  @Test
  func wordInfoAlwaysReturnsValue() {
    // wordInfo() returns WordInfo for any word (never nil in our implementation)
    let tts = AbstractTts(language: "en")

    // Even unknown words get the instance language
    let info = tts.wordInfo("xyzunknownword")
    #expect(info != nil)
    #expect(info?.language == "en")
    #expect(info?.ipa == nil)
  }
}
