//
//  SearchCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-11-18.
//

import scvCore
import SwiftUI

// MARK: - Quote HTML Parsing

/// Helper for parsing HTML quotes and converting to AttributedString
public enum QuoteHTMLParser {
  /// Parses HTML quote with <span> tag and returns AttributedString with bold
  /// accent formatting
  static func parseQuoteHTML(_ html: String?,
                             accentColor: Color) -> AttributedString?
  {
    guard let html else { return nil }

    var attributed = AttributedString()

    // Simple HTML parser for <span> tags
    var remaining = html
    while !remaining.isEmpty {
      if let spanStart = remaining.range(of: "<span>") {
        // Add text before span
        let before = String(remaining[..<spanStart.lowerBound])
        attributed.append(AttributedString(before))

        // Move past the opening tag
        remaining = String(remaining[spanStart.upperBound...])

        // Find closing tag
        if let spanEnd = remaining.range(of: "</span>") {
          let spanContent = String(remaining[..<spanEnd.lowerBound])

          // Add span content with bold and accent color
          var spanAttributed = AttributedString(spanContent)
          spanAttributed.font = .system(.body, design: .default, weight: .bold)
          spanAttributed.foregroundColor = accentColor
          attributed.append(spanAttributed)

          // Move past the closing tag
          remaining = String(remaining[spanEnd.upperBound...])
        } else {
          // Malformed HTML, just add the rest
          attributed.append(AttributedString(remaining))
          remaining = ""
        }
      } else {
        // No more spans, add remaining text
        attributed.append(AttributedString(remaining))
        remaining = ""
      }
    }

    return attributed
  }
}

// MARK: - SearchQueryFilter

/// Helper for filtering search query input
public enum SearchQueryFilter {
  public static func filter(_ input: String) -> String {
    let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)
    // Allow letters (EN, FR, PT, ES, RU), digits, parsing punctuation (. : ,),
    // and basic regexp (.*+^$\)
    var allowedCharacters = CharacterSet.letters
    allowedCharacters.formUnion(CharacterSet.decimalDigits)
    let punctuation = CharacterSet(charactersIn: ".:- .*+^$\\,")
    allowedCharacters.formUnion(punctuation)
    let lowercased = input.lowercased()

    // Replace 1+ consecutive invalid characters with single space
    var result = ""
    var lastWasInvalid = false

    for char in lowercased {
      if char.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) {
        result.append(char)
        lastWasInvalid = false
      } else {
        let charDisplay = String(char).debugDescription
        if !lastWasInvalid {
          cc.bad1(#line, "rejected:", charDisplay)
          result.append("?")
          lastWasInvalid = true
        } else {
          cc.bad1(#line, "ignored:", charDisplay)
        }
      }
    }

    // Trim and collapse multiple spaces to single space
    return result.replacingOccurrences(
      of: "  +",
      with: " ",
      options: .regularExpression,
    )
  }
}

// MARK: - SearchCardView

/// Search card view with custom toolbar TextField for searchQuery editing
/// Phase 1: Allow user to enter search query and confirm with return key
public struct SearchCardView<Card: ICard, Manager: ICardManager>: View
  where Manager.ManagedCard == Card
{
  @Binding var card: Card
  let cardManager: Manager
  @EnvironmentObject var themeProvider: ThemeProvider
  let isSearchFocused: Bool
  @State private var debounceTimer: Timer?
  @State private var iconOpacity: Double = 1.0
  @State private var iconOffset: CGFloat = 0
  @State private var maxIconOffset: CGFloat = -200
  let appIcon: Image
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  public init(
    card: Binding<Card>,
    cardManager: Manager,
    appIcon: Image? = nil,
    isSearchFocused: Bool = false,
  ) {
    _card = card
    self.cardManager = cardManager
    self.appIcon = appIcon ?? Image(systemName: "app.circle")
    self.isSearchFocused = isSearchFocused
  }

  // MARK: - Private Methods

  private func autoComplete(_ query: String, card _: Card) {
    cc.ok1(#line, "autocomplete:", query, card.searchQuery)
  }

  private func populateSuttaInfoInBackground(
    searchResult: SeekerResult,
    cardManager: Manager,
    cardId: Card.ID,
  ) {
    cc.ok2(
      #line,
      "Starting background sutta info population for \(searchResult.items.count) items",
    )

    Task {
      var updatedResult = searchResult
      let success = await updatedResult.populateItems()

      if success {
        if let card = cardManager.cardFromId(cardId) {
          var updatedCard = card
          updatedCard.searchResult = updatedResult
          cardManager.saveCard(updatedCard)
          cc.ok1(#line, "Saved card with populated segment info")
        } else {
          cc.bad1(#line, "Card not found for id:", cardId)
        }
      } else {
        cc.bad1(#line, "Failed to populate sutta info")
      }
    }
  }

  private func scheduleFade() {
    cc.ok2(#line, "scheduleFade: icon will fade and move up over 5s")
    withAnimation(.easeOut(duration: 5.0)) {
      iconOpacity = 0.1
      iconOffset = maxIconOffset
    }
  }

  private var resultsView: some View {
    guard let searchResult = card.searchResult else {
      return AnyView(
        GeometryReader { geometry in
          VStack(spacing: 12) {
            appIcon
              .resizable()
              .scaledToFit()
              .frame(width: 80, height: 80)
              .opacity(iconOpacity)
              .offset(y: iconOffset)
              .onAppear {
                // Calculate offset: move icon to 16pt below top of its
                // container
                let targetY = 16.0
                let iconCenterY = geometry.size.height / 2
                let calculated = -(iconCenterY - targetY)
                maxIconOffset = calculated
                cc.ok2(#line, "maxOffset calculated: \(calculated)")
              }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
        },
      )
    }

    // Check for error
    if let error = searchResult.error {
      return AnyView(
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.circle")
            .font(.title2)
            .foregroundColor(themeProvider.theme.errorTextColor)
          Text("card.search.error".localized)
            .font(.headline)
            .foregroundColor(themeProvider.theme.textColor)
          Text(error.message)
            .font(.body)
            .foregroundColor(themeProvider.theme.errorTextColor)
            .lineLimit(3)
          if !error.detail.isEmpty {
            Text(error.detail)
              .font(.caption)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
              .lineLimit(2)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(),
      )
    }

    // Display results
    return AnyView(
      VStack(alignment: .leading, spacing: 12) {
        // Summary header
        VStack(alignment: .leading, spacing: 4) {
          Text(
            "Found \(searchResult.items.count) document\(searchResult.items.count == 1 ? "" : "s")",
          )
          .font(.headline)
          .foregroundColor(themeProvider.theme.textColor)
          Text("Method: \(searchResult.metadata.method.rawValue)")
            .font(.caption)
            .foregroundColor(themeProvider.theme.textColor)
            .fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .cornerRadius(8)

        // Results list
        List(searchResult.items, id: \.suttaRef) { item in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(item.suttaRef.author ?? "unknown")
                .font(.caption)
                .foregroundColor(themeProvider.theme.textColor)
                .fontWeight(.semibold)
              Spacer()
              Text(
                "★ \(String(format: "%.2f", item.score))",
              )
              .font(.caption)
              .foregroundColor(themeProvider.theme.textColor)
              .fontWeight(.semibold)
              Text(
                item.segmentCount.map(String.init) ?? "…",
              )
              .font(.caption)
              .foregroundColor(themeProvider.theme.textColor)
              .fontWeight(.semibold)
              .frame(minWidth: 30, alignment: .trailing)
            }
            Text(item.suttaRef.suttaUid)
              .font(.body)
              .fontWeight(.semibold)
              .foregroundColor(themeProvider.theme.textColor)

            // Display quote if available
            if let quote = item.quote,
               let attributed = QuoteHTMLParser.parseQuoteHTML(
                 quote,
                 accentColor: themeProvider.theme.accentColor,
               )
            {
              Text(attributed)
                .font(.caption)
                .foregroundColor(themeProvider.theme.secondaryTextColor)
                .lineLimit(2)
            }
          }
          .padding(.vertical, 4)
          .contentShape(Rectangle())
          .onTapGesture {
            Task {
              let suttaCard = await cardManager.suttaCardForRef(
                item.suttaRef,
                searchQuery: card.searchQuery,
              )
              cardManager.selectCard(suttaCard)
              cc.ok1(
                #line,
                "Selected sutta card for:",
                item.suttaRef.toString(),
              )
            }
          }
        }
        .scrollContentBackground(.hidden)
        #if os(iOS)
          .listStyle(.insetGrouped)
        #else
          .listStyle(.automatic)
        #endif
      },
    )
  }

  // MARK: - Static Methods

  static func searchSubmitHandler(
    cardManager: Manager,
    selectedCardId: Manager.ManagedCard.ID,
    searchQueryBinding: Binding<String>,
  ) {
    let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)
    // Fetch fresh card from manager to ensure we have current state
    guard var card = cardManager.cardFromId(selectedCardId) else {
      cc.bad1(#line, "Card not found for id:", selectedCardId)
      return
    }

    // SYNC: Update card with current binding value before saving
    let searchQuery = searchQueryBinding.wrappedValue
    card.searchQuery = searchQuery
    cardManager.saveCard(card)

    cc.ok1(#line, "Search submitted:", searchQuery)

    // Execute search asynchronously
    Task {
      let ebtQuery = EbtQuery(query: searchQuery)
      let searchResult = await ebtQuery.search()

      // Update card with search result
      card.searchResult = searchResult
      cardManager.saveCard(card)

      if let error = searchResult.error {
        cc.bad1(#line, "Search failed:", error.message, "detail:", error.detail)
      } else {
        cc.ok1(
          #line,
          "Search completed with \(searchResult.items.count) results",
        )

        // Trigger background sutta info and quote population
        // Note: We need to spawn this on the main thread context
        // Create a temporary view instance to call the instance method
        DispatchQueue.main.async {
          let view = SearchCardView<Manager.ManagedCard, Manager>(
            card: .constant(card),
            cardManager: cardManager,
          )
          view.populateSuttaInfoInBackground(
            searchResult: searchResult,
            cardManager: cardManager,
            cardId: selectedCardId,
          )
        }
      }
    }

    // FIXME: SwiftUI bug with searchable() - text field clears after onSubmit
    // See: https://developer.apple.com/forums/thread/734087
    // Workaround: Clear and restore binding to force UI sync
    // NOTE: This is async and runs AFTER logging so it doesn't interfere with
    // card state
    searchQueryBinding.wrappedValue = ""
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      searchQueryBinding.wrappedValue = searchQuery
    }
  }

  public var body: some View {
    resultsView
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(0)
      .onChange(of: card.searchQuery) { _, newValue in
        let filtered = SearchQueryFilter.filter(newValue)
        if filtered != newValue {
          card.searchQuery = filtered
        }
        cc.ok2(#line, "onChange:", filtered)

        // Reset icon when user types new query
        withAnimation {
          iconOpacity = 1.0
          iconOffset = 0
        }
        scheduleFade()

        // Cancel existing debounce timer
        debounceTimer?.invalidate()

        // Start new 500ms debounce timer for autocomplete
        debounceTimer = Timer.scheduledTimer(
          withTimeInterval: 0.5,
          repeats: false,
        ) { _ in
          Task { @MainActor in
            autoComplete(filtered, card: card)
          }
        }
      }
      .onSubmit(of: .search) {
        cc.ok1(#line, "Search submitted:", card.searchQuery)
      }
      .onAppear {
        cc.ok1(#line, "SearchCardView initialized for card:", card.name)
        scheduleFade()
      }
      .onDisappear {
        debounceTimer?.invalidate()
        debounceTimer = nil
      }
  }
}

// MARK: - Preview

#Preview("SearchCardView") {
  @Previewable @State var selectedCardId: UUID? = nil
  @Previewable @State var mockCard1 = MockCard(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )

  let card1 = MockCard(cardType: .search, typeId: 1, searchQuery: "mindfulness")
  let card2 = MockCard(cardType: .search, typeId: 2, searchQuery: "suffering")
  let manager = MockCardManager(
    cards: [card1, card2],
    selectedCardId: card1.id,
  )

  NavigationSplitView {
    CardSidebarView(
      cardManager: manager,
      selectedCardId: $selectedCardId,
    )
    .onAppear {
      let ref1 = SuttaRef.create("mn119/en/sujato")
      let ref2 = SuttaRef.create("mn11/en/sujato")
      if ref1 != nil, ref2 != nil {
        mockCard1.searchResult = SeekerResult(
          metadata: SearchMetadata(
            timestamp: Date(),
            query: "mindfulness",
            method: .lemma,
            elapsedTime: 0.045,
            docLang: "en",
            docAuthor: "sujato",
          ),
          items: [
            .init(
              suttaRef: ref1!,
              score: 0.95,
              segmentCount: 42,
              quote: "Mindfulness is the path to the Deathless...",
            ),
            .init(
              suttaRef: ref2!,
              score: 0.87,
              segmentCount: 58,
              quote: "Through mindfulness, through heedfulness...",
            ),
          ],
        ) // SeekerResult
      } // if
    } // onAppear
  } detail: {
    ZStack {
      SearchCardView(card: $mockCard1, cardManager: manager)
    } // ZStack
    .background(ScvBackgroundsView(.sangha_dark))
  }
  .environmentObject(ThemeProvider())
}
