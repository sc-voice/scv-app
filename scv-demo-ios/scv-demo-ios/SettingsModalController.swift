//
//  SettingsModalController.swift
//  scv-demo-ios
//
//  Created by Visakha on 04/11/2025.
//

import SwiftUI
import Combine
import scvCore
import scvUI

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
