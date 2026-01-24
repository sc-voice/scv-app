import Testing
import Foundation
@testable import scvTasks

struct ReferenceTests {
  @Test
  func testFilePathReference() {
    let ref = Reference.filePath("doc/example.md")
    guard case .filePath(let path) = ref else {
      #expect(Bool(false), "Expected filePath")
      return
    }
    #expect(path == "doc/example.md")
  }

  @Test
  func testTextReference() {
    let ref = Reference.text("This is a note")
    guard case .text(let text) = ref else {
      #expect(Bool(false), "Expected text")
      return
    }
    #expect(text == "This is a note")
  }

  @Test
  func testReferenceCodable() throws {
    let fileRef = Reference.filePath("doc/test.md")
    let encoder = JSONEncoder()
    let data = try encoder.encode(fileRef)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Reference.self, from: data)
    guard case .filePath(let path) = decoded else {
      #expect(Bool(false), "Expected filePath")
      return
    }
    #expect(path == "doc/test.md")
  }
}
