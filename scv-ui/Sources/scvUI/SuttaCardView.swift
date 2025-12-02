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
  @State private var segments: [(key: String, value: Segment)] = []
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  public init(
    card: Binding<Card>,
    cardManager: Manager,
  ) {
    _card = card
    self.cardManager = cardManager
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
                HStack(alignment: .top, spacing: 8) {
                  Text(scid)
                    .font(.caption)
                    .foregroundColor(themeProvider.theme.secondaryTextColor)
                    .lineLimit(1)

                  highlightedSegmentView(getSegmentText(segment, field: "doc"))
                    .font(.body)
                    .lineLimit(nil)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(isSegmentSelected(scid) ? themeProvider.theme
                  .accentColor
                  .opacity(0.2) : .clear)
                .overlay(
                  RoundedRectangle(cornerRadius: 4)
                    .stroke(
                      isSegmentSelected(scid) ? themeProvider.theme
                        .accentColor : .clear,
                      style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .butt,
                        lineJoin: .bevel,
                        dash: [4, 3],
                      ),
                    ),
                )
                .id(scid)
                .onTapGesture {
                  mlDoc.currentScid = scid
                  // Dismiss keyboard when segment is selected
                  #if os(iOS)
                    UIApplication.shared.sendAction(
                      #selector(UIResponder.resignFirstResponder),
                      to: nil,
                      from: nil,
                      for: nil,
                    )
                  #endif
                  cc.ok1(#line, "Selected segment:", scid)
                }
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
        cc.ok1(#line, "onAppear \(mlDoc.currentScid)")
      } else {
        cc.ok1(#line, "onAppear no mlDoc")
      }
    }
  }

  // MARK: - Private Methods

  private func isSegmentSelected(_ scid: String) -> Bool {
    card.mlDoc?.currentScid == scid
  }

  private func getSegmentText(_ segment: Segment,
                              field: String = "doc") -> String
  {
    let EMPTY_SET = "∅"
    let value: String? = switch field.lowercased() {
    case "doc":
      segment.doc
    case "pli":
      segment.pli
    case "ref":
      segment.ref
    default:
      nil
    }
    return value?.isEmpty ?? true ? EMPTY_SET : value!
  }

  private func buildAttributedString(_ parseResult: HTMLParseResult)
    -> AttributedString
  {
    var attributedString = AttributedString("")

    for span in parseResult.spans {
      var spanAttr = AttributedString(span.text)
      if span.isMatched {
        spanAttr.foregroundColor = themeProvider.theme.accentColor
      } else {
        spanAttr.foregroundColor = themeProvider.theme.textColor
      }
      attributedString.append(spanAttr)
    }

    return attributedString
  }

  @ViewBuilder
  private func highlightedSegmentView(_ html: String) -> some View {
    let parseResult = HTMLParser.parse(htmlString: html)
    let attributedString = buildAttributedString(parseResult)

    Text(attributedString)
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
