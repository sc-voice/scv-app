//
//  SuttaCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-01.
//

import scvCore
import SwiftUI
#if os(iOS)
  import UIKit
#endif

// MARK: - SuttaCardView

/// Sutta viewer card displaying mlDoc segments with selection and highlighting
public struct SuttaCardView<Card: ICard, Manager: ICardManager>: View
  where Manager.ManagedCard == Card
{
  @Binding var card: Card
  let cardManager: Manager
  @EnvironmentObject var themeProvider: ThemeProvider
  @ObservedObject var player: SuttaPlayer
  @State private var segments: [(key: String, value: Segment)] = []
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  public init(
    card: Binding<Card>,
    cardManager: Manager,
    player: SuttaPlayer = .shared,
  ) {
    _card = card
    self.cardManager = cardManager
    self.player = player
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Title Header
      VStack(alignment: .leading, spacing: 8) {
        Text(card.mlDoc?.title ?? card.suttaReference)
          .font(.headline)
          .foregroundStyle(themeProvider.theme.textColor)
          .lineLimit(nil)

        if let mlDoc = card.mlDoc {
          HStack(spacing: 8) {
            Text(mlDoc.sutta_uid)
              .font(.caption)
              .foregroundColor(themeProvider.theme.secondaryTextColor)

            HStack(spacing: 4) {
              Image(systemName: "person.fill")
                .foregroundColor(themeProvider.theme.textColor)
              Text(mlDoc.docAuthorName)
                .foregroundColor(themeProvider.theme.textColor)
            }
            .font(.caption)

            Spacer()

            Button(action: {
              if player.currentSutta?.sutta_uid != mlDoc.sutta_uid {
                player.load(mlDoc)
              }
              player.togglePlayback()
            }) {
              Image(systemName: isCurrentlyPlaying && player
                .isPlaying ? "pause.fill" : "play.fill")
                .font(.title2)
                .foregroundColor(themeProvider.theme.textColor)
                .padding()
            }
          }
        }
      }
      .padding()
      .background(themeProvider.theme.cardBackground)
      .border(themeProvider.theme.borderColor, width: 0.5)

      // Segments Content
      if let mlDoc = card.mlDoc {
        ScrollViewReader { scrollProxy in
          ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(segments.indices, id: \.self) { index in
                let (scid, segment) = segments[index]
                SegmentView(
                  scid: scid,
                  segment: segment,
                  mlDoc: mlDoc,
                  player: player,
                  isCurrentlyPlaying: isCurrentlyPlaying,
                )
              }
            }
            .padding(.vertical)
          }
          .onAppear {
            if let currentScid = mlDoc.currentScid {
              // Delay scroll to allow segments to load
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollProxy.scrollTo(currentScid, anchor: .center)
                cc.ok1(#line, "Scrolled to segment on appear:", currentScid)
              }
            }
          }
          .onChange(of: mlDoc.currentScid) { _, newScid in
            if let newScid {
              scrollProxy.scrollTo(newScid, anchor: .center)
              cc.ok1(#line, "Scrolled to segment on change:", newScid)
            }
          }
        }
        .background(themeProvider.theme.backgroundColor)
      } else {
        VStack(spacing: 12) {
          Image(systemName: "doc.text")
            .font(.title2)
            .foregroundColor(themeProvider.theme.secondaryTextColor)
          Text("No document loaded")
            .foregroundColor(themeProvider.theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeProvider.theme.cardBackground)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      if let mlDoc = card.mlDoc {
        segments = mlDoc.segments()
        // Initialize currentScid to first segment if nil
        if mlDoc.currentScid == nil, let firstSegment = segments.first {
          mlDoc.currentScid = firstSegment.key
        }
        cc.ok1(#line, "onAppear \(mlDoc.currentScid ?? "nil")")
      } else {
        cc.ok1(#line, "onAppear no mlDoc")
      }
    }
    .onDisappear {
      // Stop playback when sutta card is dismissed
      // This prevents crashes when a playing sutta card is deleted
      if player.currentSutta?.sutta_uid == card.mlDoc?.sutta_uid {
        player.pause()
        player.currentSutta = nil
        cc.ok1(#line, "Stopped playback on sutta card disappear")
      }
    }
  }

  // MARK: - Private Methods

  private var isCurrentlyPlaying: Bool {
    player.currentSutta?.sutta_uid == card.mlDoc?.sutta_uid
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
