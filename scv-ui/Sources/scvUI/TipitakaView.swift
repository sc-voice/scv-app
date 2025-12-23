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
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("Tipiṭaka")
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    TipitakaView(tipitakaRefs: SN53Preview.tipitakaRefs)
      .environmentObject(ThemeProvider())
  }
}

// MARK: - Preview Data

/// SN 53 preview data for testing TipitakaView
private enum SN53Preview {
  static let tipitakaRefs: [TipitakaRef] = {
    // Create flat list of SN 53 documents
    let flatRefs = [
      TipitakaRef(id: "/sutta", name: "Sutta", caption: "Discourses"),
      TipitakaRef(
        id: "/sutta/sn",
        name: "Saṁyutta Nikāya",
        caption: "Connected Discourses",
      ),
      TipitakaRef(
        id: "/sutta/sn/sn53",
        name: "Okkantabhisamaya Saṁyutta",
        caption: "The Bodhisattva",
      ),
      TipitakaRef(
        id: "/sutta/sn/sn53/sn53.1-12",
        name: "1-12",
        caption: "Suttas 1-12",
      ),
      TipitakaRef(
        id: "/sutta/sn/sn53/sn53.13-22",
        name: "13-22",
        caption: "Suttas 13-22",
      ),
      TipitakaRef(
        id: "/sutta/sn/sn53/sn53.23-34",
        name: "23-34",
        caption: "Suttas 23-34",
      ),
      TipitakaRef(
        id: "/sutta/sn/sn53/sn53.35-44",
        name: "35-44",
        caption: "Suttas 35-44",
      ),
      TipitakaRef(
        id: "/sutta/sn/sn53/sn53.45-54",
        name: "45-54",
        caption: "Suttas 45-54",
      ),
    ]

    // Build tree from flat list
    return Tipitaka.buildTree(from: flatRefs)
  }()
}
