//
//  SheetBackgroundDimmingModifier.swift
//  scv-ui
//
//  Created by Claude on 2025-12-31.
//

import SwiftUI

// MARK: - SheetBackgroundDimmingModifier

/// A modifier that dims the background when a sheet is presented.
/// Creates a semi-transparent overlay behind the sheet to darken the underlying content.
struct SheetBackgroundDimmingModifier: ViewModifier {
  @Binding var isPresented: Bool

  func body(content: Content) -> some View {
    ZStack {
      content

      if isPresented {
        Color.black
          .opacity(0.6)
          .ignoresSafeArea()
          .transition(.opacity)
      }
    }
  }
}

// MARK: - Extension

extension View {
  func sheetBackgroundDimming(isPresented: Binding<Bool>) -> some View {
    modifier(SheetBackgroundDimmingModifier(isPresented: isPresented))
  }
}
