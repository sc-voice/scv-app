//
//  SearchCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-11-18.
//

import scvCore
import SwiftUI

/// Minimalist search card view with TextField for searchQuery editing
/// Displays search query input with dashed border in debug color
public struct SearchCardView: View {
  @Binding var card: Card
  @EnvironmentObject var themeProvider: ThemeProvider
  let cc = ColorConsole(#file, #function)

  public init(card: Binding<Card>) {
    _card = card
  }

  public var body: some View {
    let cc = ColorConsole(#file, #function)
    VStack(alignment: .leading, spacing: 16) {
      Text("Search Query")
        .font(.headline)
        .foregroundStyle(themeProvider.theme.textColor)

      TextField("Enter search query", text: $card.searchQuery)
        .textFieldStyle(.roundedBorder)
        .foregroundStyle(themeProvider.theme.textColor)
        .padding()
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
        .onChange(of: card.searchQuery) { _, newValue in
          cc.ok2(#line, "searchQuery updated:", newValue)
        }

      Spacer()
    }
    .padding()
    .background(themeProvider.theme.cardBackground)
    .onAppear {
      cc.ok1(#line, "SearchCardView initialized for card:", card.name)
    }
  }
}

// MARK: - Preview

#Preview("SearchCardView") {
  @Previewable @State var card = Card(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )

  SearchCardView(card: $card)
    .environmentObject(ThemeProvider())
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ThemeProvider().theme.backgroundColor)
}
