//
//  SettingsModalController.swift
//  scv-demo-ios
//
//  Created by Visakha on 04/11/2025.
//

import Combine
import scvCore
import scvUI
import SwiftUI

class SettingsModalController: NSObject, ObservableObject {
  let cc = ColorConsole(#file, "SettingsModalController", dbg.DemoIOSApp.other)
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
    docLang = settings.docLang
    refLang = settings.refLang
    uiLang = settings.uiLang
    isDarkModeEnabled = settings.isDarkModeEnabled
    paliVoiceId = settings.paliSpeech.voiceId
    docVoiceId = settings.docSpeech.voiceId
    paliPitch = settings.paliSpeech.pitch
    paliRate = settings.paliSpeech.rate
    docPitch = settings.docSpeech.pitch
    docRate = settings.docSpeech.rate

    originalDocLang = settings.docLang
    originalRefLang = settings.refLang
    originalUiLang = settings.uiLang
    originalIsDarkModeEnabled = settings.isDarkModeEnabled
    originalPaliVoiceId = settings.paliSpeech.voiceId
    originalDocVoiceId = settings.docSpeech.voiceId
    originalPaliPitch = settings.paliSpeech.pitch
    originalPaliRate = settings.paliSpeech.rate
    originalDocPitch = settings.docSpeech.pitch
    originalDocRate = settings.docSpeech.rate
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
    saveTimer = Timer
      .scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
        Task { @MainActor in
          guard let self else {
            return
          }
          guard self.pendingSave else {
            self.saveTimer?.invalidate()
            self.saveTimer = nil
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
