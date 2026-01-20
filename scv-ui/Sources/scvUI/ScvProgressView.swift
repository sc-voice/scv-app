//
//  ScvProgressView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-31.
//

import SwiftUI

/// Reusable progress view with app icon and circular activity indicator
/// Used throughout the app for loading states
public struct ScvProgressView: View {
  let appIcon: Image?
  let label: String?

  public init(appIcon: Image? = nil, label: String? = nil) {
    self.appIcon = appIcon
    self.label = label
  }

  public var body: some View {
    ZStack {
      VStack(spacing: 20) {
        Spacer()

        // App icon or fallback text
        if let appIcon {
          appIcon
            .resizable()
            .scaledToFit()
            .opacity(0.8)
            .frame(width: 80, height: 80)
            .clipShape(Circle())
        } else {
          Image(systemName: "ladybug.slash.fill")
            .resizable()
            .scaledToFit()
            .opacity(0.8)
            .frame(width: 80, height: 80)
            .clipShape(Circle())
        }

        // Optional label
        if let label {
          Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      // Circular progress indicator
      ProgressView()
        .scaleEffect(2.1, anchor: .center)
    }
  }
}

#Preview("With App Icon") {
  ScvProgressView(
    appIcon: Image(systemName: "waveform.circle.fill"),
    label: "Loading...",
  )
}

#Preview("Without Icon") {
  ScvProgressView(label: "Please wait")
}

#Preview("Minimal") {
  ScvProgressView()
}
