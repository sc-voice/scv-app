import Foundation
import Testing

@testable import scvCore

struct ColorConsoleTests {
  @Test
  func ok1SingleMessage() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.ok1("Success!")
    #expect(result?.contains("✅") == true)
    #expect(result?.contains("Success!") == true)
  }

  @Test
  func ok1MultipleMessages() {
    let cc = ColorConsole(#file, #function)
    let result = cc.ok1("All", "tests", "passed")
    #expect(result?.contains("✅") == true)
    #expect(result?.contains("All tests passed") == true)
  }

  @Test
  func bad1SingleMessage() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.bad1("Error!")
    #expect(result?.contains("❌") == true)
    #expect(result?.contains("Error!") == true)
  }

  @Test
  func bad1MultipleMessages() {
    let cc = ColorConsole(#file, #function)
    let result = cc.bad1("Test", "failed", "badly")
    #expect(result?.contains("❌") == true)
    #expect(result?.contains("Test failed badly") == true)
  }

  @Test
  func ok1WithInterpolation() {
    let cc = ColorConsole(#file, #function, 1)
    let count = 5
    let result = cc.ok1("Processed", count, "items")
    #expect(result?.contains("✅") == true)
    #expect(result?.contains("Processed 5 items") == true)
  }

  @Test
  func bad1WithInterpolation() {
    let cc = ColorConsole(#file, #function)
    let error = "File not found"
    let result = cc.bad1("Failed:", error)
    #expect(result?.contains("❌") == true)
    #expect(result?.contains("Failed: File not found") == true)
  }

  @Test
  func colorStringWithBrightGreen() {
    let cc = ColorConsole(#file, #function)
    let result = cc.colorString("\u{001B}[92m", "Success")
    #expect(result.contains("\u{001B}[92m"))
    #expect(result.contains("Success"))
  }

  @Test
  func colorStringWithBrightRed() {
    let cc = ColorConsole(#file, #function)
    let result = cc.colorString("\u{001B}[91m", "Error")
    #expect(result.contains("\u{001B}[91m"))
    #expect(result.contains("Error"))
  }

  @Test
  func colorStringMultipleMessages() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.colorString("\u{001B}[92m", "Hello", "World")
    #expect(result.contains("\u{001B}[92m"))
    #expect(result.contains("Hello World"))
  }

  @Test
  func ok2NotDisplayedAtVerbosity1() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.ok2("Verbose message")
    #expect(result == nil)
  }

  @Test
  func ok2DisplayedAtVerbosity2() {
    let cc = ColorConsole(#file, #function, 2)
    let result = cc.ok2("Verbose message")
    #expect(result?.contains("🌱") == true)
    #expect(result?.contains("Verbose message") == true)
  }

  @Test
  func ok2MultipleMessagesAtVerbosity2() {
    let cc = ColorConsole(#file, #function, 2)
    let result = cc.ok2("All", "tests", "passed")
    #expect(result?.contains("🌱") == true)
    #expect(result?.contains("All tests passed") == true)
  }

  @Test
  func bad2NotDisplayedAtVerbosity1() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.bad2("Verbose error")
    #expect(result == nil)
  }

  @Test
  func bad2DisplayedAtVerbosity2() {
    let cc = ColorConsole(#file, #function, 2)
    let result = cc.bad2("Verbose error")
    #expect(result?.contains("🌶️") == true)
    #expect(result?.contains("Verbose error") == true)
  }

  @Test
  func bad2MultipleMessagesAtVerbosity2() {
    let cc = ColorConsole(#file, #function, 2)
    let result = cc.bad2("Test", "failed", "badly")
    #expect(result?.contains("🌶️") == true)
    #expect(result?.contains("Test failed badly") == true)
  }
}
