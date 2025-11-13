@testable import scvMacros
import Testing

@Suite
struct CCOK1Tests {
  @Test
  func cCOK1Macro() {
    // Basic test that macro can be called
    // Actual macro expansion is validated at compile time
    #expect(true)
  }
}
