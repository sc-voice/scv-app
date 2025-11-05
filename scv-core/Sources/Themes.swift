//
//  Themes.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import SwiftUI

// MARK: - Theme Definition

/// Defines color and styling for the application
public struct Theme {
  /// Primary background color
  public let backgroundColor: Color

  /// Primary text color
  public let textColor: Color

  /// Secondary text color
  public let secondaryTextColor: Color

  /// Accent color for highlights and buttons
  public let accentColor: Color

  /// Card/container background
  public let cardBackground: Color

  /// Border color
  public let borderColor: Color

  public init(
    backgroundColor: Color,
    textColor: Color,
    secondaryTextColor: Color,
    accentColor: Color,
    cardBackground: Color,
    borderColor: Color
  ) {
    self.backgroundColor = backgroundColor
    self.textColor = textColor
    self.secondaryTextColor = secondaryTextColor
    self.accentColor = accentColor
    self.cardBackground = cardBackground
    self.borderColor = borderColor
  }
}

// MARK: - Theme Definitions

/// Saffron color used in both themes
private let COLOR_SAFFRON = Color(red: 1.0, green: 0.6, blue: 0.2) // #ff9933

/// Application themes
public enum AppTheme {
  /// Light theme with light backgrounds and dark text
  case light

  /// Dark theme with dark backgrounds and light text
  case dark

  /// Get the theme configuration
  public var theme: Theme {
    switch self {
    case .light:
      // Light theme: light backgrounds with dark text
      // Based on vuetify-opts.mjs lightTheme
      return Theme(
        backgroundColor: Color(red: 0.933, green: 0.933, blue: 0.933), // #eeeeee (grey.lighten1)
        textColor: Color(red: 0.1, green: 0.1, blue: 0.1), // dark text
        secondaryTextColor: Color(red: 0.5, green: 0.5, blue: 0.5), // medium grey
        accentColor: COLOR_SAFFRON, // #ff9933
        cardBackground: Color(red: 0.941, green: 0.941, blue: 0.941), // #f0f0f0
        borderColor: Color(red: 0.9, green: 0.9, blue: 0.9) // light grey
      )
    case .dark:
      // Dark theme: dark backgrounds with light text
      // Based on vuetify-opts.mjs darkTheme
      return Theme(
        backgroundColor: Color(red: 0.071, green: 0.071, blue: 0.071), // #121212
        textColor: Color(red: 0.95, green: 0.95, blue: 0.95), // light text
        secondaryTextColor: Color(red: 0.7, green: 0.7, blue: 0.7), // light grey
        accentColor: COLOR_SAFFRON, // #ff9933
        cardBackground: Color(red: 0.133, green: 0.133, blue: 0.133), // #222222
        borderColor: Color(red: 0.3, green: 0.3, blue: 0.3) // dark grey
      )
    }
  }
}
