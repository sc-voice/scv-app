//
//  SuttaHeaderView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-05.
//

import scvCore
import SwiftUI

// MARK: - SuttaHeaderView

/// Header view for sutta card displaying title, sutta UID, author, and play
/// button
public struct SuttaHeaderView<Card: ICard>: View {
  let card: Card
  @ObservedObject var player: SuttaPlayer
  let suttaRef: SuttaRef?
  @EnvironmentObject var themeProvider: ThemeProvider

  public init(
    card: Card,
    player: SuttaPlayer,
  ) {
    suttaRef = SuttaRef.create(card.suttaReference)
    self.card = card
    _player = ObservedObject(initialValue: player)
  }

  public var title: String {
    if let mlDoc = card.mlDoc, let currentScid = mlDoc.currentScid {
      if let currentRef = SuttaRef.create(currentScid) {
        return currentRef.abbreviation() // E.g., AN2 vs AN1-10
      }
    }
    return suttaRef?.abbreviation() ?? "suttaRef?"
  }

  public var body: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(.headline)
          .foregroundStyle(themeProvider.theme.textColor)
          .lineLimit(nil)

        if let mlDoc = card.mlDoc {
          //HStack(spacing: 4) {
            //Image(systemName: "person.fill")
              //.foregroundColor(themeProvider.theme.textColor)
            Text(mlDoc.docAuthorName)
              .foregroundColor(themeProvider.theme.textColor)
          //}
          .font(.body)
        } // mlDoc
      } // VStack
      Spacer()
      if let mlDoc = card.mlDoc {
        Button(action: {
          if player.currentSutta?.sutta_uid != mlDoc.sutta_uid {
            player.load(mlDoc)
          }
          player.togglePlayback()
        }) {
          Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            .font(.title2)
            .foregroundColor(themeProvider.theme.textColor)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
      } // mlDoc
    } // HStack
    .padding(.horizontal, 16)
    .padding(.vertical, 5)
    .background(themeProvider.theme.backgroundColor)
    .border(themeProvider.theme.borderColor, width: 0.5)
  }
}

// MARK: - Preview

#Preview("SuttaHeaderView") {
  @Previewable @State var mockCard = PreviewCard(
    cardType: .sutta,
    typeId: 1,
    suttaReference: "mn1/en/sujato",
    mlDoc: MLDocument(
      author: "sujato",
      sutta_uid: "mn1",
      title: "The Root of Suffering",
      docLang: "en",
      docAuthor: "sujato",
      docAuthorName: "Bhikkhu Sujato",
    ),
  )

  SuttaHeaderView(
    card: mockCard,
    player: .shared,
  )
  .environmentObject(ThemeProvider())
}
