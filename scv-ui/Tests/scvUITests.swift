@testable import scvCore
@testable import scvUI
import Testing

@Suite
struct scvUITests {
  @Test
  func searchSuttasIntentInitializesWithQuery() {
    let intent = SearchSuttasIntent(query: "root of suffering")
    #expect(intent.query == "root of suffering")
  }

  @Test
  func searchSuttasIntentInitializesWithEmptyQuery() {
    let intent = SearchSuttasIntent()
    #expect(intent.query == "")
  }

  @Test
  func searchIntentRequestContainsData() {
    let request = SearchIntentRequest(
      query: "dukkha",
      language: "en",
      author: "sujato",
    )

    #expect(request.query == "dukkha")
    #expect(request.language == "en")
    #expect(request.author == "sujato")
  }

  @Test
  func searchIntentRequestIsEncodable() throws {
    let original = SearchIntentRequest(
      query: "anatta",
      language: "en",
      author: "sujato",
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    #expect(data.count > 0)
  }

  @Test
  func searchIntentRequestIsDecodable() throws {
    let original = SearchIntentRequest(
      query: "anatta",
      language: "en",
      author: "sujato",
    )

    let encoder = JSONEncoder()
    let encoded = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SearchIntentRequest.self, from: encoded)

    #expect(decoded.query == original.query)
    #expect(decoded.language == original.language)
    #expect(decoded.author == original.author)
  }

  @Test
  func suttaPlayerUpdatesCurrentScidWhenPlayingSegment() async {
    // Create a mock MLDocument with segments
    if let mockResponse = SearchResponse.createMockResponse(),
       var mlDoc = mockResponse.mlDocs.first
    {
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

  @Test
  func suttaPlayerJumpToSegmentWhilePlaying() async {
    // Create a mock MLDocument with segments
    if let mockResponse = SearchResponse.createMockResponse(),
       let mlDoc = mockResponse.mlDocs.first
    {
      let player = SuttaPlayer.shared
      let segments = mlDoc.segments()

      // Load the document
      player.load(mlDoc)

      // Start playing segment 0
      player.play()

      // Give synthesizer time to start
      try? await Task.sleep(nanoseconds: 100_000_000)

      // Verify playing segment 0
      #expect(player.currentSutta?.currentScid == segments[0].key)

      // User jumps to segment 3 while segment 0 is still playing
      // With correct fix: jumpToSegment sets nextIndexToPlay = 3 (without
      // calling playSegmentAt)
      player.jumpToSegment(scid: segments[3].key)

      // Simulate segment 0's didFinish callback (stale callback from before the
      // jump)
      // It should play nextIndexToPlay, which should be 3 (not 4)
      let staleUtterance = AVSpeechUtterance(string: "test")
      player.speechSynthesizer(player.synthesizer, didFinish: staleUtterance)

      // Give async task time to complete
      try? await Task.sleep(nanoseconds: 100_000_000)

      // Verify currentScid is segment 3 (not segment 4)
      // If jumpToSegment called playSegmentAt(3) instead of just setting
      // nextIndexToPlay = 3,
      // then nextIndexToPlay would be 4, and this test would fail
      #expect(player.currentSutta?.currentScid == segments[3].key)
    }
  }

  // MARK: - AppController Tests

  @Test
  func appControllerSearchByUrlConstructsValidURL() {
    let mockOpener = MockURLOpener()
    let controller = AppController(urlOpener: mockOpener)

    controller.searchByUrl(query: "dhamma")

    #expect(mockOpener.lastURL != nil)
    #expect(mockOpener.lastURL?.scheme == "sc-voice")
    #expect(mockOpener.lastURL?.host == "search")
  }

  @Test
  func appControllerSearchByUrlIncludesQueryParameter() {
    let mockOpener = MockURLOpener()
    let controller = AppController(urlOpener: mockOpener)

    controller.searchByUrl(query: "dukkha")

    guard let components = URLComponents(
      url: mockOpener.lastURL ?? URL(fileURLWithPath: ""),
      resolvingAgainstBaseURL: true,
    ) else {
      #expect(Bool(false), "Failed to parse URL components")
      return
    }

    let queryValue = components.queryItems?.first(where: { $0.name == "q" })?
      .value
    #expect(queryValue == "dukkha")
  }

  @Test
  func appControllerSearchByUrlEncodesSpecialCharacters() {
    let mockOpener = MockURLOpener()
    let controller = AppController(urlOpener: mockOpener)

    controller.searchByUrl(query: "hello world")

    guard let components = URLComponents(
      url: mockOpener.lastURL ?? URL(fileURLWithPath: ""),
      resolvingAgainstBaseURL: true,
    ) else {
      #expect(Bool(false), "Failed to parse URL components")
      return
    }

    let queryValue = components.queryItems?.first(where: { $0.name == "q" })?
      .value
    #expect(queryValue == "hello world")
  }

  @Test
  func appControllerSearchByUrlCallsURLOpener() {
    let mockOpener = MockURLOpener()
    let controller = AppController(urlOpener: mockOpener)

    #expect(mockOpener.openWasCalled == false)
    controller.searchByUrl(query: "test")
    #expect(mockOpener.openWasCalled == true)
  }

  @Test
  func appControllerExtractSearchQueryFromValidURL() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search?q=dhamma")!

    let query = controller.extractSearchQuery(from: url)

    #expect(query == "dhamma")
  }

  @Test
  func appControllerExtractSearchQueryFromURLWithoutParam() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search")!

    let query = controller.extractSearchQuery(from: url)

    #expect(query == nil)
  }

  @Test
  func appControllerExtractSearchQueryWithEncodedCharacters() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search?q=hello%20world")!

    let query = controller.extractSearchQuery(from: url)

    #expect(query == "hello world")
  }

  @Test
  func appControllerHandleSearchUrlWithValidURL() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search?q=dukkha")!

    // Should not crash or throw
    controller.handleSearchUrl(url: url)
  }

  @Test
  func appControllerHandleSearchUrlWithMissingParam() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search")!

    // Should not crash, shows error (can't verify alert in test)
    controller.handleSearchUrl(url: url)
  }
}

// MARK: - Mock URLOpener for Testing

class MockURLOpener: URLOpener {
  var lastURL: URL?
  var openWasCalled = false

  func open(_ url: URL, completion: @escaping @MainActor (Bool) -> Void) {
    lastURL = url
    openWasCalled = true
    completion(true)
  }
}
