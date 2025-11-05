//
//  SettingsView.swift
//  scv-demo-ios
//
//  Created by Visakha on 04/11/2025.
//

import SwiftUI
import AVFoundation
import Combine
import scvCore
import scvUI

// MARK: - SettingsModalController

class SettingsModalController: NSObject, ObservableObject {
  @Published var docLang: ScvLanguage {
    didSet { autosave() }
  }
  @Published var refLang: ScvLanguage {
    didSet { autosave() }
  }
  @Published var uiLang: ScvLanguage {
    didSet { autosave() }
  }
  @Published var isDarkModeEnabled: Bool {
    didSet { autosave() }
  }
  @Published var paliVoiceId: String {
    didSet { autosave() }
  }
  @Published var docVoiceId: String {
    didSet { autosave() }
  }
  @Published var paliPitch: Float {
    didSet { autosave() }
  }
  @Published var paliRate: Float {
    didSet { autosave() }
  }
  @Published var docPitch: Float {
    didSet { autosave() }
  }
  @Published var docRate: Float {
    didSet { autosave() }
  }

  private let originalDocLang: ScvLanguage
  private let originalRefLang: ScvLanguage
  private let originalUiLang: ScvLanguage
  private let originalIsDarkModeEnabled: Bool
  private let originalPaliVoiceId: String
  private let originalDocVoiceId: String
  private let originalPaliPitch: Float
  private let originalPaliRate: Float
  private let originalDocPitch: Float
  private let originalDocRate: Float

  private var pendingSave = false
  private var saveTimer: Timer?

  init(from settings: Settings) {
    self.docLang = settings.docLang
    self.refLang = settings.refLang
    self.uiLang = settings.uiLang
    self.isDarkModeEnabled = settings.isDarkModeEnabled
    self.paliVoiceId = settings.paliSpeech.voiceId
    self.docVoiceId = settings.docSpeech.voiceId
    self.paliPitch = settings.paliSpeech.pitch
    self.paliRate = settings.paliSpeech.rate
    self.docPitch = settings.docSpeech.pitch
    self.docRate = settings.docSpeech.rate

    self.originalDocLang = settings.docLang
    self.originalRefLang = settings.refLang
    self.originalUiLang = settings.uiLang
    self.originalIsDarkModeEnabled = settings.isDarkModeEnabled
    self.originalPaliVoiceId = settings.paliSpeech.voiceId
    self.originalDocVoiceId = settings.docSpeech.voiceId
    self.originalPaliPitch = settings.paliSpeech.pitch
    self.originalPaliRate = settings.paliSpeech.rate
    self.originalDocPitch = settings.docSpeech.pitch
    self.originalDocRate = settings.docSpeech.rate
  }

  private func autosave() {
    // Always update in-memory settings for live player reads
    Settings.shared.docLang = docLang
    Settings.shared.refLang = refLang
    Settings.shared.uiLang = uiLang
    Settings.shared.isDarkModeEnabled = isDarkModeEnabled
    Settings.shared.paliSpeech.voiceId = paliVoiceId
    Settings.shared.docSpeech.voiceId = docVoiceId
    Settings.shared.paliSpeech.pitch = paliPitch
    Settings.shared.paliSpeech.rate = paliRate
    Settings.shared.docSpeech.pitch = docPitch
    Settings.shared.docSpeech.rate = docRate

    // Only write to UserDefaults if audio is not playing
    if !SuttaPlayer.shared.isPlaying {
      Settings.shared.save()
      pendingSave = false
    } else {
      // Mark for deferred save and schedule check
      pendingSave = true
      scheduleDeferredSave()
    }
  }

  private func scheduleDeferredSave() {
    saveTimer?.invalidate()
    saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self = self, self.pendingSave else {
        self?.saveTimer?.invalidate()
        self?.saveTimer = nil
        return
      }

      if !SuttaPlayer.shared.isPlaying {
        Settings.shared.save()
        self.pendingSave = false
        self.saveTimer?.invalidate()
        self.saveTimer = nil
      }
    }
  }

  func resetToDefaults() {
    // Reset to app defaults, not session originals
    docLang = .default
    refLang = .default
    uiLang = .default
    isDarkModeEnabled = true
    paliVoiceId = ""
    docVoiceId = ""
    paliPitch = 1.0
    paliRate = 1.0
    docPitch = 1.0
    docRate = 1.0
  }
}

// MARK: - SettingsView

struct SettingsView: View {
  @ObservedObject var controller: SettingsModalController
  @Environment(\.dismiss) var dismiss
  @State private var showResetConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Settings")
          .font(.headline)
        Spacer()
        Button(action: { dismiss() }) {
          Image(systemName: "xmark")
            .font(.body)
            .foregroundColor(.gray)
        }
      }
      .padding()
      .borderBottom()

      Form {
        // MARK: - Languages Section

        Section("Languages") {
          Picker("Document Language", selection: $controller.docLang) {
            ForEach(ScvLanguage.allCases, id: \.self) { lang in
              Text(lang.displayName).tag(lang)
            }
          }

          Picker("Reference Language", selection: $controller.refLang) {
            ForEach(ScvLanguage.allCases, id: \.self) { lang in
              Text(lang.displayName).tag(lang)
            }
          }

          Picker("UI Language", selection: $controller.uiLang) {
            ForEach(ScvLanguage.uiLanguages, id: \.self) { lang in
              Text(lang.displayName).tag(lang)
            }
          }
        }

        // MARK: - Appearance Section

        Section("Appearance") {
          Toggle("Dark Mode", isOn: $controller.isDarkModeEnabled)
        }

        // MARK: - Pali Voice Section

        Section("Pali Narration Voice") {
          VoicePickerView(
            selectedVoiceId: $controller.paliVoiceId,
            pitch: $controller.paliPitch,
            rate: $controller.paliRate,
            language: .pli
          )
        }

        // MARK: - Document Voice Section

        Section("Document Narration Voice") {
          VoicePickerView(
            selectedVoiceId: $controller.docVoiceId,
            pitch: $controller.docPitch,
            rate: $controller.docRate,
            language: controller.docLang
          )
        }

        // MARK: - Reset Button Section

        Section {
          Button("Reset Settings", role: .destructive) {
            showResetConfirmation = true
          }
        }
      }
    }
    .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
      Button("Reset", role: .destructive) {
        controller.resetToDefaults()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will restore all settings to their default values.")
    }
  }
}

// MARK: - Helper Extension

extension View {
  func borderBottom() -> some View {
    self.overlay(alignment: .bottom) {
      Divider()
    }
  }
}

// MARK: - VoicePickerView

struct VoicePickerView: View {
  @Binding var selectedVoiceId: String
  @Binding var pitch: Float
  @Binding var rate: Float
  let language: ScvLanguage

  var availableVoices: [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { voice in
        guard let voiceLanguage = ScvLanguage.toVoiceLanguage(voice.language) else {
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
    availableVoices.first(where: { $0.identifier == selectedVoiceId })?.name ?? "Default"
  }

  func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
    let quality = voice.quality.rawValue
    return "\(voice.name) (\(quality))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker("Voice", selection: $selectedVoiceId) {
        Text("Default").tag("")
        ForEach(availableVoices, id: \.identifier) { voice in
          Text(voiceDisplayName(voice)).tag(voice.identifier)
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Pitch")
          Slider(value: $pitch, in: 0.5...2.0, step: 0.1)
          Text(String(format: "%.1f", pitch))
            .frame(width: 35)
        }

        HStack {
          Text("Rate")
          Slider(value: $rate, in: 0.1...2.0, step: 0.1)
          Text(String(format: "%.1f", rate))
            .frame(width: 35)
        }
      }
    }
  }
}

#Preview {
  SettingsView(controller: SettingsModalController(from: Settings.shared))
}
