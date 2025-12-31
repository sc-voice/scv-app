//
//  CardSidebarView.swift
//  scv-ui
//
//  Created by Claude on 2025-11-17.
//

import scvCore
import SwiftData
import SwiftUI

public struct CardSidebarView<Manager: ICardManager>: View {
  @Binding var selectedCardId: AnyHashable?
  let cardManager: Manager
  let cc = ColorConsole(#file, #function, dbg.CardSidebarView.other)
  @EnvironmentObject var themeProvider: ThemeProvider
  let onSettingsTap: (() -> Void)?
  @State private var titleOpacity: Double = 1.0
  @State private var titleScale: Double = 1.0
  @State private var titleColor: Color?
  @State private var backgroundOpacity: Double = 1

  public init(
    cardManager: Manager,
    selectedCardId: Binding<AnyHashable?>,
    onSettingsTap: (() -> Void)? = nil,
  ) {
    self.cardManager = cardManager
    _selectedCardId = selectedCardId
    self.onSettingsTap = onSettingsTap
  }

  private var cardListView: some View {
    Group {
      if UIDevice.current.userInterfaceIdiom == .phone {
        // iPhone: Use List for proper NavigationSplitView single-column selection behavior
        List(selection: $selectedCardId) {
          ForEach(cardManager.allCards, id: \.id) { card in
            cardRowContent(card)
              .contentShape(Rectangle())
              .onTapGesture {
                selectedCardId = card.id
                cardManager.selectCard(card)
                cc.ok1(#line, "Selected card:", card.name)
              }
          }
          .onDelete { indices in
            cardManager.removeCards(at: indices)
            cc.ok1(#line, "Deleted card(s) at indices:", indices.debugDescription)
          }
        }
        .scrollContentBackground(.hidden)
        .background(.black.opacity(0.5))
      } else {
        // iPad/macOS: Use ScrollView for custom styling and animations
        ScrollView {
          VStack(spacing: 0) {
            ForEach(cardManager.allCards, id: \.id) { card in
              cardRow(card)
            }
          }
          .background(.black)
          .cornerRadius(8)
          .padding(8)
        }
        .scrollContentBackground(.hidden)
        .background(ScvBackgroundsView(.space).opacity(backgroundOpacity))
      }
    }
  }

  // Shared content for both iOS and macOS
  private func cardRowContent(_ card: Manager.ManagedCard) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: card.iconName())
        .foregroundStyle(card.id == cardManager
          .recentCardId ? themeProvider.theme.accentColor : .secondary)

      if card.cardType == .sutta {
        suttaCardContent(card)
      } else {
        VStack(alignment: .leading, spacing: 2) {
          Text(card.sidebarTitle)
            .font(.headline)
            .lineLimit(1)
            .foregroundStyle(card.sidebarTitle == "card.search.placeholder"
              .localized || card.sidebarTitle == "card.type.sutta"
              .localized ? .secondary : .primary)
        }
      }

      Spacer()

      Button(action: {
        cardManager.removeCardId(card.id)
        cc.ok1(#line, "Deleted card:", card.name)
      }) {
        Image(systemName: "xmark.circle.fill")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help("Delete card")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // macOS-only: card row with accent border and selection styling
  private func cardRow(_ card: Manager.ManagedCard) -> some View {
    cardRowContent(card)
      .padding(12)
      .padding(.trailing, 0)
      .overlay(
        alignment: .trailing,
        content: {
          if selectedCardId == card.id {
            themeProvider.theme.accentColor
              .frame(width: 4)
          }
        }
      )
      .onTapGesture {
        selectedCardId = card.id
        cardManager.selectCard(card)
        cc.ok1(#line, "Selected card:", card.name)
      }
  }

  public var body: some View {
    ZStack {
      cardListView
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("scVoice/\(Settings.shared.docLang.code.uppercased())")
            .font(.title2)
            .foregroundStyle(titleColor ?? themeProvider.theme.accentColor)
            .opacity(titleOpacity)
            .scaleEffect(titleScale)
        }

        #if os(iOS)
          ToolbarItem(placement: .navigationBarLeading) {
            Button(action: addNewCard) {
              Image(systemName: "plus")
                .font(.title2)
            }
            .buttonStyle(.plain)
            .help("Add new search card")
          }

          if let onSettingsTap {
            ToolbarItem(placement: .navigationBarTrailing) {
              Button(action: handleSettingsTap(onSettingsTap)) {
                Image(systemName: "gearshape")
                  .font(.title2)
              }
              .buttonStyle(.plain)
              .help("Settings")
            }
          }
        #else
          ToolbarItem(placement: .automatic) {
            Button(action: addNewCard) {
              Image(systemName: "magnifyingglass")
                .font(.title2)
            }
            .buttonStyle(.plain)
            .help("Add new search card")
          }

          if let onSettingsTap {
            ToolbarItem(placement: .automatic) {
              Button(action: handleSettingsTap(onSettingsTap)) {
                Image(systemName: "gearshape")
                  .font(.title2)
              }
              .buttonStyle(.plain)
              .help("Settings")
            }
          }
        #endif
      }
      .toolbarBackground(Color.black, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .onAppear {
        if titleColor == nil {
          titleColor = themeProvider.theme.secondaryTextColor
        }
        withAnimation(.linear(duration: 30)) {
          backgroundOpacity = 0.2
        }
      }
    } // ZStack
    .background( Color.black )
  } // View

  // MARK: - Sutta Card Display

  private func suttaCardContent(_ card: Manager.ManagedCard) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      // Line 1: Abbreviation + Title (clipped with ellipsis)
      if let suttaRef = SuttaRef.create(card.suttaReference) {
        let abbreviation = suttaRef.abbreviation()
        let title = getTitleForSuttaRef(suttaRef, mlDoc: card.mlDoc)
        let displayText = "\(abbreviation) \(title)"

        Text(displayText)
          .font(.headline)
          .lineLimit(1)
          .truncationMode(.tail)
          .foregroundStyle(.primary)
      }

      // Line 2: lang:author (segmentCount)
      if let suttaRef = SuttaRef.create(card.suttaReference) {
        let caption = formatSuttaCaption(suttaRef, mlDoc: card.mlDoc)
        Text(caption)
          .font(.caption)
          .lineLimit(1)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func getTitleForSuttaRef(_ suttaRef: SuttaRef, mlDoc: MLDocument?)
    -> String
  {
    guard let mlDoc else {
      return Tipitaka.tipitakaName(suttaRef: suttaRef)
    }

    // Try to get title from segment :0.3
    if let titleSegment = mlDoc.segMap["\(suttaRef.suttaUid):0.3"],
       let doc = titleSegment.doc, !doc.isEmpty
    {
      return doc.trimmingCharacters(in: .whitespaces)
    }

    // Fall back to segment :0.2
    if let titleSegment = mlDoc.segMap["\(suttaRef.suttaUid):0.2"],
       let doc = titleSegment.doc, !doc.isEmpty
    {
      return doc.trimmingCharacters(in: .whitespaces)
    }

    // Fall back to Pali name
    return Tipitaka.tipitakaName(suttaRef: suttaRef)
  }

  private func formatSuttaCaption(_ suttaRef: SuttaRef, mlDoc: MLDocument?)
    -> String
  {
    let segmentCount = mlDoc?.segMap.count ?? 0
    return "\(suttaRef.lang):\(suttaRef.author ?? "unknown") (\(segmentCount))"
  }

  // MARK: - Private Methods

  private func addNewCard() {
    let newCard = cardManager.addCard(type: .search)
    cardManager.selectCard(newCard)
    cc.ok1(#line, "Added new card:", newCard.name)
  }

  private func handleSettingsTap(_ callback: @escaping () -> Void) -> () -> Void {
    {
      withAnimation(.easeInOut(duration: 2.0)) {
        titleColor = themeProvider.theme.accentColor
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        withAnimation(.easeInOut(duration: 2.0)) {
          titleColor = themeProvider.theme.secondaryTextColor
        }
      }
      callback()
    }
  }
}

// MARK: - Mock for Preview

/// Simple mock card manager for preview
@Observable
public class PreviewCardManager: ICardManager {
  public typealias ManagedCard = PreviewCard

  public var allCards: [PreviewCard]
  public var selectedCardId: AnyHashable?
  public var recentCardId: AnyHashable?

  public var selectedCard: PreviewCard? {
    guard let selectedCardId else { return nil }
    return cardFromId(selectedCardId)
  }

  public init(cards: [PreviewCard] = [], selectedCardId: AnyHashable? = nil) {
    allCards = cards
    self.selectedCardId = selectedCardId
    recentCardId = selectedCardId
  }

  public func selectCard(_ card: PreviewCard) {
    selectedCardId = card.id
    recentCardId = card.id
  }

  public func selectCardId(_ id: AnyHashable?) {
    if let id, let card = cardFromId(id) {
      selectedCardId = card.id
      recentCardId = card.id
    } else {
      selectedCardId = nil
    }
  }

  public func removeCards(at indices: IndexSet) {
    allCards.remove(atOffsets: indices)
  }

  public func removeCardId(_ id: AnyHashable) {
    if let index = allCards.firstIndex(where: { $0.id == id }) {
      allCards.remove(at: index)
    }
  }

  public func cardFromId(_ id: AnyHashable) -> PreviewCard? {
    allCards.first { $0.id == id }
  }

  public func bindCard(id: AnyHashable) -> Binding<PreviewCard>? {
    guard cardFromId(id) != nil else {
      return nil
    }

    return Binding(
      get: { [weak self] in
        self?.cardFromId(id) ?? PreviewCard(cardType: .search, typeId: 0)
      },
      set: { [weak self] newValue in
        if let index = self?.allCards.firstIndex(where: { $0.id == id }) {
          self?.allCards[index] = newValue
        }
      },
    )
  }

  @discardableResult
  public func addCard(type cardType: scvCore.CardType) -> PreviewCard {
    let newId = (allCards.map(\.typeId).max() ?? 0) + 1
    let newCard = PreviewCard(cardType: cardType, typeId: newId)
    allCards.append(newCard)
    return newCard
  }

  public func saveCard(_ card: PreviewCard) {
    // Mock implementation - just updates in-memory
    if let index = allCards.firstIndex(where: { $0.id == card.id }) {
      allCards[index] = card
    }
  }

  public func suttaCardForRef(_ suttaRef: SuttaRef,
                              searchQuery: String?) async -> PreviewCard
  {
    // Mock implementation - return existing or create new sutta card
    let refString = suttaRef.toString()
    if let existing = allCards.first(where: {
      $0.cardType == .sutta && $0.suttaReference == refString
    }) {
      return existing
    }

    let newId = (allCards.filter { $0.cardType == .sutta }.map(\.typeId)
      .max() ?? 0) + 1
    let newCard = PreviewCard(
      cardType: .sutta,
      typeId: newId,
      searchQuery: searchQuery ?? "",
      suttaReference: refString,
    )
    allCards.append(newCard)
    return newCard
  }
}

// MARK: - Preview

#Preview("CardSidebarView with 3 cards") {
  @Previewable @State var selectedId: AnyHashable? = nil

  let card1 = PreviewCard(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )
  let card2 = PreviewCard(
    cardType: .sutta,
    typeId: 1,
    suttaReference: "thig1.1/en/soma",
  )
  let card3 = PreviewCard(cardType: .search, typeId: 3, searchQuery: "")

  let manager = PreviewCardManager(
    cards: [card1, card2, card3],
    selectedCardId: card1.id,
  )

  CardSidebarView(
    cardManager: manager,
    selectedCardId: $selectedId,
    onSettingsTap: {
      print("Settings tapped")
    },
  )
  .environmentObject(ThemeProvider())
}
