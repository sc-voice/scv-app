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
    didSet {
      if oldValue != docLang {
        // Save old language settings before switching
        saveDocLangSettings(for: oldValue)
        // Load new language settings
        loadDocLangSettings(for: docLang)
      }
      autosave()
    }
  }

  @Published var refLang: ScvLanguage {
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

  @Published var docAuthor: String {
    didSet { autosave() }
  }

  @Published var segmentPause: Double {
    didSet { autosave() }
  }

  @Published var playPali: Bool {
    didSet { autosave() }
  }

  @Published var playDoc: Bool {
    didSet { autosave() }
  }

  @Published var showPali: Bool {
    didSet { autosave() }
  }

  @Published var showDoc: Bool {
    didSet { autosave() }
  }

  @Published var showRef: Bool {
    didSet { autosave() }
  }

  @Published var soundEffectVolume: Float {
    didSet { autosave() }
  }

  @Published var maxColumnWidth: CGFloat {
    didSet { autosave() }
  }

  private let originalDocLang: ScvLanguage
  private let originalRefLang: ScvLanguage
  private let originalIsDarkModeEnabled: Bool
  private let originalPaliVoiceId: String
  private let originalDocVoiceId: String
  private let originalPaliPitch: Float
  private let originalPaliRate: Float
  private let originalDocPitch: Float
  private let originalDocRate: Float
  private let originalSegmentPause: Double

  private var pendingSave = false
  private var saveTimer: Timer?
  private var isAutoSaving = false

  public init(from settings: scvCore.Settings) {
    docLang = settings.docLang
    refLang = settings.refLang
    isDarkModeEnabled = settings.isDarkModeEnabled
    paliVoiceId = settings.paliSettings.voiceId
    docVoiceId = settings.docLangSettings[settings.docLang]?.voiceId ?? ""
    paliPitch = settings.paliSettings.pitch
    paliRate = settings.paliSettings.rate
    docPitch = settings.docLangSettings[settings.docLang]?.pitch ?? 1.0
    docRate = settings.docLangSettings[settings.docLang]?.rate ?? 1.0
    docAuthor = settings.docLangSettings[settings.docLang]?.author ?? ""
    segmentPause = settings.segmentPause
    playPali = settings.playPali
    playDoc = settings.playDoc
    showPali = settings.showPali
    showDoc = settings.showDoc
    showRef = settings.showRef
    soundEffectVolume = settings.soundEffectVolume
    maxColumnWidth = settings.maxColumnWidth

    originalDocLang = settings.docLang
    originalRefLang = settings.refLang
    originalIsDarkModeEnabled = settings.isDarkModeEnabled
    originalPaliVoiceId = settings.paliSettings.voiceId
    originalDocVoiceId = settings.docLangSettings[settings.docLang]?
      .voiceId ?? ""
    originalPaliPitch = settings.paliSettings.pitch
    originalPaliRate = settings.paliSettings.rate
    originalDocPitch = settings.docLangSettings[settings.docLang]?.pitch ?? 1.0
    originalDocRate = settings.docLangSettings[settings.docLang]?.rate ?? 1.0
    originalSegmentPause = settings.segmentPause
  }

  private func autosave() {
    guard !isAutoSaving else { return }
    isAutoSaving = true
    defer { isAutoSaving = false }

    // Always update in-memory settings for live player reads
    let langChanged = Settings.shared.docLang != docLang
      || Settings.shared.refLang != refLang
    Settings.shared.docLang = docLang
    Settings.shared.refLang = refLang
    Settings.shared.isDarkModeEnabled = isDarkModeEnabled
    Settings.shared.paliSettings.voiceId = paliVoiceId
    Settings.shared.paliSettings.pitch = paliPitch
    Settings.shared.paliSettings.rate = paliRate
    Settings.shared.segmentPause = segmentPause
    Settings.shared.playPali = playPali
    Settings.shared.playDoc = playDoc
    Settings.shared.showPali = showPali
    Settings.shared.showDoc = showDoc
    Settings.shared.showRef = showRef
    Settings.shared.soundEffectVolume = soundEffectVolume
    Settings.shared.maxColumnWidth = maxColumnWidth

    // Update docLangSettings for current language
    if Settings.shared.docLangSettings[docLang] == nil {
      Settings.shared.docLangSettings[docLang] = LangSettings(language: docLang)
    }
    Settings.shared.docLangSettings[docLang]?.voiceId = docVoiceId
    Settings.shared.docLangSettings[docLang]?.pitch = docPitch
    Settings.shared.docLangSettings[docLang]?.rate = docRate
    Settings.shared.docLangSettings[docLang]?.author = docAuthor

    // If language changed, validate to ensure docAuthor/refAuthor are valid for
    // the new language
    if langChanged {
      Settings.shared.validate()
      // Sync back any changes validate() made (e.g., fallback to english if no
      // voice available, or docAuthor changed to default for new language)
      docLang = Settings.shared.docLang
      refLang = Settings.shared.refLang
      docAuthor = Settings.shared.docLangSettings[Settings.shared.docLang]?
        .author ?? ""
    }

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

  private func saveDocLangSettings(for language: ScvLanguage) {
    // Save current docAuthor/docVoiceId/docPitch/docRate for the language being
    // left
    if Settings.shared.docLangSettings[language] == nil {
      Settings.shared
        .docLangSettings[language] = LangSettings(language: language)
    }
    Settings.shared.docLangSettings[language]?.author = docAuthor
    Settings.shared.docLangSettings[language]?.voiceId = docVoiceId
    Settings.shared.docLangSettings[language]?.pitch = docPitch
    Settings.shared.docLangSettings[language]?.rate = docRate
  }

  private func loadDocLangSettings(for language: ScvLanguage) {
    // Load docAuthor/docVoiceId/docPitch/docRate for the new language
    if let langSettings = Settings.shared.docLangSettings[language] {
      // Use previously saved settings for this language
      docAuthor = langSettings.author
      docVoiceId = langSettings.voiceId
      docPitch = langSettings.pitch
      docRate = langSettings.rate
    } else {
      // First time selecting this language, use defaults from manifest
      if let defaultInfo = DatabaseManifest.shared
        .defaultAuthorForLanguage(language.code)
      {
        docAuthor = defaultInfo.author
      } else {
        docAuthor = ""
      }
      docVoiceId = ""
      docPitch = 1.0
      docRate = 1.0
    }
  }

  func resetToDefaults() {
    // Reset docLang to system language or english if system language has no DB
    if let preferredLanguage = Locale.preferredLanguages.first,
       let systemLanguage = ScvLanguage.toVoiceLanguage(preferredLanguage),
       EbtData.authorsForLanguageFromManifest(systemLanguage.code).count > 0
    {
      docLang = systemLanguage
    } else {
      docLang = .english
    }

    // Set docAuthor to default author for the new docLang
    if let defaultInfo = DatabaseManifest.shared
      .defaultAuthorForLanguage(docLang.code)
    {
      docAuthor = defaultInfo.author
    } else {
      docAuthor = ""
    }

    refLang = .default
    isDarkModeEnabled = true
    paliVoiceId = ""
    docVoiceId = ""
    paliPitch = 1.0
    paliRate = 1.0
    docPitch = 1.0
    docRate = 1.0
    segmentPause = SEGMENT_PAUSE_DEFAULT
    playPali = false
    playDoc = true
    showPali = false
    showDoc = true
    showRef = false
    soundEffectVolume = SOUND_EFFECT_VOLUME_DEFAULT
    maxColumnWidth = (MIN_COLUMN_WIDTH + MAX_COLUMN_WIDTH) / 2
  }
}
