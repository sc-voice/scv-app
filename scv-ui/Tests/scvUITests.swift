import Testing
@testable import scvUI
@testable import scvCore

@Suite
struct scvUITests {
  @Test
  func placeholder() {
    #expect(true)
  }

  @Test
  func testSuttaPlayerUpdatesCurrentScidWhenPlayingSegment() async {
    // Create a mock MLDocument with segments
    if let mockResponse = SearchResponse.createMockResponse(),
       var mlDoc = mockResponse.mlDocs.first {
      let player = SuttaPlayer.shared
      let segments = mlDoc.segments()

      // Load the document
      player.load(mlDoc)

      // Play first segment
      player.play()

      // Give AVSpeechSynthesizer time to start
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

      // Verify currentScid matches first segment
      let firstSegmentScid = segments[0].key
      #expect(player.currentSutta?.currentScid == firstSegmentScid)
    }
  }
}
