//
//  SuttaCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-01.
//

import scvCore
import SwiftUI

// MARK: - SuttaCardView

/// Minimal sutta viewer card showing suttaRef and document content
public struct SuttaCardView<Card: ICard, Manager: ICardManager>: View
  where Manager.ManagedCard == Card
{
  @Binding var card: Card
  let cardManager: Manager
  @EnvironmentObject var themeProvider: ThemeProvider
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  public init(
    card: Binding<Card>,
    cardManager: Manager,
  ) {
    _card = card
    self.cardManager = cardManager
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(card.suttaReference)
        .font(.headline)
        .foregroundColor(themeProvider.theme.textColor)
        .padding()

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(themeProvider.theme.cardBackground)
    .onAppear {
      cc.ok1(#line, "SuttaCardView initialized for:", card.suttaReference)
    }
  }
}

// MARK: - Preview

#Preview("SuttaCardView") {
  @Previewable @State var mockCard = MockCard(
    cardType: .sutta,
    typeId: 1,
    suttaReference: "mn1/en/sujato",
  )

  let manager = MockCardManager(
    cards: [mockCard],
    selectedCardId: mockCard.id,
  )

  SuttaCardView(card: $mockCard, cardManager: manager)
    .environmentObject(ThemeProvider())
}
