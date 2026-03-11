//
//  ForegroundAlert.swift
//  scv-ui
//
//  Created by Claude on 2026-03-11.
//

import SwiftUI

// MARK: - ForegroundAlert

/// Generic voice error alert for both foreground and background playback.
///
/// Displays a system alert with title, message, and OK button.
/// Respects Dynamic Type for accessibility.
extension View {
  func foregroundAlert(
    isPresented: Binding<Bool>,
    title: String,
    message: String,
    onOK: @escaping () -> Void = {}
  ) -> some View {
    alert(title, isPresented: isPresented) {
      Button("OK") {
        onOK()
      }
    } message: {
      Text(message)
    }
  }
}
