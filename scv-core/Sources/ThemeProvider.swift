//
//  ThemeProvider.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import SwiftUI

// MARK: - ThemeProvider

/// Manages application theme state and provides access to current theme
public class ThemeProvider: ObservableObject {
  /// Current application theme
  @Published public var currentTheme: AppTheme = .dark

  public init(theme: AppTheme? = nil) {
    if let theme = theme {
      currentTheme = theme
    } else {
      // Initialize from Settings
      currentTheme = Settings.shared.isDarkModeEnabled ? .dark : .light
    }
  }

  /// Get the current theme configuration
  public var theme: Theme {
    currentTheme.theme
  }

  /// Toggle between light and dark themes
  public func toggleTheme() {
    currentTheme = currentTheme == .light ? .dark : .light
    updateSettings()
  }

  /// Set theme to a specific value
  public func setTheme(_ theme: AppTheme) {
    currentTheme = theme
    updateSettings()
  }

  /// Sync Settings with current theme
  private func updateSettings() {
    Settings.shared.isDarkModeEnabled = (currentTheme == .dark)
    Settings.shared.save()
  }
}

// MARK: - View Extension

extension View {
  /// Apply current theme colors as modifiers
  func withTheme(_ themeProvider: ThemeProvider) -> some View {
    background(themeProvider.theme.backgroundColor)
      .foregroundColor(themeProvider.theme.textColor)
  }
}
