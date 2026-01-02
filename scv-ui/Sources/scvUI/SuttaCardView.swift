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
  @Environment(\.accessibilityReduceMotion) var reduceMotion

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
    VStack(alignment: .leading, spacing: 0) { // VStack1
      // Title Header
      SuttaHeaderView(
        card: card,
        player: player,
      )
      .environmentObject(themeProvider)

      // Segments Content
      if let mlDoc = card.mlDoc {
        ScrollViewReader { scrollProxy in
          ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(segments.indices, id: \.self) { index in
                let (_, segment) = segments[index]
                SegmentView(
                  segment: segment,
                  mlDoc: mlDoc,
                  player: player,
                )
              }
            }
            .padding(.vertical)
          }
          .scrollContentBackground(.hidden)
          .background(.clear)
          .onAppear {
            if let currentScid = mlDoc.currentScid {
              // Delay scroll to allow segments to load
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) {
                  // Scroll to two line heights from top
                  scrollProxy.scrollTo(
                    currentScid,
                    anchor: UnitPoint(x: 0.5, y: 0.06),
                  )
                  cc.ok1(
                    #line,
                    "Scrolled to segment (two line heights from top):",
                    currentScid,
                  )
                }
              }
            }
          }
          .onChange(of: mlDoc.currentScid) { _, newScid in
            if let newScid {
              withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) {
                // Scroll to two line heights from top
                scrollProxy.scrollTo(
                  newScid,
                  anchor: UnitPoint(x: 0.5, y: 0.06),
                )
                cc.ok1(
                  #line,
                  "Scrolled to segment (two line heights from top):",
                  newScid,
                )
              }
            }
          }
        }
      } else {
        VStack(spacing: 12) {
          Image(systemName: "doc.text")
            .font(.title2)
            .foregroundColor(themeProvider.theme.secondaryTextColor)
          Text("No document loaded")
            .foregroundColor(themeProvider.theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    } // VStack1
    .background(
      Group {
        if Settings.shared.isDarkModeEnabled {
          ScvBackgroundsView(.space)
            .overlay(
              LinearGradient(
                gradient: Gradient(stops: [
                  .init(color: .clear, location: 0),
                  .init(color: .black.opacity(0.3), location: 0.1),
                  .init(color: .black.opacity(0.6), location: 1),
                ]),
                startPoint: .top,
                endPoint: .bottom,
              ),
            )
        } else {
          ScvBackgroundsView(.nothingness)
            .brightness(0.1)
        }
      },
    )
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
}

// MARK: - Preview

#Preview("SuttaCardView") {
  @Previewable @State var mockCard = PreviewCard(
    cardType: .sutta,
    typeId: 1,
    suttaReference: "mn1/en/sujato",
  )

  let manager = PreviewCardManager(
    cards: [mockCard],
    selectedCardId: mockCard.id,
  )

  SuttaCardView(card: $mockCard, cardManager: manager)
    .environmentObject(ThemeProvider())
}
