//
//  VoicePickerView.swift
//  scv-ui
//
//  Created by Visakha on 20/11/2025.
//

import AVFoundation
import scvCore
import SwiftUI

// MARK: - VoicePickerView

struct VoicePickerView: View {
  @Binding var selectedVoiceId: String
  @Binding var pitch: Float
  @Binding var rate: Float
  let language: ScvLanguage
  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var showVoicePicker = false
  @State private var showCustomization = false
  @Environment(\.sizeCategory) var sizeCategory

  var pickerDetent: Set<PresentationDetent> {
    sizeCategory.isAccessibilityCategory ? [.fraction(0.95)] : [.medium]
  }

  var pickerHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 400 : 250
  }

  var shouldStackVertically: Bool {
    sizeCategory.isAccessibilityCategory
  }

  var availableVoices: [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { voice in
        guard let voiceLanguage = ScvLanguage.toVoiceLanguage(voice.language)
        else {
          return false
        }
        return voiceLanguage == language
          && !voice.voiceTraits.contains(.isNoveltyVoice)
      }
      .sorted { a, b in
        if a.quality.rawValue != b.quality.rawValue {
          return a.quality.rawValue > b.quality.rawValue
        }
        return a.name < b.name
      }
  }

  var selectedVoiceName: String {
    availableVoices.first(where: { $0.identifier == selectedVoiceId })?
      .name ?? "Default"
  }

  func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
    let quality = voice.quality.rawValue
    return "\(voice.name) (\(quality))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Group {
        if shouldStackVertically {
          VStack(alignment: .leading, spacing: 8) {
            Text("Voice")
            Button(action: { showVoicePicker = true }) {
              Text(selectedVoiceName)
                .foregroundColor(themeProvider.theme.valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        } else {
          HStack {
            Text("Voice")
            Spacer()
            Button(action: { showVoicePicker = true }) {
              Text(selectedVoiceName)
                .foregroundColor(themeProvider.theme.valueColor)
            }
          }
        }
      }
      .sheet(isPresented: $showVoicePicker) {
        VStack {
          Picker("Select Voice", selection: $selectedVoiceId) {
            Text("Default")
              .font(.body)
              .tag("")
            ForEach(availableVoices, id: \.identifier) { voice in
              Text(voiceDisplayName(voice))
                .font(.body)
                .tag(voice.identifier)
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

      DisclosureGroup("settings.customize".localized, isExpanded: $showCustomization) {
        VStack(alignment: .leading, spacing: 8) {
          if shouldStackVertically {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Image(systemName: "mountain.2")
                  .foregroundColor(themeProvider.theme.accentColor)
                Text("settings.pitch".localized)
                  .font(.body)
              }
              Slider(value: $pitch, in: 0.5 ... 2.0, step: 0.1)
              Text(String(format: "%.1f", pitch))
                .font(.caption)
                .foregroundColor(themeProvider.theme.valueColor)
            }
          } else {
            HStack {
              Image(systemName: "mountain.2")
                .foregroundColor(themeProvider.theme.accentColor)
              VStack(alignment: .leading, spacing: 4) {
                Text("settings.pitch".localized)
                  .font(.body)
                Slider(value: $pitch, in: 0.5 ... 2.0, step: 0.1)
              }
              Text(String(format: "%.1f", pitch))
                .foregroundColor(themeProvider.theme.valueColor)
                .frame(width: 35)
            }
          }

          if shouldStackVertically {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Image(systemName: "hare")
                  .foregroundColor(themeProvider.theme.accentColor)
                Text("settings.rate".localized)
                  .font(.body)
              }
              Slider(value: $rate, in: 0.1 ... 2.0, step: 0.1)
              Text(String(format: "%.1f", rate))
                .font(.caption)
                .foregroundColor(themeProvider.theme.valueColor)
            }
          } else {
            HStack {
              Image(systemName: "hare")
                .foregroundColor(themeProvider.theme.accentColor)
              VStack(alignment: .leading, spacing: 4) {
                Text("settings.rate".localized)
                  .font(.body)
                Slider(value: $rate, in: 0.1 ... 2.0, step: 0.1)
              }
              Text(String(format: "%.1f", rate))
                .foregroundColor(themeProvider.theme.valueColor)
                .frame(width: 35)
            }
          }
        }
      }
    }
  }
}
