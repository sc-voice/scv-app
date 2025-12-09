import Foundation
import NaturalLanguage
import XCTest

@testable import scvCore

/// Tests for NLContextualEmbedding DE BERT embeddings
final class EmbeddingTests: XCTestCase {
  /// Data structure for serializing MLDocument with segment embeddings
  struct MLDocumentEmbeddingData: Codable {
    let mlDocument: MLDocument
    let segmentEmbeddings: [String: [Double]]
  }

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
    guard let result = try? embedding.embeddingResult(
      for: text,
      language: .german,
    ) else {
      throw XCTSkip("Could not generate embeddings for DE text")
    }
    let embedTime = Date().timeIntervalSince(embedStart)
    print("Embedding generation: \(String(format: "%.3f", embedTime))s")

    // Collect actual vectors
    var actualVectors: [[Double]] = []
    result
      .enumerateTokenVectors(in: text.startIndex ..< text
        .endIndex)
      { vector, _ in
        actualVectors.append(Array(vector))
        return true
      }

    // Path to fixtures file
    let fixturesPath = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("de-embeddings.json")

    if FileManager.default.fileExists(atPath: fixturesPath.path) {
      // Load and compare
      let data = try Data(contentsOf: fixturesPath)
      let expectedVectors = try JSONDecoder().decode(
        [[Double]].self,
        from: data,
      )

      XCTAssertEqual(actualVectors.count, expectedVectors.count)
      XCTAssertEqual(
        actualVectors,
        expectedVectors,
        "Embeddings should match saved fixtures",
      )
      print("✓ Embeddings match saved fixtures")
    } else {
      // Save fixtures
      let data = try JSONEncoder().encode(actualVectors)
      try data.write(to: fixturesPath)
      print("✓ Saved embeddings to \(fixturesPath.lastPathComponent)")
    }
  }

  func testDESn1220Embeddings() async throws {
    // Load sn12.20 in German (de/sabbamitta)
    guard let suttaRef = SuttaRef.create("sn12.20/de/sabbamitta") else {
      XCTFail("Failed to create SuttaRef for sn12.20/de/sabbamitta")
      return
    }

    let mlDoc = await EbtData.shared.getMLDocument(suttaRef: suttaRef)
    guard let mlDoc else {
      XCTFail("Failed to load MLDocument for sn12.20/de/sabbamitta")
      return
    }

    print(
      "✓ Loaded MLDocument: \(mlDoc.sutta_uid) with \(mlDoc.segMap.count) segments",
    )

    // Create German contextual embedding
    guard let embedding = NLContextualEmbedding(language: .german) else {
      throw XCTSkip("NLContextualEmbedding not available for German")
    }

    let loadStart = Date()
    try embedding.load()
    let loadTime = Date().timeIntervalSince(loadStart)
    print("✓ Model loaded in \(String(format: "%.3f", loadTime))s")

    // Generate embeddings for each segment
    var segmentEmbeddings: [String: [Double]] = [:]
    var processedCount = 0
    var skippedCount = 0

    for (scid, segment) in mlDoc.segMap {
      // Skip empty segments
      guard let germanText = segment.doc, !germanText.isEmpty else {
        skippedCount += 1
        continue
      }

      // Generate embedding for this segment
      guard let result = try? embedding.embeddingResult(
        for: germanText,
        language: .german,
      ) else {
        print("⚠ Could not generate embedding for segment \(scid)")
        skippedCount += 1
        continue
      }

      // Collect token vectors
      var tokenVectors: [[Double]] = []
      result
        .enumerateTokenVectors(in: germanText.startIndex ..< germanText
          .endIndex)
        { vector, _ in
          tokenVectors.append(Array(vector))
          return true
        }

      // Average the token vectors to get single segment vector
      let avgVector = averageVectors(tokenVectors)
      segmentEmbeddings[scid] = avgVector

      processedCount += 1

      // Progress indicator
      if processedCount % 50 == 0 {
        print("✓ Processed \(processedCount) segments...")
      }
    }

    print(
      "✓ Processed \(processedCount) segments, skipped \(skippedCount) empty segments",
    )

    // Create data structure with MLDocument and embeddings
    let embeddingData = MLDocumentEmbeddingData(
      mlDocument: mlDoc,
      segmentEmbeddings: segmentEmbeddings,
    )

    // Path to fixtures file
    let fixturesPath = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("sn12.20-de-embeddings.json")

    if FileManager.default.fileExists(atPath: fixturesPath.path) {
      // File exists - validate against it
      let data = try Data(contentsOf: fixturesPath)
      let expectedData = try JSONDecoder().decode(
        MLDocumentEmbeddingData.self,
        from: data,
      )

      XCTAssertEqual(
        embeddingData.mlDocument.sutta_uid,
        expectedData.mlDocument.sutta_uid,
        "Sutta UID should match",
      )
      XCTAssertEqual(
        embeddingData.segmentEmbeddings.count,
        expectedData.segmentEmbeddings.count,
        "Number of embeddings should match",
      )

      print("✓ Embeddings match saved fixtures")
    } else {
      // File doesn't exist - save it
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let jsonData = try encoder.encode(embeddingData)
      try jsonData.write(to: fixturesPath)
      print("✓ Saved embeddings to \(fixturesPath.lastPathComponent)")
      print("  Sutta: \(embeddingData.mlDocument.sutta_uid)")
      print(
        "  Segments with embeddings: \(embeddingData.segmentEmbeddings.count)",
      )
      print("  Vector dimensions: 512 (BERT)")
    }
  }

  /// Averages multiple vectors into a single vector
  private func averageVectors(_ vectors: [[Double]]) -> [Double] {
    guard !vectors.isEmpty else { return [] }

    let vectorCount = vectors.count
    let dimensions = vectors[0].count

    var averaged = [Double](repeating: 0.0, count: dimensions)

    for vector in vectors {
      for (i, value) in vector.enumerated() {
        if i < dimensions {
          averaged[i] += value
        }
      }
    }

    for i in 0 ..< dimensions {
      averaged[i] /= Double(vectorCount)
    }

    return averaged
  }
}
