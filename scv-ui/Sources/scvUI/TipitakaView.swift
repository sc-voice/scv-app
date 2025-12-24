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
public struct TipitakaView: View {
  let tipitakaRefs: [TipitakaRef]
  @EnvironmentObject var themeProvider: ThemeProvider

  public init(tipitakaRefs: [TipitakaRef]) {
    self.tipitakaRefs = tipitakaRefs
  }

  public var body: some View {
    List {
      Text("Tipiṭaka")
      .font(.caption)
      .listRowSeparator(.hidden)
      OutlineGroup(tipitakaRefs, children: \.children) { ref in
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(ref.name)
              .font(.body)
            if let caption = ref.caption {
              Text(caption)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
          if ref.children == nil || ref.children?.isEmpty == true {
            print("Tapped leaf: \(ref.name)")
          }
        }
      }
    }
    .listStyle(.sidebar)
  }
}

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
      ProgressView()
        .task {
          let root = await Tipitaka.authorTipitaka(lang: "en", author: "soma")
          tipitakaRefs = [root]
        }
    } else {
      TipitakaView(tipitakaRefs: tipitakaRefs[0].children ?? [])
    }
  }
}
