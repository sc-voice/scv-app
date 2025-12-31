//
//  LanguagePickerModal.swift
//  scv-ui
//
//  Created by Claude on 2025-12-31.
//

import scvCore
import SwiftUI

// MARK: - LanguagePickerModal

/// A reusable modal component for selecting from a picker with language/author options.
/// Handles iOS wheel picker and macOS menu picker styles automatically.
public struct LanguagePickerModal<T: Hashable>: View {
  @Environment(\.sizeCategory) var sizeCategory

  let title: String
  let selection: Binding<T>
  let options: [T]
  let optionLabel: (T) -> String

  var pickerDetent: Set<PresentationDetent> {
    sizeCategory.isAccessibilityCategory ? [.fraction(0.95)] : [.medium]
  }

  var pickerHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 400 : 250
  }

  /// Initialize a LanguagePickerModal
  /// - Parameters:
  ///   - title: Title displayed in the picker
  ///   - selection: Binding to the selected value
  ///   - options: Array of options to pick from
  ///   - optionLabel: Closure to extract display label from option
  public init(
    title: String,
    selection: Binding<T>,
    options: [T],
    optionLabel: @escaping (T) -> String
  ) {
    self.title = title
    self.selection = selection
    self.options = options
    self.optionLabel = optionLabel
  }

  public var body: some View {
    VStack {
      Picker(title, selection: selection) {
        ForEach(options, id: \.self) { option in
          Text(optionLabel(option))
            .font(.body)
            .tag(option)
        }
      }
      #if os(iOS)
      .pickerStyle(.wheel)
      #else
      .pickerStyle(.menu)
      #endif
    }
    .frame(height: pickerHeight)
    #if os(iOS)
      .presentationDetents(pickerDetent)
    #endif
  }
}

// MARK: - Preview

#Preview {
  struct PreviewContainer: View {
    @State private var selectedLanguage: ScvLanguage = .english

    var body: some View {
      NavigationStack {
        Form {
          Section("Select Language") {
            Text(selectedLanguage.displayName)
          }
        }
        .sheet(isPresented: .constant(true)) {
          LanguagePickerModal(
            title: "Language",
            selection: $selectedLanguage,
            options: ScvLanguage.allCases,
            optionLabel: { $0.displayName }
          )
        }
      }
    }
  }

  return PreviewContainer()
}
