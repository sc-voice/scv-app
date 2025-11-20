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
      HStack {
        Text("Voice")
        Spacer()
        Button(action: { showVoicePicker = true }) {
          Text(selectedVoiceName)
            .foregroundColor(themeProvider.theme.valueColor)
        }
      }
      .sheet(isPresented: $showVoicePicker) {
        Picker("Select Voice", selection: $selectedVoiceId) {
          Text("Default").tag("")
          ForEach(availableVoices, id: \.identifier) { voice in
            Text(voiceDisplayName(voice)).tag(voice.identifier)
          }
        }
        #if os(iOS)
        .pickerStyle(.wheel)
        .presentationDetents([.medium])
        #else
        .pickerStyle(.menu)
        #endif
      }

      DisclosureGroup("Customize...", isExpanded: $showCustomization) {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Pitch")
            Slider(value: $pitch, in: 0.5 ... 2.0, step: 0.1)
            Text(String(format: "%.1f", pitch))
              .foregroundColor(themeProvider.theme.valueColor)
              .frame(width: 35)
          }

          HStack {
            Text("Rate")
            Slider(value: $rate, in: 0.1 ... 2.0, step: 0.1)
            Text(String(format: "%.1f", rate))
              .foregroundColor(themeProvider.theme.valueColor)
              .frame(width: 35)
          }
        }
      }
    }
  }
}
