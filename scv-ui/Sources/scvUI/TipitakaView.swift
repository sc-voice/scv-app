//
//  TipitakaView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-23.
//

import scvCore
import SwiftUI

// MARK: - TipitakaView

/// Displays hierarchical Tipiṭaka document tree using OutlineGroup
public struct TipitakaView<Manager: ICardManager>: View {
  let tipitakaRefs: [TipitakaRef]
  let cardManager: Manager?
  @EnvironmentObject var themeProvider: ThemeProvider
  let cc = ColorConsole(#file, #function, dbg.TipitakaView.other)

  public init(tipitakaRefs: [TipitakaRef], cardManager: Manager? = nil) {
    self.tipitakaRefs = tipitakaRefs
    self.cardManager = cardManager
  }

  // MARK: - Private Methods

  /// Recursively sort TipitakaRef children using SuttaCentralId.compareLow()
  private func sortedTipitakaRefs(_ refs: [TipitakaRef]) -> [TipitakaRef] {
    refs.map { ref in
      let sortedRef = ref
      if let children = ref.children {
        sortedRef.children = sortedTipitakaRefs(children).sorted { a, b in
          SuttaCentralId.compareLow(a.id, b.id) < 0
        }
      }
      return sortedRef
    }
    .sorted { a, b in
      SuttaCentralId.compareLow(a.id, b.id) < 0
    }
  }

  /// Extracts the suttaUid from a TipitakaRef path
  /// Example: "/sutta/mn/mn1" → "mn1"
  private func suttaUidFromPath(_ path: String) -> String? {
    let components = path.split(separator: "/").map(String.init)
    return components.last
  }

  /// Renders a single row in the OutlineGroup
  @ViewBuilder
  private func tipitakaRowContent(_ ref: TipitakaRef) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(ref.name)
          .font(.body)
        if let caption = ref.caption {
          Text(caption)
            .font(.caption)
            .foregroundColor(themeProvider.theme.textColor)
        }
      }
      .padding(0)
    }
    .padding(0)
    .contentShape(Rectangle())
    .onTapGesture {
      if ref.children == nil || ref.children?.isEmpty == true {
        handleLeafTap(ref)
      }
    }
  }

  /// Handles tapping on a leaf node to create and select a sutta card
  private func handleLeafTap(_ ref: TipitakaRef) {
    guard let suttaUid = suttaUidFromPath(ref.id) else {
      cc.bad1(#line, "Could not extract suttaUid from path:", ref.id)
      return
    }

    cc.ok1(#line, "Tapped leaf:", ref.name, "suttaUid:", suttaUid)

    // Create SuttaRef using current Settings lang/author
    guard let suttaRef = SuttaRef.create(
      suttaUid,
      defaultLang: Settings.shared.docLang.code,
      defaultAuthor: Settings.shared.docAuthor,
    ) else {
      cc.bad1(#line, "Failed to create SuttaRef for:", suttaUid)
      return
    }

    // Create and select sutta card
    guard let cardManager else {
      cc.bad1(#line, "No cardManager available")
      return
    }

    Task {
      let suttaCard = await cardManager.suttaCardForRef(suttaRef)
      cardManager.selectCard(suttaCard)
      cc.ok1(#line, "Selected sutta card for:", suttaRef.toString())
    }
  }

  public var body: some View {
    VStack {
      List {
        Text("Tipiṭaka")
        .font(.body)
        .listRowSeparator(.hidden)
        .foregroundStyle(themeProvider.theme.toolbarForeground)
        .listRowBackground(themeProvider.theme.toolbarBackground)
        OutlineGroup(sortedTipitakaRefs(tipitakaRefs),
                     children: \.children)
        { ref in
          tipitakaRowContent(ref)
        }
      }
      .padding(20)
      #if os(iOS)
      .listRowSpacing(2)
      #endif
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
    } // VStack
    .background(themeProvider.theme.cardBackground)
    .cornerRadius(16)
  } // View
} // TipitakaView

// MARK: - Preview

#Preview {
  NavigationStack {
    TipitakaViewPreview()
      .environmentObject(ThemeProvider())
  }
}

// MARK: - Preview Helper

private struct TipitakaViewPreview: View {
  @State private var tipitakaRefs: [TipitakaRef] = []

  var body: some View {
    if tipitakaRefs.isEmpty {
      ScvProgressView()
        .task {
          let root = await Tipitaka.authorTipitaka(lang: "en", author: "soma")
          tipitakaRefs = [root]
        }
    } else {
      // Use PreviewCardManager for preview (cardManager is optional)
      TipitakaView<PreviewCardManager>(
        tipitakaRefs: tipitakaRefs[0].children ?? [],
        cardManager: nil,
      )
    }
  }
}
