import XCTest
import NaturalLanguage

/// Tests for NLTokenizer German tokenization
final class TokenizerTests: XCTestCase {

    func testGermanTokenization() throws {
        let text = "abhängig entstehen"
        let tokens = tokenize(text)

        XCTAssertEqual(tokens, ["abhängig", "entstehen"])
    }

    // MARK: - Helper Methods

    // NLTokenizer is pre CoreML and .word is too coarse a unit for DE
    // if we want to search by sub-word tokens
    private func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(.german)
        tokenizer.string = text

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            tokens.append(String(text[tokenRange]))
            return true
        }

        return tokens
    }
}
