//
//  CollapsibleSection.swift
//  scv-ui
//
//  Created by Claude on 2025-12-27.
//

import scvCore
import SwiftUI

// MARK: - CollapsibleSection

/// A reusable collapsible section component with title, disclosure triangle,
/// and content
public struct CollapsibleSection<Content: View>: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  @Binding var isExpanded: Bool
  @Environment(\.accessibilityReduceMotion) var reduceMotion

  let title: String
  let onToggle: (() -> Void)?
  let content: () -> Content

  /// Initialize a CollapsibleSection with external state management
  /// - Parameters:
  ///   - title: The header title displayed
  ///   - isExpanded: Binding to whether the section is expanded
  ///   - onToggle: Optional callback when section is toggled
  ///   - content: ViewBuilder closure containing the collapsible content
  public init(
    _ title: String,
    isExpanded: Binding<Bool>,
    onToggle: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> Content,
  ) {
    self.title = title
    _isExpanded = isExpanded
    self.onToggle = onToggle
    self.content = content
  }

  public var body: some View {
    VStack(spacing: 0) {
      // MARK: - Header

      Button(action: {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
          isExpanded.toggle()
          onToggle?()
        }
      }) {
        HStack(spacing: 12) {
          // Disclosure triangle
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.body.weight(.semibold))
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
        .stroke(themeProvider.theme.borderColor, lineWidth: 0.5),
    )
  }
}

// MARK: - Preview

#Preview("CollapsibleSection") {
  struct PreviewContainer: View {
    @State private var expandedSection: String? = nil

    var body: some View {
      VStack(spacing: 16) {
        CollapsibleSection(
          "Expand me",
          isExpanded: .constant(expandedSection == "one"),
        ) {
          VStack(alignment: .leading, spacing: 12) {
            Text("This is the collapsed content.")
              .font(.body)
            Text("It can contain any view.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        CollapsibleSection(
          "Another Section",
          isExpanded: .constant(expandedSection == "two"),
        ) {
          VStack(alignment: .leading, spacing: 8) {
            Text("This section can be expanded")
            Text("Click the header to expand/collapse it")
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
  }

  return PreviewContainer()
}
