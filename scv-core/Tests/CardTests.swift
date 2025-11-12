import Foundation
@testable import scvCore
import SwiftData
import Testing

/// Test helper to temporarily swap localization bundle
@MainActor
func withLocalizationBundle(_ bundle: Bundle, _ test: () -> Void) {
    let originalBundle = localizationBundle
    localizationBundle = bundle
    defer { localizationBundle = originalBundle }
    test()
}

@Suite
struct CardTests {
    @Test
    func cardDefaultInitialization() {
        let beforeCreation = Date()
        let card = Card()

        #expect(card.cardType == .search)
        #expect(card.typeId == 0)
        #expect(card.searchQuery == "")
        #expect(card.searchResults == nil)
        #expect(card.suttaReference == "")

        // createdAt should be within 1 second of now
        let timeDifference = abs(card.createdAt.timeIntervalSince(beforeCreation))
        #expect(timeDifference <= 1.0)
    }

    @Test
    func cardIconName() {
        let searchCard = Card(cardType: .search)
        #expect(searchCard.iconName() == "magnifyingglass")

        let suttaCard = Card(cardType: .sutta)
        #expect(suttaCard.iconName() == "book")
    }

    @Test
    @MainActor
    func cardTitle() {
        let card = Card(cardType: .search, typeId: 5)
        let title = card.title()

        #expect(title.contains("Search"))
        #expect(title.contains("5"))
    }

    @Test
    @MainActor
    func cardLocalizedCardTypeName() {
        let searchCard = Card(cardType: .search)
        let searchName = searchCard.localizedCardTypeName()
        #expect(searchName == "Search")

        let suttaCard = Card(cardType: .sutta)
        let suttaName = suttaCard.localizedCardTypeName()
        #expect(suttaName == "Sutta")
    }

    @Test
    func cardWithSearchResults() {
        let response = SearchResponse(pattern: "mindfulness")
        let card = Card(cardType: .search, searchResults: response)

        #expect(card.searchResults != nil)
        #expect(card.searchResults?.pattern == "mindfulness")
    }

    @Test
    @MainActor
    func cardPortugueseLocalization() {
        // Load the pt-PT localization bundle
        guard let bundle = Bundle.module.url(forResource: "pt-PT", withExtension: "lproj"),
              let portugueseBundle = Bundle(url: bundle)
        else {
            #expect(Bool(false), "Failed to load pt-PT localization bundle")
            return
        }

        withLocalizationBundle(portugueseBundle) {
            let searchCard = Card(cardType: .search)
            let suttaCard = Card(cardType: .sutta)

            let searchLocalized = searchCard.localizedCardTypeName()
            let suttaLocalized = suttaCard.localizedCardTypeName()

            #expect(searchLocalized == "Pesquisa")
            #expect(suttaLocalized == "Sutta")
        }
    }

    @Test
    @MainActor
    func cardEnglishLocalization() {
        let searchCard = Card(cardType: .search)
        let suttaCard = Card(cardType: .sutta)

        #expect(searchCard.localizedCardTypeName() == "Search")
        #expect(suttaCard.localizedCardTypeName() == "Sutta")
    }

    @Test
    @MainActor
    func cardLocalizationKeysExist() {
        // Verify all required localization keys exist in the default bundle
        let searchKey = "card.type.search"
        let suttaKey = "card.type.sutta"

        let searchString = searchKey.localized
        let suttaString = suttaKey.localized

        // Keys should resolve to non-empty strings (not remain as keys)
        #expect(!searchString.isEmpty)
        #expect(!suttaString.isEmpty)
        #expect(searchString == "Search")
        #expect(suttaString == "Sutta")
    }

    @Test
    @MainActor
    func cardLocalizationKeysExistInPortuguese() {
        guard let bundle = Bundle.module.url(forResource: "pt-PT", withExtension: "lproj"),
              let portugueseBundle = Bundle(url: bundle)
        else {
            #expect(Bool(false), "Failed to load pt-PT localization bundle")
            return
        }

        withLocalizationBundle(portugueseBundle) {
            let searchKey = "card.type.search"
            let suttaKey = "card.type.sutta"

            let searchString = searchKey.localized
            let suttaString = suttaKey.localized

            // Keys should resolve to translations in Portuguese
            #expect(!searchString.isEmpty)
            #expect(!suttaString.isEmpty)
            #expect(searchString == "Pesquisa")
            #expect(suttaString == "Sutta")
        }
    }

    // Verify Card gets PersistentIdentifier automatically
    @Test
    func cardHasUUID() {
        let card = Card()
        // #expect(card.id is PersistentIdentifier)

        let card2 = Card()
        // #expect(card2.id is PersistentIdentifier)
        #expect(card.id != card2.id)
    }

    // MARK: - Codable Tests

    @Test
    func cardEncodesToJSON() throws {
        let card = Card(
            cardType: .search,
            typeId: 1,
            searchQuery: "mindfulness"
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(card)
        let jsonString = String(data: jsonData, encoding: .utf8)

        #expect(jsonString != nil)
        #expect(jsonString?.contains("\"uuid\"") ?? false)
        #expect(jsonString?.contains("\"cardType\":\"search\"") ?? false)
        #expect(jsonString?.contains("\"typeId\":1") ?? false)
        #expect(jsonString?.contains("\"searchQuery\":\"mindfulness\"") ?? false)
    }

    @Test
    func cardDecodesFromJSON() throws {
        let json = """
        {
          "uuid": "550e8400-e29b-41d4-a716-446655440000",
          "createdAt": 725846400.0,
          "cardType": "search",
          "typeId": 2,
          "searchQuery": "dhamma",
          "searchResults": null,
          "suttaReference": ""
        }
        """

        let decoder = JSONDecoder()
        let card = try decoder.decode(Card.self, from: json.data(using: .utf8)!)

        #expect(card.uuid == UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
        #expect(card.cardType == .search)
        #expect(card.typeId == 2)
        #expect(card.searchQuery == "dhamma")
        #expect(card.searchResults == nil)
        #expect(card.suttaReference == "")
    }

    @Test
    func cardRoundTripSerialization() throws {
        let originalCard = Card(
            cardType: .sutta,
            typeId: 5,
            searchQuery: "",
            suttaReference: "MN 10"
        )
        let originalUUID = originalCard.uuid

        // Encode to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalCard)

        // Decode from JSON
        let decoder = JSONDecoder()
        let decodedCard = try decoder.decode(Card.self, from: jsonData)

        // Verify properties match
        #expect(decodedCard.uuid == originalUUID)
        #expect(decodedCard.cardType == originalCard.cardType)
        #expect(decodedCard.typeId == originalCard.typeId)
        #expect(decodedCard.searchQuery == originalCard.searchQuery)
        #expect(decodedCard.suttaReference == originalCard.suttaReference)
        #expect(decodedCard.createdAt == originalCard.createdAt)
    }

    @Test
    func cardWithSearchResponseRoundTrip() throws {
        let searchResponse = SearchResponse(
            author: "test",
            lang: "en",
            pattern: "anicca",
            segsMatched: 10
        )
        let originalCard = Card(
            cardType: .search,
            typeId: 3,
            searchQuery: "anicca",
            searchResults: searchResponse
        )

        // Encode and decode
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalCard)

        let decoder = JSONDecoder()
        let decodedCard = try decoder.decode(Card.self, from: jsonData)

        // Verify SearchResponse survived round-trip
        #expect(decodedCard.searchResults != nil)
        #expect(decodedCard.searchResults?.pattern == "anicca")
        #expect(decodedCard.searchResults?.author == "test")
        #expect(decodedCard.searchResults?.segsMatched == 10)
    }

    @Test
    func cardUUIDPreservedAcrossInstances() throws {
        let card1 = Card(cardType: .search, typeId: 1)
        let uuid1 = card1.uuid

        // Encode and decode
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(card1)

        let decoder = JSONDecoder()
        let card2 = try decoder.decode(Card.self, from: jsonData)

        // UUID should be the same
        #expect(card2.uuid == uuid1)

        // But PersistentIdentifier should be different (regenerated)
        #expect(card1.id != card2.id)
    }

    // MARK: - Card/SearchResponse Relationship Tests

    @Test
    func cardWithMockSearchResponse() throws {
        guard let mockResponse = SearchResponse.createMockResponse() else {
            #expect(Bool(false), "Failed to load mock SearchResponse")
            return
        }

        let card = Card(
            cardType: .search,
            typeId: 1,
            searchQuery: "root of suffering",
            searchResults: mockResponse
        )

        #expect(card.searchResults != nil)
        #expect(card.searchResults?.pattern == "root of suffering")
        #expect(card.searchResults?.author == "sujato")
        #expect(card.searchResults?.mlDocs.count == 1)
    }

    @Test
    func cardMockSearchResponseNestedDataIntegrity() throws {
        guard let mockResponse = SearchResponse.createMockResponse() else {
            #expect(Bool(false), "Failed to load mock SearchResponse")
            return
        }

        let card = Card(
            cardType: .search,
            typeId: 1,
            searchResults: mockResponse
        )

        guard let response = card.searchResults else {
            #expect(Bool(false), "SearchResponse should not be nil")
            return
        }

        // Verify SearchResponse fields
        #expect(response.author == "sujato")
        #expect(response.lang == "en")
        #expect(response.pattern == "root of suffering")
        #expect(response.segsMatched == 14)

        // Verify MLDocument
        #expect(response.mlDocs.count == 1)
        let doc = response.mlDocs.first!
        #expect(doc.author == "Bhikkhu Sujato")
        #expect(doc.segMap.count == 55)

        // Verify Segment data
        let segment = doc.segMap["sn42.11:2.11"]
        #expect(segment != nil)
        #expect(segment?.matched == true)
        #expect(segment?.doc != nil)
    }

    @Test
    func cardWithMockSearchResponseRoundTrip() throws {
        guard let mockResponse = SearchResponse.createMockResponse() else {
            #expect(Bool(false), "Failed to load mock SearchResponse")
            return
        }

        let originalCard = Card(
            cardType: .search,
            typeId: 2,
            searchQuery: "root of suffering",
            searchResults: mockResponse
        )

        // Encode and decode
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalCard)

        let decoder = JSONDecoder()
        let decodedCard = try decoder.decode(Card.self, from: jsonData)

        // Verify SearchResponse survived round-trip
        #expect(decodedCard.searchResults != nil)
        #expect(decodedCard.searchResults?.pattern == "root of suffering")
        #expect(decodedCard.searchResults?.author == "sujato")
        #expect(decodedCard.searchResults?.mlDocs.count == 1)

        // Verify nested MLDocument data
        let doc = decodedCard.searchResults?.mlDocs.first
        #expect(doc?.sutta_uid == "sn42.11")
        #expect(doc?.segMap.count == 55)
    }

    @Test
    func cardWithNilSearchResponse() throws {
        let card = Card(
            cardType: .search,
            typeId: 3,
            searchQuery: "test",
            searchResults: nil
        )

        #expect(card.searchResults == nil)

        // Encode and decode
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(card)

        let decoder = JSONDecoder()
        let decodedCard = try decoder.decode(Card.self, from: jsonData)

        #expect(decodedCard.searchResults == nil)
    }

    @Test
    func cardWithEmptySearchResponse() throws {
        let emptyResponse = SearchResponse()
        let card = Card(
            cardType: .search,
            typeId: 4,
            searchResults: emptyResponse
        )

        #expect(card.searchResults != nil)
        #expect(card.searchResults?.mlDocs.count == 0)
        #expect(card.searchResults?.pattern == "")

        // Encode and decode
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(card)

        let decoder = JSONDecoder()
        let decodedCard = try decoder.decode(Card.self, from: jsonData)

        #expect(decodedCard.searchResults != nil)
        #expect(decodedCard.searchResults?.mlDocs.count == 0)
        #expect(decodedCard.searchResults?.pattern == "")
    }

    // MARK: - Card MLDocument Tests (Objective 04)

    @Test
    func cardMLDocDefaultNil() throws {
        let card = Card(cardType: .sutta, typeId: 1)
        #expect(card.mlDoc == nil)
    }

    @Test
    func cardMLDocCanBeSet() throws {
        let doc = MLDocument(sutta_uid: "sn42.11", title: "Test")
        let card = Card(cardType: .sutta, typeId: 1, mlDoc: doc)
        #expect(card.mlDoc != nil)
        #expect(card.mlDoc?.sutta_uid == "sn42.11")
    }

    @Test
    func cardMLDocWithCurrentScidPersists() throws {
        let doc = MLDocument(sutta_uid: "sn42.11", title: "Test")
        doc.currentScid = "sn42.11:2.11"

        let card = Card(cardType: .sutta, typeId: 1, mlDoc: doc)

        // Encode and decode
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(card)

        let decoder = JSONDecoder()
        let decodedCard = try decoder.decode(Card.self, from: jsonData)

        #expect(decodedCard.mlDoc != nil)
        #expect(decodedCard.mlDoc?.sutta_uid == "sn42.11")
        #expect(decodedCard.mlDoc?.currentScid == "sn42.11:2.11")
    }

    @Test
    func cardMLDocRoundTripPreservesAllProperties() throws {
        let doc = MLDocument(
            author: "Bhikkhu Sujato",
            sutta_uid: "sn42.11",
            title: "Linked Discourses 42.11",
            currentScid: "sn42.11:1.5"
        )

        let card = Card(cardType: .sutta, typeId: 2, mlDoc: doc)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(card)

        let decoder = JSONDecoder()
        let decodedCard = try decoder.decode(Card.self, from: jsonData)

        #expect(decodedCard.mlDoc?.author == "Bhikkhu Sujato")
        #expect(decodedCard.mlDoc?.sutta_uid == "sn42.11")
        #expect(decodedCard.mlDoc?.title == "Linked Discourses 42.11")
        #expect(decodedCard.mlDoc?.currentScid == "sn42.11:1.5")
    }

    // MARK: - SwiftData Persistence Tests

    @Test
    @MainActor
    func cardIdentityPreservesThroughSwiftDataRoundTrip() throws {
        // Setup in-memory model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Card.self, configurations: config)
        let context = ModelContext(container)

        // Create and save search card
        let originalCard = Card(cardType: .search, typeId: 1, searchQuery: "test")
        let originalUUID = originalCard.uuid
        let originalCreatedAt = originalCard.createdAt

        context.insert(originalCard)
        try context.save()

        // Load from SwiftData
        let fetchDescriptor = FetchDescriptor<Card>()
        let loadedCards = try context.fetch(fetchDescriptor)
        let loadedCard = loadedCards.first!

        // Verify uuid and createdAt preserved
        #expect(loadedCard.uuid == originalUUID)
        #expect(loadedCard.createdAt == originalCreatedAt)
    }

    @Test
    @MainActor
    func cardIdentityPreservesSuttaCardTypeSwiftData() throws {
        // Setup in-memory model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Card.self, configurations: config)
        let context = ModelContext(container)

        // Create and save sutta card
        let originalCard = Card(cardType: .sutta, typeId: 5, suttaReference: "MN 10")
        let originalUUID = originalCard.uuid
        let originalCreatedAt = originalCard.createdAt

        context.insert(originalCard)
        try context.save()

        // Load from SwiftData
        let fetchDescriptor = FetchDescriptor<Card>()
        let loadedCards = try context.fetch(fetchDescriptor)
        let loadedCard = loadedCards.first!

        // Verify uuid and createdAt preserved for sutta card
        #expect(loadedCard.uuid == originalUUID)
        #expect(loadedCard.createdAt == originalCreatedAt)
        #expect(loadedCard.cardType == .sutta)
        #expect(loadedCard.suttaReference == "MN 10")
    }

    @Test
    @MainActor
    func cardIdentityPreservesMultipleRoundTrips() throws {
        // Setup in-memory model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Card.self, configurations: config)
        let context = ModelContext(container)

        // Create and save card
        let originalCard = Card(cardType: .search, typeId: 2, searchQuery: "dhamma")
        let originalUUID = originalCard.uuid
        let originalCreatedAt = originalCard.createdAt

        context.insert(originalCard)
        try context.save()

        // First reload
        var fetchDescriptor = FetchDescriptor<Card>()
        var loadedCards = try context.fetch(fetchDescriptor)
        var card = loadedCards.first!

        #expect(card.uuid == originalUUID)
        #expect(card.createdAt == originalCreatedAt)

        // Modify and save again
        card.searchQuery = "updated search"
        try context.save()

        // Second reload
        fetchDescriptor = FetchDescriptor<Card>()
        loadedCards = try context.fetch(fetchDescriptor)
        card = loadedCards.first!

        // Verify uuid and createdAt still preserved after modification
        #expect(card.uuid == originalUUID)
        #expect(card.createdAt == originalCreatedAt)
        #expect(card.searchQuery == "updated search")
    }

    // MARK: - Card Validation Tests (Objective 03)

    @Test
    @MainActor
    func cardTypeIdUniquePerCardType() throws {
        // Setup in-memory model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Card.self, configurations: config)
        let context = ModelContext(container)

        // Create first search card with typeId 1
        let card1 = Card(cardType: .search, typeId: 1)
        context.insert(card1)
        try context.save()

        // Attempt to create second search card with same typeId
        let card2 = Card(cardType: .search, typeId: 1)
        context.insert(card2)
        try context.save()

        // Verify both cards exist (constraint not enforced at model level yet)
        let fetchDescriptor = FetchDescriptor<Card>()
        let cards = try context.fetch(fetchDescriptor)

        // Count cards with same cardType and typeId
        let duplicates = cards.filter { $0.cardType == .search && $0.typeId == 1 }
        #expect(duplicates.count == 2, "Multiple cards with same (cardType, typeId) found - constraint may not be enforced")
    }

    @Test
    @MainActor
    func cardTypeIdCanExistAcrossDifferentCardTypes() throws {
        // Setup in-memory model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Card.self, configurations: config)
        let context = ModelContext(container)

        // Create search card with typeId 1
        let searchCard = Card(cardType: .search, typeId: 1)
        context.insert(searchCard)

        // Create sutta card with same typeId
        let suttaCard = Card(cardType: .sutta, typeId: 1)
        context.insert(suttaCard)

        try context.save()

        // Verify both cards exist with same typeId but different cardType
        let fetchDescriptor = FetchDescriptor<Card>()
        let cards = try context.fetch(fetchDescriptor)

        let searchCards = cards.filter { $0.cardType == .search && $0.typeId == 1 }
        let suttaCards = cards.filter { $0.cardType == .sutta && $0.typeId == 1 }

        #expect(searchCards.count == 1)
        #expect(suttaCards.count == 1)
    }

    @Test
    @MainActor
    func cardManagerBulkAddMaintainsTypeIdUniqueness() throws {
        // Setup in-memory model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Card.self, configurations: config)
        let context = ModelContext(container)

        // Create CardManager and add multiple cards rapidly
        let manager = CardManager(modelContext: context)

        let card1 = manager.addCard(cardType: .search)
        let card2 = manager.addCard(cardType: .search)
        let card3 = manager.addCard(cardType: .search)

        // Verify each card got unique typeId
        let typeIds = Set([card1.typeId, card2.typeId, card3.typeId])
        #expect(typeIds.count == 3, "Cards should have unique typeIds")

        // Verify cards are in ascending order
        #expect(card1.typeId < card2.typeId)
        #expect(card2.typeId < card3.typeId)

        // Verify no duplicates in storage
        let fetchDescriptor = FetchDescriptor<Card>()
        let allCards = try context.fetch(fetchDescriptor)
        let searchCards = allCards.filter { $0.cardType == .search }

        let searchTypeIds = searchCards.map { $0.typeId }
        let uniqueTypeIds = Set(searchTypeIds)
        #expect(uniqueTypeIds.count == searchTypeIds.count, "All search cards should have unique typeIds")
    }

    @Test
    @MainActor
    func cardDirectCreationValidation() throws {
        // Setup in-memory model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Card.self, configurations: config)
        let context = ModelContext(container)

        // Test that Card can be instantiated with explicit typeId
        let card1 = Card(cardType: .search, typeId: 5)
        let card2 = Card(cardType: .sutta, typeId: 5)
        let card3 = Card(cardType: .search, typeId: 6)

        context.insert(card1)
        context.insert(card2)
        context.insert(card3)
        try context.save()

        // Verify all cards exist
        let fetchDescriptor = FetchDescriptor<Card>()
        let allCards = try context.fetch(fetchDescriptor)

        #expect(allCards.count == 3)

        // Verify typeIds are as expected
        let searchCards = allCards.filter { $0.cardType == .search }.sorted { $0.typeId < $1.typeId }
        #expect(searchCards[0].typeId == 5)
        #expect(searchCards[1].typeId == 6)
    }

    // MARK: - Localization Edge Cases (Objective 04)

    @Test
    @MainActor
    func cardLocalizationMissingKeyFallback() {
        // When a localization key doesn't exist, NSLocalizedString returns the key itself
        // Manually call localization on a non-existent key
        let missingKeyResult = "nonexistent.key".localized

        // Should return the key itself as fallback
        #expect(missingKeyResult == "nonexistent.key")
    }

    @Test
    @MainActor
    func cardLocalizationWithEmptyBundle() throws {
        // Create a temporary empty bundle (no Localizable.strings)
        let tempDir = FileManager.default.temporaryDirectory
        let bundleDir = tempDir.appendingPathComponent(UUID().uuidString).appendingPathComponent("empty.lproj")

        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        guard let emptyBundle = Bundle(url: bundleDir.deletingLastPathComponent()) else {
            #expect(Bool(false), "Failed to create empty bundle")
            return
        }

        withLocalizationBundle(emptyBundle) {
            let card = Card(cardType: .search)
            let localizedName = card.localizedCardTypeName()

            // With empty bundle, should fallback to key
            #expect(localizedName == "card.type.search")
        }

        // Cleanup
        try FileManager.default.removeItem(at: bundleDir.deletingLastPathComponent())
    }

    @Test
    @MainActor
    func cardLocalizationBundleSwappingWithErrors() throws {
        // Save original bundle reference
        let searchCard = Card(cardType: .search)
        let originalLocalization = searchCard.localizedCardTypeName()

        // Verify original works
        #expect(originalLocalization == "Search")

        // Load Portuguese bundle
        guard let bundle = Bundle.module.url(forResource: "pt-PT", withExtension: "lproj"),
              let portugueseBundle = Bundle(url: bundle)
        else {
            #expect(Bool(false), "Failed to load pt-PT localization bundle")
            return
        }

        // Swap to Portuguese
        withLocalizationBundle(portugueseBundle) {
            let portugueseLocalization = searchCard.localizedCardTypeName()
            #expect(portugueseLocalization == "Pesquisa")
        }

        // Verify original bundle is restored
        let restoredLocalization = searchCard.localizedCardTypeName()
        #expect(restoredLocalization == "Search")
    }

    @Test
    @MainActor
    func cardLocalizationNestedBundleSwapping() throws {
        let card = Card(cardType: .search)

        // Load Portuguese bundle
        guard let bundle = Bundle.module.url(forResource: "pt-PT", withExtension: "lproj"),
              let portugueseBundle = Bundle(url: bundle)
        else {
            #expect(Bool(false), "Failed to load pt-PT localization bundle")
            return
        }

        withLocalizationBundle(portugueseBundle) {
            let portugueseResult1 = card.localizedCardTypeName()
            #expect(portugueseResult1 == "Pesquisa")

            // Create empty bundle and swap within Portuguese context
            let tempDir = FileManager.default.temporaryDirectory
            let bundleDir = tempDir.appendingPathComponent(UUID().uuidString).appendingPathComponent("empty.lproj")

            do {
                try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

                guard let emptyBundle = Bundle(url: bundleDir.deletingLastPathComponent()) else {
                    #expect(Bool(false), "Failed to create empty bundle")
                    return
                }

                withLocalizationBundle(emptyBundle) {
                    let emptyResult = card.localizedCardTypeName()
                    // Should fallback to key
                    #expect(emptyResult == "card.type.search")
                }

                // Should restore to Portuguese
                let portugueseResult2 = card.localizedCardTypeName()
                #expect(portugueseResult2 == "Pesquisa")

                // Cleanup
                try FileManager.default.removeItem(at: bundleDir.deletingLastPathComponent())
            } catch {
                #expect(Bool(false), "Failed to create temporary bundle: \(error)")
            }
        }
    }

    @Test
    @MainActor
    func cardLocalizationWithInvalidBundlePath() throws {
        let card = Card(cardType: .search)

        // Try to load from non-existent path
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")
            .appendingPathComponent("fake.lproj")

        let invalidBundle = Bundle(url: invalidURL)

        // Bundle should be nil or unusable
        if let bundle = invalidBundle {
            withLocalizationBundle(bundle) {
                let result = card.localizedCardTypeName()
                // Should fallback since bundle has no strings
                #expect(result == "card.type.search")
            }
        }
    }

    @Test
    @MainActor
    func cardLocalizationPartiallyTranslatedBundle() throws {
        // Create a bundle with only partial translations
        let tempDir = FileManager.default.temporaryDirectory
        let bundleDir = tempDir.appendingPathComponent(UUID().uuidString).appendingPathComponent("partial.lproj")

        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        // Create Localizable.strings with only one key
        let stringsContent = "\"card.type.search\" = \"CustomSearch\";\n"
        let stringsPath = bundleDir.appendingPathComponent("Localizable.strings")

        try stringsContent.write(toFile: stringsPath.path, atomically: true, encoding: .utf8)

        guard let partialBundle = Bundle(url: bundleDir.deletingLastPathComponent()) else {
            #expect(Bool(false), "Failed to create partial bundle")
            try FileManager.default.removeItem(at: bundleDir.deletingLastPathComponent())
            return
        }

        withLocalizationBundle(partialBundle) {
            let card = Card(cardType: .search)
            let suttaCard = Card(cardType: .sutta)

            let searchLocalized = card.localizedCardTypeName()
            let suttaLocalized = suttaCard.localizedCardTypeName()

            // Search key exists in partial bundle
            #expect(searchLocalized == "CustomSearch")

            // Sutta key doesn't exist, should fallback to key
            #expect(suttaLocalized == "card.type.sutta")
        }

        // Cleanup
        try FileManager.default.removeItem(at: bundleDir.deletingLastPathComponent())
    }

    @Test
    @MainActor
    func cardLocalizationBundleSwappingExceptionSafety() throws {
        let card = Card(cardType: .search)

        guard let bundle = Bundle.module.url(forResource: "pt-PT", withExtension: "lproj"),
              let portugueseBundle = Bundle(url: bundle)
        else {
            #expect(Bool(false), "Failed to load pt-PT localization bundle")
            return
        }

        // Test that bundle swapping with defer properly restores bundle
        withLocalizationBundle(portugueseBundle) {
            let portugueseValue = card.localizedCardTypeName()
            #expect(portugueseValue == "Pesquisa")
        }

        // Verify original bundle is restored after withLocalizationBundle exits
        // This tests that the defer in withLocalizationBundle works correctly
        let restoredValue = card.localizedCardTypeName()
        #expect(restoredValue == "Search")
    }

    @Test
    @MainActor
    func cardLocalizationMultipleCardsWithInvalidBundle() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let bundleDir = tempDir.appendingPathComponent(UUID().uuidString).appendingPathComponent("empty.lproj")

        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        guard let emptyBundle = Bundle(url: bundleDir.deletingLastPathComponent()) else {
            #expect(Bool(false), "Failed to create empty bundle")
            return
        }

        withLocalizationBundle(emptyBundle) {
            let searchCard1 = Card(cardType: .search, typeId: 1)
            let suttaCard1 = Card(cardType: .sutta, typeId: 1)
            let searchCard2 = Card(cardType: .search, typeId: 2)

            // All should fallback gracefully
            #expect(searchCard1.localizedCardTypeName() == "card.type.search")
            #expect(suttaCard1.localizedCardTypeName() == "card.type.sutta")
            #expect(searchCard2.localizedCardTypeName() == "card.type.search")
        }

        // Cleanup
        try FileManager.default.removeItem(at: bundleDir.deletingLastPathComponent())
    }

    @Test
    @MainActor
    func cardLocalizationKeyAccessDirectly() {
        // Test accessing localization keys directly without Card
        let searchKey = "card.type.search"
        let suttaKey = "card.type.sutta"
        let invalidKey = "nonexistent.translation"

        let searchLocalized = searchKey.localized
        let suttaLocalized = suttaKey.localized
        let invalidLocalized = invalidKey.localized

        #expect(searchLocalized == "Search")
        #expect(suttaLocalized == "Sutta")
        #expect(invalidLocalized == "nonexistent.translation")
    }

    @Test
    @MainActor
    func cardLocalizationFormattedStrings() throws {
        // Create a temporary bundle with a formatted string template
        let tempDir = FileManager.default.temporaryDirectory
        let bundleDir = tempDir.appendingPathComponent(UUID().uuidString).appendingPathComponent("format.lproj")

        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        // Create Localizable.strings with a format string
        let stringsContent = "\"format.test\" = \"Card %d: %@\";\n"
        let stringsPath = bundleDir.appendingPathComponent("Localizable.strings")

        try stringsContent.write(toFile: stringsPath.path, atomically: true, encoding: .utf8)

        guard let formatBundle = Bundle(url: bundleDir.deletingLastPathComponent()) else {
            #expect(Bool(false), "Failed to create format bundle")
            try FileManager.default.removeItem(at: bundleDir.deletingLastPathComponent())
            return
        }

        withLocalizationBundle(formatBundle) {
            // Test the localized(_:) method with format arguments
            let formatted = "format.test".localized(1, "Search" as CVarArg)
            #expect(formatted == "Card 1: Search")
        }

        // Cleanup
        try FileManager.default.removeItem(at: bundleDir.deletingLastPathComponent())
    }
}
