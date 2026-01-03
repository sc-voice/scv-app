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
    let allVoicesForLanguage = AVSpeechSynthesisVoice.speechVoices()
      .filter { voice in
        guard let voiceLanguage = ScvLanguage.toVoiceLanguage(voice.language)
        else {
          return false
        }
        return voiceLanguage == language
          && !voice.voiceTraits.contains(.isNoveltyVoice)
      }

    // If enhanced or premium voices available, exclude default quality voices
    let hasEnhancedOrPremium = allVoicesForLanguage.contains { voice in
      voice.quality == .enhanced || voice.quality == .premium
    }

    let filtered = hasEnhancedOrPremium
      ? allVoicesForLanguage.filter { $0.quality != .default }
      : allVoicesForLanguage

    return filtered.sorted { a, b in
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
            HStack(spacing: 8) {
              Image(systemName: "speaker.fill")
                .foregroundColor(themeProvider.theme.secondaryTextColor
                  .opacity(themeProvider.theme.iconOpacity))
                .frame(minWidth: 44)
              Text("Voice")
                .foregroundColor(themeProvider.theme.textColor)
            }
            Button(action: { showVoicePicker = true }) {
              Text(selectedVoiceName)
                .foregroundColor(themeProvider.theme.valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        } else {
          HStack {
            Image(systemName: "speaker.fill")
              .foregroundColor(themeProvider.theme.secondaryTextColor
                .opacity(themeProvider.theme.iconOpacity))
              .frame(minWidth: 44)
            Text("Voice")
              .foregroundColor(themeProvider.theme.textColor)
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
    }
  }
}
