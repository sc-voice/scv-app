import Foundation
import Testing

@testable import scvCore

struct ColorConsoleTests {
  @Test
  func ok1SingleMessage() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.ok1("test", #function)
    #expect(result?.contains("✅") == true)
    #expect(result?.contains("test " + #function) == true)
  }

  @Test
  func ok1MultipleMessages() {
    let cc = ColorConsole(#file, #function)
    let result = cc.ok1("test", #function)
    #expect(result?.contains("✅") == true)
    #expect(result?.contains("test " + #function) == true)
  }

  @Test
  func bad1SingleMessage() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.bad1("test", #function)
    #expect(result?.contains("❌") == true)
    #expect(result?.contains("test " + #function) == true)
  }

  @Test
  func bad1MultipleMessages() {
    let cc = ColorConsole(#file, #function)
    let result = cc.bad1("test", #function)
    #expect(result?.contains("❌") == true)
    #expect(result?.contains("test " + #function) == true)
  }

  @Test
  func ok1WithInterpolation() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.ok1("test", #function)
    #expect(result?.contains("✅") == true)
    #expect(result?.contains("test " + #function) == true)
  }

  @Test
  func bad1WithInterpolation() {
    let cc = ColorConsole(#file, #function)
    let result = cc.bad1("test", #function)
    #expect(result?.contains("❌") == true)
    #expect(result?.contains("test " + #function) == true)
  }

  @Test
  func colorStringMultipleMessages() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.formatString(["Hello", "World"])
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
    #expect(result?.contains("🍀") == true)
    #expect(result?.contains("Verbose message") == true)
  }

  @Test
  func ok2MultipleMessagesAtVerbosity2() {
    let cc = ColorConsole(#file, #function, 2)
    let result = cc.ok2("All", #function)
    #expect(result?.contains("🍀") == true)
    #expect(result?.contains("All " + #function) == true)
  }

  @Test
  func bad2NotDisplayedAtVerbosity1() {
    let cc = ColorConsole(#file, #function, 1)
    let result = cc.bad2("Verbose", #function)
    #expect(result == nil)
  }

  @Test
  func bad2DisplayedAtVerbosity2() {
    let cc = ColorConsole(#file, #function, 2)
    let result = cc.bad2("Verbose", #function)
    #expect(result?.contains("🌶️") == true)
    #expect(result?.contains("Verbose " + #function) == true)
  }

  @Test
  func bad2MultipleMessagesAtVerbosity2() {
    let cc = ColorConsole(#file, #function, 2)
    let msg = "bad2MultipleMessagesAtVerbosity2"
    let result = cc.bad2(msg)
    #expect(result?.contains("🌶️") == true)
    #expect(result?.contains(msg) == true)
  }
}
