//
//  SettingsModalController.swift
//  scv-ui
//
//  Created by Visakha on 20/11/2025.
//

import Combine
import scvCore
import SwiftUI

@MainActor
public class SettingsModalController: NSObject, ObservableObject {
  let cc = ColorConsole(#file, "SettingsModalController", dbg.Settings.other)
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

  public init(from settings: scvCore.Settings) {
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

    // Schedule deferred save to check playback state
    scheduleDeferredSave()
  }

  private func scheduleDeferredSave() {
    // IMPORTANT: pendingSave must be set to true for Settings.shared.save() to execute.
    // Without this flag, the guard statement at line 118 prevents save() from
    // being called,
    // causing settings changes to remain in-memory only and never persist to
    // disk.
    // NOTE: This bug is hard to test via unit tests because:
    // - In-memory Settings.shared updates happen in autosave() regardless
    // - Disk persistence (Settings.shared.save()) can only be verified by
    // mocking
    // - Tests cannot easily verify file I/O without complex test infrastructure
    pendingSave = true
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
