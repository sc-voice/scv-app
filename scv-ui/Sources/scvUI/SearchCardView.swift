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
    let allowedCharacters =
      CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.: ")
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
  @State private var showAlert = false
  @State private var lastConfirmedQuery = ""
  @State private var debounceTimer: Timer?
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  public init(card: Binding<Card>, cardManager: Manager) {
    _card = card
    self.cardManager = cardManager
  }

  // MARK: - Private Methods

  private func autoComplete(_ query: String, card _: Card) {
    cc.ok1(#line, "autocomplete:", query)
  }

  // MARK: - Static Methods

  static func searchSubmitHandler(
    _ card: Card,
    cardManager: Manager,
    searchQueryBinding: Binding<String>,
  ) {
    let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)
    cardManager.saveCard(card)
    // FIXME: SwiftUI bug with searchable() - text field clears after onSubmit
    // See: https://developer.apple.com/forums/thread/734087
    // Workaround: Clear and restore binding to force UI sync
    let savedQuery = searchQueryBinding.wrappedValue
    searchQueryBinding.wrappedValue = ""
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      searchQueryBinding.wrappedValue = savedQuery
    }

    cc.ok1(#line, "Search submitted:", card.searchQuery)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Results will appear here")
        .font(.body)
        .foregroundStyle(themeProvider.theme.secondaryTextColor)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(themeProvider.theme.cardBackground)
    .padding(0)
    .border(themeProvider.theme.debugForeground, width: 2)
    .onChange(of: card.searchQuery) { _, newValue in
      let filtered = SearchQueryFilter.filter(newValue)
      if filtered != newValue {
        card.searchQuery = filtered
      }
      cc.ok2(#line, "onChange:", filtered)

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
      lastConfirmedQuery = card.searchQuery
      cardManager.saveCard(card)
      showAlert = true
      cc.ok1(#line, "Search confirmed:", card.searchQuery)
    }
    .alert("Search Confirmation", isPresented: $showAlert) {
      Button("OK") {}
    } message: {
      Text("Search for: \(lastConfirmedQuery)")
    }
    .onAppear {
      cc.ok1(#line, "SearchCardView initialized for card:", card.name)
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
