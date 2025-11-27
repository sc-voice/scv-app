//
//  SearchCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-11-18.
//

import scvCore
import SwiftUI

// MARK: - SearchQueryFilter

/// Helper for filtering search query input
public enum SearchQueryFilter {
  public static func filter(_ input: String) -> String {
    let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)
    // Allow alphanumerics, parsing punctuation (. : ,), and basic regexp
    // (.*+^$\)
    let allowedCharacters = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.: .*+^$\\,",
    )
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
  @State private var debounceTimer: Timer?
  @State private var iconOpacity: Double = 1.0
  @State private var iconOffset: CGFloat = 0
  @State private var maxIconOffset: CGFloat = -200
  let searchingIcon: Image
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  public init(
    card: Binding<Card>,
    cardManager: Manager,
    searchingIcon: Image? = nil,
  ) {
    _card = card
    self.cardManager = cardManager
    self.searchingIcon = searchingIcon ?? Image(systemName: "app.circle")
  }

  // MARK: - Private Methods

  private func autoComplete(_ query: String, card _: Card) {
    cc.ok1(#line, "autocomplete:", query, card.searchQuery)
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
            searchingIcon
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
        .padding()
        .background(themeProvider.theme.cardBackground),
      )
    }

    // Display results
    return AnyView(
      VStack(alignment: .leading, spacing: 12) {
        // Summary header
        VStack(alignment: .leading, spacing: 4) {
          Text(
            "Found \(searchResult.results.count) document\(searchResult.results.count == 1 ? "" : "s")",
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
        .background(themeProvider.theme.cardBackground)
        .cornerRadius(8)

        // Results list
        List(searchResult.results, id: \.suttaRef) { item in
          VStack(alignment: .leading, spacing: 4) {
            Text(item.suttaRef.suttaUid)
              .font(.body)
              .fontWeight(.semibold)
              .foregroundColor(themeProvider.theme.textColor)
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
            }
          }
          .padding(.vertical, 4)
        }
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
      let settings = Settings.shared
      let searchResult = await EbtData.shared.search(
        query: searchQuery,
        docLang: settings.docLang.code,
        docAuthor: settings.docAuthor,
        refLang: settings.refLang.code,
        refAuthor: settings.refAuthor,
      )

      // Update card with search result
      card.searchResult = searchResult
      cardManager.saveCard(card)

      if let error = searchResult.error {
        cc.bad1(#line, "Search failed:", error.message, "detail:", error.detail)
      } else {
        cc.ok1(
          #line,
          "Search completed with \(searchResult.results.count) results",
        )
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
      .background(themeProvider.theme.cardBackground)
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
  @Previewable @State var selectedCardId: UUID?
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

  selectedCardId = card1.id

  return NavigationSplitView {
    CardSidebarView(
      cardManager: manager,
      selectedCardId: $selectedCardId,
    )
  } detail: {
    if selectedCardId == card1.id {
      SearchCardView(card: $mockCard1, cardManager: manager)
    } else {
      Text("Select a card")
    }
  }
  .environmentObject(ThemeProvider())
}
