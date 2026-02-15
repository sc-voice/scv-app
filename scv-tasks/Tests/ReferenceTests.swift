import Foundation
@testable import scvTasks
import Testing
import UUIDV7

struct ReferenceTests {
  @Test
  func referenceWithText() {
    let ref = Reference(text: "This is a note")
    #expect(ref.text == "This is a note")
    #expect(ref.url == nil)
    #expect(ref.relevance == 0.5)
  }

  @Test
  func referenceWithURL() {
    let url = URL(string: "https://example.com/doc")!
    let ref = Reference(url: url)
    #expect(ref.text == nil)
    #expect(ref.url == url)
    #expect(ref.relevance == 0.5)
  }

  @Test
  func referenceWithTextAndURL() {
    let url = URL(string: "https://example.com")!
    let ref = Reference(text: "Link to example", url: url, relevance: 0.8)
    #expect(ref.text == "Link to example")
    #expect(ref.url == url)
    #expect(ref.relevance == 0.8)
  }

  @Test
  func referenceRelevanceClamping() {
    let refTooHigh = Reference(relevance: 1.5)
    #expect(refTooHigh.relevance == 1.0)

    let refTooLow = Reference(relevance: -0.5)
    #expect(refTooLow.relevance == 0.0)

    let refValid = Reference(relevance: 0.75)
    #expect(refValid.relevance == 0.75)
  }

  @Test
  func referenceDefaultRelevance() {
    let ref = Reference()
    #expect(ref.relevance == 0.5)
  }

  @Test
  func referenceCodable() throws {
    let url = URL(string: "https://example.com/ref")!
    let ref = Reference(text: "Example", url: url, relevance: 0.7)

    let encoder = JSONEncoder()
    let data = try encoder.encode(ref)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Reference.self, from: data)
    #expect(decoded.text == "Example")
    #expect(decoded.url == url)
    #expect(decoded.relevance == 0.7)
  }

  @Test
  func referenceIdentifiable() {
    let ref = Reference(text: "Test")
    #expect(!ref.id.isEmpty)
    #expect(ref.id.count == 4) // First 4 chars of MD5 hash
  }
}
