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
  public let toolbarBackground: Color

  public let toolbarForeground: Color

  /// Error text color
  public let errorTextColor: Color

  /// Debug text color (only visible in debug builds)
  public let debugForeground: Color

  /// Link color
  public let linkColor: Color

  /// Opacity for annotational (non-interactive) icons
  public let iconOpacity: Double

  /// Background color for tip modals
  public let tipBackground: Color

  /// Foreground (text/icon) color for tip modals
  public let tipForeground: Color

  /// Focus ring color for keyboard navigation indicators
  public let focusColor: Color

  /// Sidebar item text color
  public let sideItemForeground: Color

  /// Sidebar item background color
  public let sideItemBackground: Color

  /// Sidebar active item text color
  public let sideItemActiveForeground: Color

  /// Sidebar active item background color
  public let sideItemActiveBackground: Color

  public init(
    backgroundColor: Color,
    textColor: Color,
    secondaryTextColor: Color,
    accentColor: Color,
    cardBackground: Color,
    borderColor: Color,
    valueColor: Color,
    toolbarBackground: Color,
    toolbarForeground: Color,
    errorTextColor: Color,
    debugForeground: Color,
    linkColor: Color,
    sideItemActiveBackground: Color,
    sideItemActiveForeground: Color,
    sideItemBackground: Color,
    sideItemForeground: Color,
    focusColor: Color = .blue,
    iconOpacity: Double = 0.8,
    tipBackground: Color,
    tipForeground: Color,
  ) {
    self.backgroundColor = backgroundColor
    self.textColor = textColor
    self.secondaryTextColor = secondaryTextColor
    self.accentColor = accentColor
    self.cardBackground = cardBackground
    self.borderColor = borderColor
    self.valueColor = valueColor
    self.toolbarBackground = toolbarBackground
    self.toolbarForeground = toolbarForeground
    self.errorTextColor = errorTextColor
    self.debugForeground = debugForeground
    self.linkColor = linkColor
    self.sideItemForeground = sideItemForeground
    self.sideItemBackground = sideItemBackground
    self.sideItemActiveForeground = sideItemActiveForeground
    self.sideItemActiveBackground = sideItemActiveBackground
    self.focusColor = focusColor
    self.iconOpacity = iconOpacity
    self.tipBackground = tipBackground
    self.tipForeground = tipForeground
  }
}

// MARK: - Theme Definitions

/// Saffron color used in dark theme
private let COLOR_SAFFRON = Color(red: 1.0, green: 0.6, blue: 0.2) // #ff9933

/// Dark brown accent for light theme (WCAG AA compliant)
private let COLOR_BROWN_ACCENT = Color(red: 0.545, green: 0.271,
                                       blue: 0.075) // #8b4513

/// Cyan color for user-mutable values in dark theme
private let COLOR_CYAN = Color(red: 0.0, green: 1.0, blue: 1.0) // #00ffff

/// Dark teal color for light theme value display (WCAG AA compliant)
private let COLOR_TEAL_DARK = Color(red: 0.024, green: 0.373,
                                    blue: 0.451) // #065f73

/// Brown color for toolbar (dark theme)
private let COLOR_BROWN = Color(red: 0.243, green: 0.161,
                                blue: 0.141) // #3E2723

/// Grey color for toolbar (light theme)
private let COLOR_GREY = Color(red: 0.741, green: 0.741, blue: 0.741) // #BDBDBD

/// Dark saffron color for toolbar (dark theme - much darker variant of
/// COLOR_SAFFRON)
private let COLOR_TOOLBAR_SAFFRON = Color(red: 0.35, green: 0.21,
                                          blue: 0.07) // #593611

/// Fuchsia color for debug text (light theme)
private let COLOR_FUCHSIA = Color(red: 1.0, green: 0.0, blue: 1.0) // #FF00FF

/// Bright red color for errors (dark theme)
private let COLOR_ERROR_BRIGHT = Color(red: 1.0, green: 0.2,
                                       blue: 0.2) // #FF3333

/// Dark red color for errors (light theme)
private let COLOR_ERROR_DARK = Color(red: 0.8, green: 0.0, blue: 0.0) // #CC0000

// momochrome dark palette
private let COLOR_DARK_BACKGROUND1 = Color(
  red: 0.071,
  green: 0.071,
  blue: 0.071,
)

private let COLOR_DARK_BACKGROUND2 = Color(red: 0.2, green: 0.2, blue: 0.2)

private let COLOR_DARK_FOREGROUND1 = Color(red: 0.95, green: 0.95, blue: 0.95)

private let COLOR_DARK_FOREGROUND2 = Color(red: 0.7, green: 0.7, blue: 0.7)

/// Dark green background for tip modals (theme-independent)
private let COLOR_TIP_BACKGROUND = Color(red: 0.106, green: 0.302,
                                         blue: 0.180) // #1B4D2E

/// Bright yellow foreground for tip modals (theme-independent)
private let COLOR_TIP_FOREGROUND = Color(red: 1.0, green: 1.0,
                                         blue: 0.8) // #FFE000

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
      // Uses darker accent and value colors for WCAG AA contrast compliance
      Theme(
        backgroundColor: Color(red: 0.933, green: 0.933, blue: 0.933),
        textColor: Color(red: 0.1, green: 0.1, blue: 0.1), // dark text
        secondaryTextColor: Color(red: 0.3, green: 0.3,
                                  blue: 0.3), // medium grey
        accentColor: COLOR_BROWN_ACCENT, // #8b4513 (4.91:1 contrast ratio)
        cardBackground: Color(red: 0.8, green: 0.8, blue: 0.8),
        borderColor: Color(red: 0.9, green: 0.9, blue: 0.9), // light grey
        valueColor: COLOR_TEAL_DARK, // #065f73 (5.02:1 contrast ratio)
        toolbarBackground: COLOR_TOOLBAR_SAFFRON,
        toolbarForeground: COLOR_DARK_FOREGROUND1,
        errorTextColor: COLOR_ERROR_DARK, // #CC0000
        debugForeground: COLOR_FUCHSIA, // #FF00FF
        linkColor: COLOR_BROWN_ACCENT, // #8b4513 (same as accentColor)
        sideItemActiveBackground: COLOR_DARK_BACKGROUND1,
        sideItemActiveForeground: COLOR_DARK_FOREGROUND1,
        sideItemBackground: COLOR_DARK_BACKGROUND2,
        sideItemForeground: COLOR_DARK_FOREGROUND2,
        focusColor: .blue,
        iconOpacity: 0.8,
        tipBackground: COLOR_TIP_BACKGROUND,
        tipForeground: COLOR_TIP_FOREGROUND,
      )
    case .dark:
      // Dark theme: dark backgrounds with light text
      // Based on vuetify-opts.mjs darkTheme
      Theme(
        backgroundColor: COLOR_DARK_BACKGROUND1,
        textColor: COLOR_DARK_FOREGROUND1,
        secondaryTextColor: COLOR_DARK_FOREGROUND2,
        accentColor: COLOR_SAFFRON, // #ff9933
        cardBackground: Color(red: 0.2, green: 0.2, blue: 0.2),
        borderColor: Color(red: 0.3, green: 0.3, blue: 0.3), // dark grey
        valueColor: COLOR_CYAN, // #00ffff
        toolbarBackground: COLOR_TOOLBAR_SAFFRON, // #cc7a29
        toolbarForeground: COLOR_DARK_FOREGROUND1,
        errorTextColor: COLOR_ERROR_BRIGHT, // #FF3333
        debugForeground: COLOR_FUCHSIA, // #FF00FF
        linkColor: COLOR_SAFFRON, // #ff9933 (same as accentColor)
        sideItemActiveBackground: COLOR_DARK_BACKGROUND1,
        sideItemActiveForeground: COLOR_DARK_FOREGROUND1,
        sideItemBackground: COLOR_DARK_BACKGROUND2,
        sideItemForeground: COLOR_DARK_FOREGROUND2,
        focusColor: .blue,
        iconOpacity: 0.8,
        tipBackground: COLOR_TIP_BACKGROUND,
        tipForeground: COLOR_TIP_FOREGROUND,
      )
    }
  }

  /// Return the inverse theme (light ↔ dark)
  public static func inverseTheme(_ theme: AppTheme) -> AppTheme {
    theme == .light ? .dark : .light
  }
}
