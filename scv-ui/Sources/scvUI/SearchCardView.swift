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
      } else if !lastWasInvalid {
        result.append(" ")
        lastWasInvalid = true
      }
    }

    // Trim and collapse multiple spaces to single space
    return result.trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
  }
}

// MARK: - SearchCardView

/// Search card view with custom toolbar TextField for searchQuery editing
/// Phase 1: Allow user to enter search query and confirm with return key
public struct SearchCardView: View {
  @Binding var card: Card
  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var showAlert = false
  @State private var lastConfirmedQuery = ""
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  public init(card: Binding<Card>) {
    _card = card
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Results will appear here")
        .font(.body)
        .foregroundStyle(themeProvider.theme.secondaryTextColor)

      Spacer()
    }
    .padding()
    .background(themeProvider.theme.cardBackground)
    .toolbar {
      #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
          searchQueryField
            .frame(maxWidth: .infinity)
        }
      #else
        ToolbarItem(placement: .automatic) {
          searchQueryField
            .frame(maxWidth: .infinity)
        }
      #endif
    }
    .alert("Search Confirmation", isPresented: $showAlert) {
      Button("OK") {}
    } message: {
      Text("Search for: \(lastConfirmedQuery)")
    }
    .onAppear {
      cc.ok1(#line, "SearchCardView initialized for card:", card.name)
    }
  }

  private var searchQueryField: some View {
    HStack(spacing: 8) {
      TextField("Enter search query", text: $card.searchQuery)
        .textFieldStyle(.roundedBorder)
        .foregroundStyle(themeProvider.theme.textColor)
        .onChange(of: card.searchQuery) { _, newValue in
          let filtered = SearchQueryFilter.filter(newValue)
          if filtered != newValue {
            card.searchQuery = filtered
          }
          cc.ok2(#line, "searchQuery filtered:", filtered)
        }
        .onSubmit {
          lastConfirmedQuery = card.searchQuery
          showAlert = true
          cc.ok1(#line, "Search confirmed:", card.searchQuery)
        }
        .padding(8)
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .strokeBorder(
              style: StrokeStyle(
                lineWidth: 2,
                dash: [5],
              ),
            )
            .foregroundStyle(themeProvider.theme.debugForeground),
        )
    }
  }
}

// MARK: - Preview

#Preview("SearchCardView") {
  @Previewable @State var selectedCardId: UUID?
  @Previewable @State var bindableCard1 = Card(
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
      SearchCardView(card: $bindableCard1)
    } else {
      Text("Select a card")
    }
  }
  .environmentObject(ThemeProvider())
}
