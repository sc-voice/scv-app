//
//  HelpCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-03.
//

import scvCore
import SwiftUI

// MARK: - HelpCardView

/// Help card view displayed when no other cards exist
public struct HelpCardView: View {
  @EnvironmentObject var themeProvider: ThemeProvider

  public init() {}

  public var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "questionmark.circle")
        .font(.system(size: 64))
        .foregroundStyle(themeProvider.theme.accentColor)

      VStack(spacing: 12) {
        Text("HELP IS ON THE WAY")
          .font(.headline)
          .foregroundStyle(themeProvider.theme.textColor)

        Text(
          "Create a search card or sutta card using the + button to get started.",
        )
        .font(.body)
        .foregroundStyle(themeProvider.theme.secondaryTextColor)
        .multilineTextAlignment(.center)
      }
      .padding(.horizontal)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
    .background(themeProvider.theme.cardBackground)
  }
}

// MARK: - Preview

#Preview("HelpCardView") {
  HelpCardView()
    .environmentObject(ThemeProvider())
}
