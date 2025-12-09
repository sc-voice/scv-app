import XCTest
import NaturalLanguage
import Foundation

/// Tests for NLContextualEmbedding DE BERT embeddings
final class EmbeddingTests: XCTestCase {

    func testDEContextualEmbedding() throws {
        // Create contextual embedding for DE
        guard let embedding = NLContextualEmbedding(language: .german) else {
            throw XCTSkip("NLContextualEmbedding not available for DE")
        }

        // Load the model
        let loadStart = Date()
        try embedding.load()
        let loadTime = Date().timeIntervalSince(loadStart)
        print("Model load time: \(String(format: "%.3f", loadTime))s")

        let text = "abhängig entstehen"

        // Get embedding result
        let embedStart = Date()
        guard let result = try? embedding.embeddingResult(for: text, language: .german) else {
            throw XCTSkip("Could not generate embeddings for DE text")
        }
        let embedTime = Date().timeIntervalSince(embedStart)
        print("Embedding generation: \(String(format: "%.3f", embedTime))s")

        // Collect actual vectors
        var actualVectors: [[Double]] = []
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, tokenRange in
            actualVectors.append(Array(vector))
            return true
        }

        // Path to fixtures file
        let fixturesPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("de-embeddings.json")

        if FileManager.default.fileExists(atPath: fixturesPath.path) {
            // Load and compare
            let data = try Data(contentsOf: fixturesPath)
            let expectedVectors = try JSONDecoder().decode([[Double]].self, from: data)

            XCTAssertEqual(actualVectors.count, expectedVectors.count)
            XCTAssertEqual(actualVectors, expectedVectors, "Embeddings should match saved fixtures")
            print("✓ Embeddings match saved fixtures")
        } else {
            // Save fixtures
            let data = try JSONEncoder().encode(actualVectors)
            try data.write(to: fixturesPath)
            print("✓ Saved embeddings to \(fixturesPath.lastPathComponent)")
        }
    }
}
