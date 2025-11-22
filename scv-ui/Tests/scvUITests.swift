import Foundation
@testable import scvCore
@testable import scvUI
import Testing

@Suite
struct scvUITests {
  let cc = ColorConsole(#file, #function, dbg.scvUITests.other)

  @Test
  func searchSuttasIntentInitializesWithQuery() {
    let intent = SearchSuttasIntent(query: "root of suffering")
    #expect(intent.query == "root of suffering")
    cc.ok1(#line, "passed")
  }

  @Test
  func searchSuttasIntentInitializesWithEmptyQuery() {
    let intent = SearchSuttasIntent()
    #expect(intent.query == nil)
    cc.ok1(#line, "passed")
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
    cc.ok1(#line, "passed")
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
    cc.ok1(#line, "passed")
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
    cc.ok1(#line, "passed")
  }

  // TODO: Test SuttaPlayer speech synthesis (see backlog)
  // @Test
  // @MainActor
  // func suttaPlayerUpdatesCurrentScidWhenPlayingSegment() async {
  //   // Create a mock MLDocument with segments
  //   if let mockResponse = SearchResponse.createMockResponse(),
  //      let mlDoc = mockResponse.mlDocs.first
  //   {
  //     let mockSynthesizer = MockSpeechSynthesizer()
  //     let player = SuttaPlayer(synthesizer: mockSynthesizer)
  //     mockSynthesizer.mockDelegate = player
  //     let segments = mlDoc.segments()
  //
  //     // Load the document
  //     player.load(mlDoc)
  //
  //     // Play first segment
  //     player.play()
  //
  //     // Verify speak was called and currentScid is set
  //     #expect(mockSynthesizer.speakWasCalled == true)
  //     let firstSegmentScid = segments[0].key
  //     let currentScid = player.currentSutta?.currentScid
  //     #expect(currentScid == firstSegmentScid)
  //   }
  // }

  // TODO: Test SuttaPlayer jump to segment (see backlog)
  // @Test
  // @MainActor
  // func suttaPlayerJumpToSegmentWhilePlaying() async {
  //   // Create a mock MLDocument with segments
  //   if let mockResponse = SearchResponse.createMockResponse(),
  //      let mlDoc = mockResponse.mlDocs.first
  //   {
  //     let mockSynthesizer = MockSpeechSynthesizer()
  //     let player = SuttaPlayer(synthesizer: mockSynthesizer)
  //     mockSynthesizer.mockDelegate = player
  //     let segments = mlDoc.segments()
  //
  //     // Load the document
  //     player.load(mlDoc)
  //
  //     // Start playing segment 0
  //     player.play()
  //
  //     // Verify playing segment 0
  //     let currentScid0 = player.currentSutta?.currentScid
  //     #expect(currentScid0 == segments[0].key)
  //
  //     // User jumps to segment 3 while segment 0 is still playing
  //     // With correct fix: jumpToSegment sets nextIndexToPlay = 3 (without
  //     // calling playSegmentAt)
  //     player.jumpToSegment(scid: segments[3].key)
  //
  //     // Simulate segment 0's didFinish callback (stale callback from before
  //     /the
  //     // jump)
  //     // It should play nextIndexToPlay, which should be 3 (not 4)
  //     let staleUtterance = AVSpeechUtterance(string: "test")
  //     player.speechSynthesizer(player.synthesizer, didFinish: staleUtterance)
  //
  //     // Give async task time to complete
  //     try? await Task.sleep(for: .milliseconds(10))
  //
  //     // Verify currentScid is segment 3 (not segment 4)
  //     // If jumpToSegment called playSegmentAt(3) instead of just setting
  //     // nextIndexToPlay = 3,
  //     // then nextIndexToPlay would be 4, and this test would fail
  //     let currentScid3 = player.currentSutta?.currentScid
  //     #expect(currentScid3 == segments[3].key)
  //   }
  // }

  // TODO: AppController tests need MockURLOpener (see backlog)
  // Tests commented out because MockURLOpener causes hangs
  /*
   @Test
   @MainActor
   func appControllerSearchByUrlConstructsValidURL() {
     let mockOpener = MockURLOpener()
     let controller = AppController(urlOpener: mockOpener)

     controller.searchByUrl(query: "dhamma")

     #expect(mockOpener.lastURL != nil)
     #expect(mockOpener.lastURL?.scheme == "sc-voice")
     #expect(mockOpener.lastURL?.host == "search")
     cc.ok1(#line, "passed")
   }

   @Test
   @MainActor
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
     cc.ok1(#line, "passed")
   }

   @Test
   @MainActor
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
     cc.ok1(#line, "passed")
   }

   @Test
   @MainActor
   func appControllerSearchByUrlCallsURLOpener() {
     let mockOpener = MockURLOpener()
     let controller = AppController(urlOpener: mockOpener)

     #expect(mockOpener.openWasCalled == false)
     controller.searchByUrl(query: "test")
     #expect(mockOpener.openWasCalled == true)
     cc.ok1(#line, "passed")
   }
   */

  @Test
  @MainActor
  func appControllerExtractSearchQueryFromValidURL() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search?q=dhamma")!

    let query = controller.extractSearchQuery(from: url)

    #expect(query == "dhamma")
    cc.ok1(#line, "passed")
  }

  @Test
  @MainActor
  func appControllerExtractSearchQueryFromURLWithoutParam() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search")!

    let query = controller.extractSearchQuery(from: url)

    #expect(query == nil)
    cc.ok1(#line, "passed")
  }

  @Test
  @MainActor
  func appControllerExtractSearchQueryWithEncodedCharacters() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search?q=hello%20world")!

    let query = controller.extractSearchQuery(from: url)

    #expect(query == "hello world")
    cc.ok1(#line, "passed")
  }

  @Test
  @MainActor
  func appControllerHandleSearchUrlWithValidURL() {
    let controller = AppController()
    let url = URL(string: "sc-voice://search?q=dukkha")!

    // Should not crash or throw
    controller.handleSearchUrl(url: url)
    cc.ok1(#line, "passed")
  }

  /* TEST HANGS:
   @Test
   @MainActor
   func appControllerHandleSearchUrlWithMissingParam() {
     let controller = AppController()
     let url = URL(string: "sc-voice://search")!

     // Should not crash, shows error (can't verify alert in test)
     controller.handleSearchUrl(url: url)
     cc.ok1(#line, "passed")
   }
   */

  // MARK: - SearchCardView Tests

  @Test
  func searchCardViewUpdatesSearchQueryBinding() {
    let card = Card(
      cardType: .search,
      typeId: 1,
      searchQuery: "initial",
    )

    let initialQuery = card.searchQuery
    #expect(initialQuery == "initial")

    // Simulate user editing searchQuery
    card.searchQuery = "updated query"
    #expect(card.searchQuery == "updated query")
    cc.ok1(#line, "passed")
  }

  @Test
  func searchCardViewRendersWithEmptyQuery() {
    let card = Card(
      cardType: .search,
      typeId: 2,
      searchQuery: "",
    )

    #expect(card.searchQuery.isEmpty)
    #expect(card.cardType == .search)
    cc.ok1(#line, "passed")
  }

  @Test
  func searchCardViewRendersWithExistingQuery() {
    let card = Card(
      cardType: .search,
      typeId: 3,
      searchQuery: "mindfulness",
    )

    #expect(card.searchQuery == "mindfulness")
    #expect(!card.searchQuery.isEmpty)
    cc.ok1(#line, "passed")
  }

  @Test
  func searchCardViewFiltersValidCharacters() {
    let validInput = "mindfulness 123"
    let filtered = SearchQueryFilter.filter(validInput)
    #expect(filtered == "mindfulness 123")
    cc.ok1(#line, "passed")
  }

  @Test
  func searchCardViewFiltersInvalidCharacters() {
    let invalidInput = "  !!!hello@world#test!!!  "
    let filtered = SearchQueryFilter.filter(invalidInput)
    #expect(filtered == " ?hello?world?test? ")
    cc.ok1(#line, "passed")
  }

  @Test
  func searchCardViewFiltersUppercaseToLowercase() {
    let input = "MINDFULNESS"
    let filtered = SearchQueryFilter.filter(input)
    #expect(filtered == "mindfulness")
    cc.ok1(#line, "passed")
  }

  @Test
  func searchCardViewAcceptsDots() {
    let input = "AN.3.31"
    let filtered = SearchQueryFilter.filter(input)
    #expect(filtered == "an.3.31")
    cc.ok1(#line, "passed")
  }

  @Test
  func searchCardViewAcceptsColons() {
    let input = "hello:world"
    let filtered = SearchQueryFilter.filter(input)
    #expect(filtered == "hello:world")
    cc.ok1(#line, "passed")
  }
}

// MARK: - Mock URLOpener for Testing

@MainActor
class MockURLOpener: URLOpener {
  nonisolated(unsafe) var lastURL: URL?
  nonisolated(unsafe) var openWasCalled = false

  nonisolated func open(
    _ url: URL,
    completion: @escaping @MainActor (Bool) -> Void,
  ) {
    lastURL = url
    openWasCalled = true
    Task { @MainActor in completion(true) }
  }
}
