//
//  SliderSettingRow.swift
//  scv-ui
//
//  Created by Claude on 2025-12-31.
//

import scvCore
import SwiftUI

// MARK: - SliderSettingRow

/// A reusable row component for settings with an icon, label, slider, and value
/// display.
/// Automatically adapts layout based on accessibility size category.
public struct SliderSettingRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  @Environment(\.sizeCategory) var sizeCategory

  let icon: String
  let label: String
  let value: Binding<Double>
  let range: ClosedRange<Double>
  let step: Double
  let displayFormatter: (Double) -> String

  var shouldStackVertically: Bool {
    sizeCategory.isAccessibilityCategory
  }

  /// Initialize a SliderSettingRow
  /// - Parameters:
  ///   - icon: SF Symbol name for the row icon
  ///   - label: Localized label text
  ///   - value: Binding to the slider value (0.0 to 1.0)
  ///   - range: Range for slider (default: 0...1)
  ///   - step: Step increment for slider
  ///   - displayFormatter: Closure to format the displayed value
  public init(
    icon: String,
    label: String,
    value: Binding<Double>,
    in range: ClosedRange<Double> = 0.0 ... 1.0,
    step: Double = 0.1,
    displayFormatter: @escaping (Double)
      -> String = { String(format: "%.2f", $0) },
  ) {
    self.icon = icon
    self.label = label
    self.value = value
    self.range = range
    self.step = step
    self.displayFormatter = displayFormatter
  }

  public var body: some View {
    if shouldStackVertically {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Image(systemName: icon)
            .foregroundColor(themeProvider.theme.textColor
              .opacity(themeProvider.theme.iconOpacity))
          Text(label)
            .font(.body)
        }
        Slider(value: value, in: range, step: step)
        Text(displayFormatter(value.wrappedValue))
          .font(.caption)
          .foregroundColor(themeProvider.theme.secondaryTextColor)
      }
    } else {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .foregroundColor(themeProvider.theme.textColor
            .opacity(themeProvider.theme.iconOpacity))
        VStack(alignment: .leading, spacing: 4) {
          Text(label)
            .font(.body)
          Slider(value: value, in: range, step: step)
        }
        Text(displayFormatter(value.wrappedValue))
          .font(.caption)
          .foregroundColor(themeProvider.theme.secondaryTextColor)
          .frame(width: 50, alignment: .trailing)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  struct PreviewContainer: View {
    @State private var volume = 0.5
    @State private var pause = 0.3

    var body: some View {
      Form {
        Section("Audio") {
          SliderSettingRow(
            icon: "speaker.wave.2",
            label: "Sound Effects Volume",
            value: $volume,
            in: 0 ... 1,
            step: 0.25,
            displayFormatter: { Int($0 * 4) == 4 ? "Max" : String(Int($0 * 4))
            },
          )
          SliderSettingRow(
            icon: "waveform",
            label: "Segment Pause",
            value: $pause,
            in: 0 ... 1,
            step: 0.1,
            displayFormatter: { String(format: "%.2f", $0) + "s" },
          )
        }
      }
      .environmentObject(ThemeProvider())
    }
  }

  return PreviewContainer()
}
