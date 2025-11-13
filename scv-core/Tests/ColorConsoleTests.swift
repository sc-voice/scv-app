import Foundation
import Testing

@testable import scvCore

struct ColorConsoleTests {
  @Test
  func ok1SingleMessage() {
    let result = cc.ok1("Success!")
    #expect(result.contains("\u{001B}[92m"))
    #expect(result.contains("Success!"))
    #expect(result.contains("\u{001B}[0m"))
  }

  @Test
  func ok1MultipleMessages() {
    let result = cc.ok1("All", "tests", "passed")
    #expect(result.contains("\u{001B}[92m"))
    #expect(result.contains("All tests passed"))
    #expect(result.contains("\u{001B}[0m"))
  }

  @Test
  func bad1SingleMessage() {
    let result = cc.bad1("Error!")
    #expect(result.contains("\u{001B}[91m"))
    #expect(result.contains("Error!"))
    #expect(result.contains("\u{001B}[0m"))
  }

  @Test
  func bad1MultipleMessages() {
    let result = cc.bad1("Test", "failed", "badly")
    #expect(result.contains("\u{001B}[91m"))
    #expect(result.contains("Test failed badly"))
    #expect(result.contains("\u{001B}[0m"))
  }

  @Test
  func ok1WithInterpolation() {
    let count = 5
    let result = cc.ok1("Processed", count, "items")
    #expect(result.contains("\u{001B}[92m"))
    #expect(result.contains("Processed 5 items"))
    #expect(result.contains("\u{001B}[0m"))
  }

  @Test
  func bad1WithInterpolation() {
    let error = "File not found"
    let result = cc.bad1("Failed:", error)
    #expect(result.contains("\u{001B}[91m"))
    #expect(result.contains("Failed: File not found"))
    #expect(result.contains("\u{001B}[0m"))
  }

  @Test
  func colorStringWithBrightGreen() {
    let result = cc.colorString("\u{001B}[92m", "Success")
    #expect(result.contains("\u{001B}[92m"))
    #expect(result.contains("Success"))
    #expect(result.contains("\u{001B}[0m"))
  }

  @Test
  func colorStringWithBrightRed() {
    let result = cc.colorString("\u{001B}[91m", "Error")
    #expect(result.contains("\u{001B}[91m"))
    #expect(result.contains("Error"))
    #expect(result.contains("\u{001B}[0m"))
  }

  @Test
  func colorStringMultipleMessages() {
    let result = cc.colorString("\u{001B}[92m", "Hello", "World")
    #expect(result.contains("\u{001B}[92m"))
    #expect(result.contains("Hello World"))
    #expect(result.contains("\u{001B}[0m"))
  }
}
