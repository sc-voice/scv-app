import Foundation

/// Word language and pronunciation information
struct WordInfo: Sendable, Equatable {
  /// Language code ("pli" for Pali words, or target language code)
  let language: String
  /// Optional custom IPA pronunciation override from customWords
  let ipa: String?
}

/// SSML generation for text-to-speech synthesis
/// Migrated from
/// https://github.com/sc-voice/api_sc-voice_net/blob/main/src/abstract-tts.cjs
final class AbstractTts {
  // MARK: - Properties

  let language: String
  let localeIPA: String
  let breaks: [Double]
  let customWords: [String: [String: Any]]?

  private let reVowels1: NSRegularExpression
  private let paliDiacritics: CharacterSet

  // MARK: - Initialization

  init(
    language: String = "en",
    localeIPA: String? = nil,
    breaks: [Double]? = nil,
    syllableVowels: String? = nil,
    customWords: [String: [String: Any]]? = nil,
  ) {
    self.language = language
    self.localeIPA = localeIPA ?? language
    self.breaks = breaks ?? [0.001, 0.1, 0.2, 0.6, 1]
    self.customWords = customWords
    paliDiacritics = CharacterSet(
      charactersIn: "āīūḍḷṁṅṇṭñĀĪŪḌḶṀṄṆṬÑ",
    )

    let vowels = syllableVowels ?? "aeioujɐɛɪɔʌ"
    reVowels1 = try! NSRegularExpression(
      pattern: "^[\(NSRegularExpression.escapedPattern(for: vowels))].*",
      options: [.useUnicodeWordBoundaries],
    )
  }

  // MARK: - Break Methods

  /// Returns SSML break tag for given index in breaks array
  func `break`(_ index: Int) -> String {
    let adjustedIndex = index < breaks.count ? index : breaks.count - 1
    let time = breaks[adjustedIndex]
    let timeStr = String(time).replacingOccurrences(
      of: "0+$",
      with: "",
      options: .regularExpression,
    ).replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    return "<break time=\"\(timeStr)s\"/>"
  }

  /// Returns longest SSML break (section break)
  func sectionBreak() -> String {
    `break`(breaks.count - 1)
  }

  // MARK: - IPA Methods

  /// Generate SSML phoneme element for IPA pronunciation
  /// - Parameters:
  ///   - ipa: IPA string (e.g., "ɐˈɺɪjɐ")
  ///   - word: Original word to display (e.g., "ariyasacca")
  /// - Returns: SSML with optional leading break if IPA starts with vowel
  func ipa_word(_ ipa: String, _ word: String) -> String {
    let shortBreak = `break`(0)
    let phoneme = "<phoneme alphabet=\"ipa\" ph=\"\(ipa)\">\(word)</phoneme>\(shortBreak)"

    // If IPA starts with vowel, add break before phoneme
    let range = NSRange(ipa.startIndex ..< ipa.endIndex, in: ipa)
    if reVowels1.firstMatch(in: ipa, range: range) != nil {
      return shortBreak + phoneme
    }

    return phoneme
  }

  // MARK: - Word Info Methods

  /// Returns language and optional custom IPA for a word
  /// - Parameter word: Word to look up
  /// - Returns: WordInfo with language and optional IPA from customWords, or
  /// nil for unknown words
  func wordInfo(_ word: String) -> WordInfo? {
    let lowerWord = word.lowercased()

    // Check customWords first (highest priority)
    if let customWords {
      if let wordData = customWords[lowerWord] as [String: Any]? {
        let lang = wordData["language"] as? String ?? language
        let ipa = wordData["ipa"] as? String
        return WordInfo(language: lang, ipa: ipa)
      }
    }

    // Determine language: "pli" if word is Pali, else use instance language
    let lang = Pali.shared.isPali(word) ? "pli" : language
    return WordInfo(language: lang, ipa: nil)
  }
}
