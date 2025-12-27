//
//  CollapsibleSection.swift
//  scv-ui
//
//  Created by Claude on 2025-12-27.
//

import scvCore
import SwiftUI

// MARK: - CollapsibleSection

/// A reusable collapsible section component with title, disclosure triangle, and content
public struct CollapsibleSection<Content: View>: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var isExpanded: Bool = false

  let title: String
  let initiallyExpanded: Bool
  let content: () -> Content

  /// Initialize a CollapsibleSection
  /// - Parameters:
  ///   - title: The header title displayed
  ///   - initiallyExpanded: Whether the section starts expanded (default: false)
  ///   - content: ViewBuilder closure containing the collapsible content
  public init(
    _ title: String,
    initiallyExpanded: Bool = false,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.title = title
    self.initiallyExpanded = initiallyExpanded
    self.content = content
    _isExpanded = State(initialValue: initiallyExpanded)
  }

  public var body: some View {
    VStack(spacing: 0) {
      // MARK: - Header
      Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
        HStack(spacing: 12) {
          // Disclosure triangle
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(themeProvider.theme.accentColor)
            .frame(width: 16)

          Text(title)
            .font(.headline)
            .foregroundColor(themeProvider.theme.textColor)

          Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(themeProvider.theme.cardBackground)
      }

      // MARK: - Divider
      Rectangle()
        .fill(themeProvider.theme.borderColor)
        .frame(height: 0.5)

      // MARK: - Content
      if isExpanded {
        VStack(spacing: 0) {
          content()
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeProvider.theme.backgroundColor.opacity(0.5))
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(themeProvider.theme.cardBackground)
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(themeProvider.theme.borderColor, lineWidth: 0.5)
    )
  }
}

// MARK: - Preview

#Preview("CollapsibleSection") {
  VStack(spacing: 16) {
    CollapsibleSection("Expand me", initiallyExpanded: false) {
      VStack(alignment: .leading, spacing: 12) {
        Text("This is the collapsed content.")
          .font(.body)
        Text("It can contain any view.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }

    CollapsibleSection("Initially Expanded", initiallyExpanded: true) {
      VStack(alignment: .leading, spacing: 8) {
        Text("This section starts expanded")
        Text("Click the header to collapse it")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }

    Spacer()
  }
  .padding()
  .background(.gray.opacity(0.1))
  .environmentObject(ThemeProvider())
}
