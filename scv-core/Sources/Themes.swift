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

  /// Value color for user-mutable values (voices, settings, etc.)
  public let valueColor: Color

  /// Toolbar color
  public let toolbarColor: Color

  /// Debug text color (only visible in debug builds)
  public let debugForeground: Color

  public init(
    backgroundColor: Color,
    textColor: Color,
    secondaryTextColor: Color,
    accentColor: Color,
    cardBackground: Color,
    borderColor: Color,
    valueColor: Color,
    toolbarColor: Color,
    debugForeground: Color,
  ) {
    self.backgroundColor = backgroundColor
    self.textColor = textColor
    self.secondaryTextColor = secondaryTextColor
    self.accentColor = accentColor
    self.cardBackground = cardBackground
    self.borderColor = borderColor
    self.valueColor = valueColor
    self.toolbarColor = toolbarColor
    self.debugForeground = debugForeground
  }
}

// MARK: - Theme Definitions

/// Saffron color used in both themes
private let COLOR_SAFFRON = Color(red: 1.0, green: 0.6, blue: 0.2) // #ff9933

/// Cyan color for user-mutable values
private let COLOR_CYAN = Color(red: 0.0, green: 1.0, blue: 1.0) // #00ffff

/// Brown color for toolbar (dark theme)
private let COLOR_BROWN = Color(red: 0.243, green: 0.161,
                                blue: 0.141) // #3E2723

/// Grey color for toolbar (light theme)
private let COLOR_GREY = Color(red: 0.741, green: 0.741, blue: 0.741) // #BDBDBD

/// Fuchsia color for debug text (light theme)
private let COLOR_FUCHSIA = Color(red: 1.0, green: 0.0, blue: 1.0) // #FF00FF

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
      Theme(
        backgroundColor: Color(red: 0.933, green: 0.933,
                               blue: 0.933), // #eeeeee (grey.lighten1)
        textColor: Color(red: 0.1, green: 0.1, blue: 0.1), // dark text
        secondaryTextColor: Color(red: 0.5, green: 0.5,
                                  blue: 0.5), // medium grey
        accentColor: COLOR_SAFFRON, // #ff9933
        cardBackground: Color(red: 0.941, green: 0.941, blue: 0.941), // #f0f0f0
        borderColor: Color(red: 0.9, green: 0.9, blue: 0.9), // light grey
        valueColor: COLOR_CYAN, // #00ffff
        toolbarColor: COLOR_GREY, // #BDBDBD
        debugForeground: COLOR_FUCHSIA, // #FF00FF
      )
    case .dark:
      // Dark theme: dark backgrounds with light text
      // Based on vuetify-opts.mjs darkTheme
      Theme(
        backgroundColor: Color(red: 0.071, green: 0.071,
                               blue: 0.071), // #121212
        textColor: Color(red: 0.95, green: 0.95, blue: 0.95), // light text
        secondaryTextColor: Color(red: 0.7, green: 0.7,
                                  blue: 0.7), // light grey
        accentColor: COLOR_SAFFRON, // #ff9933
        cardBackground: Color(red: 0.133, green: 0.133, blue: 0.133), // #222222
        borderColor: Color(red: 0.3, green: 0.3, blue: 0.3), // dark grey
        valueColor: COLOR_CYAN, // #00ffff
        toolbarColor: COLOR_BROWN, // #795548
        debugForeground: COLOR_CYAN, // #00ffff
      )
    }
  }

  /// Return the inverse theme (light ↔ dark)
  public static func inverseTheme(_ theme: AppTheme) -> AppTheme {
    theme == .light ? .dark : .light
  }
}
