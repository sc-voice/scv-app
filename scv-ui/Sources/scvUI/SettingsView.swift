//
//  SettingsView.swift
//  scv-ui
//
//  Created by Visakha on 20/11/2025.
//

import AVFoundation
import Combine
import scvCore
import SwiftUI

// MARK: - SettingsView

public struct SettingsView: View {
  let cc = ColorConsole(#file, "SettingsView", dbg.Settings.other)
  @ObservedObject public var controller: SettingsModalController
  @EnvironmentObject var themeProvider: ThemeProvider
  @Environment(\.dismiss) var dismiss
  @State private var isLoading = true
  @State private var showResetConfirmation = false
  @State private var showClearAudioConfirmation = false
  @State private var showDocLangPicker = false
  @State private var showDocAuthorPicker = false
  @State private var showRefLangPicker = false
  @State private var expandedSection: String? = "languages"
  @State private var audioStoreDiskSize: Int = 0
  @State private var isLoadingDiskSize = true
  @State private var showBackgroundPlaybackInfo = false

  private func toggleSection(_ section: String) {
    if expandedSection == section {
      expandedSection = nil
    } else {
      expandedSection = section
    }
  }

  private func formatDiskSize(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }

  public init(controller: SettingsModalController) {
    _controller = ObservedObject(wrappedValue: controller)
  }

  var availableDocAuthors: [DatabaseInfo] {
    EbtData.authorsForLanguageFromManifest(controller.docLang.code)
      .sorted { $0.files.total > $1.files.total }
  }

  var docAuthorName: String {
    availableDocAuthors.first { $0.author == controller.docAuthor }?.authorName
      ?? controller.docAuthor
  }

  var sortedLanguages: [ScvLanguage] {
    let availableLangCodes = Set(DatabaseManifest.shared.availableLanguages())
    return ScvLanguage.allCases.filter { availableLangCodes.contains($0.code) }
      .sorted { $0.code < $1.code }
  }

  public var body: some View {
    ZStack {
      themeProvider.theme.backgroundColor
        .opacity(0.2)

      VStack(spacing: 0) {
        HStack {
          Text("settings.title".localized)
            .font(.headline)
            .foregroundStyle(themeProvider.theme.textColor)
          Spacer()
          Button(action: { dismiss() }) {
            Image(systemName: "xmark")
              .font(.body)
              .foregroundColor(themeProvider.theme.textColor)
              .frame(minWidth: 44, minHeight: 44)
          }
        }
        .padding()
        .background(themeProvider.theme.cardBackground)
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(themeProvider.theme.borderColor)
            .frame(height: 0.5)
        }

        if isLoading {
          ScvProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeProvider.theme.backgroundColor)
        } else {
          ScrollView {
            VStack(spacing: 2) {
              // MARK: - Languages Section

              CollapsibleSection(
                "settings.languages".localized,
                isExpanded: Binding(
                  get: { expandedSection == "languages" },
                  set: { _ in toggleSection("languages") },
                ),
                summary: {
                  VStack(alignment: .trailing, spacing: 0) {
                    Text(controller.docLang.code.uppercased())
                      .lineLimit(1)
                    Text(docAuthorName)
                      .font(.system(.caption2))
                      .lineLimit(1)
                  }
                },
              ) {
                LanguagesSectionContent(
                  controller: controller,
                  availableDocAuthors: availableDocAuthors,
                  sortedLanguages: sortedLanguages,
                  showDocLangPicker: $showDocLangPicker,
                  showDocAuthorPicker: $showDocAuthorPicker,
                  showRefLangPicker: $showRefLangPicker,
                )
              }

              // MARK: - Display Section

              CollapsibleSection(
                "settings.display".localized,
                isExpanded: Binding(
                  get: { expandedSection == "display" },
                  set: { _ in toggleSection("display") },
                ),
                summary: {
                  VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 4) {
                      if controller.showPali {
                        Text("PLI")
                      }
                      if controller.showPali, controller.showDoc {
                        Text("/")
                      }
                      if controller.showDoc {
                        Text(controller.docLang.code.uppercased())
                      }
                      if controller.showPali || controller.showDoc,
                         controller.showRef
                      {
                        Text("/")
                      }
                      if controller.showRef {
                        Text("REF")
                      }
                    }
                    .lineLimit(1)
                    Text(controller.isDarkModeEnabled ? "settings.dark".localized : "settings.light".localized)
                      .font(.system(.caption2))
                  }
                },
              ) {
                DisplaySectionContent(
                  controller: controller,
                )
              }

              // MARK: - Audio Section

              CollapsibleSection(
                "settings.audio".localized,
                isExpanded: Binding(
                  get: { expandedSection == "audio" },
                  set: { _ in toggleSection("audio") },
                ),
                summary: {
                  VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 4) {
                      if controller.showPali {
                        Text("PLI")
                      }
                      if controller.showPali, controller.showDoc {
                        Text("/")
                      }
                      if controller.showDoc {
                        Text(controller.docLang.code.uppercased())
                      }
                    }
                    .lineLimit(1)
                    Text(AudioSectionContent
                      .voiceName(for: controller.docVoiceId))
                      .font(.system(.caption2))
                  }
                },
              ) {
                AudioSectionContent(
                  controller: controller,
                  showBackgroundPlaybackInfo: $showBackgroundPlaybackInfo,
                )
              }

              // MARK: - Advanced Section

              CollapsibleSection(
                "Advanced",
                isExpanded: Binding(
                  get: { expandedSection == "advanced" },
                  set: { _ in toggleSection("advanced") },
                ),
              ) {
                VStack(alignment: .leading, spacing: 12) {
                  // Audio Store Disk Size
                  HStack {
                    Image(systemName: "internaldrive")
                      .foregroundColor(themeProvider.theme.secondaryTextColor
                        .opacity(themeProvider.theme.iconOpacity))
                      .frame(minWidth: 44)
                    VStack(alignment: .leading, spacing: 2) {
                      Text("settings.audio.store".localized)
                        .font(.body)
                        .foregroundColor(themeProvider.theme.textColor)
                      if isLoadingDiskSize {
                        Text("settings.loading".localized)
                          .font(.system(.caption2))
                          .foregroundColor(themeProvider.theme
                            .secondaryTextColor)
                      } else {
                        Text(formatDiskSize(audioStoreDiskSize))
                          .font(.system(.caption2))
                          .foregroundColor(themeProvider.theme
                            .secondaryTextColor)
                      }
                    }
                    Spacer()
                    Button(role: .destructive) {
                      showClearAudioConfirmation = true
                    } label: {
                      Label(
                        "settings.clear.audio.button".localized,
                        systemImage: "trash.fill",
                      )
                    }
                    .labelStyle(.iconOnly)
                  }

                  Divider()
                    .padding(.vertical, 4)

                  Button(
                    "settings.reset.button".localized,
                    role: .destructive,
                  ) {
                    showResetConfirmation = true
                  }
                }
              }
            }
            .padding()
          }
          .scrollContentBackground(.hidden)
        }
      } // VStack

      if isLoading {
        ScvProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.black.opacity(1.0))
      }
    } // ZStack
    .background(ScvBackgroundsView(.village))
    .onChange(of: showResetConfirmation) {
      if showResetConfirmation {
        cc.ok2(#line, "alert(Reset All Settings) presenting")
      }
    }
    .alert(
      "settings.reset.alert.title".localized,
      isPresented: $showResetConfirmation,
    ) {
      Button(
        "alert.reset".localized,
        role: .destructive,
      ) {
        controller.resetToDefaults()
        themeProvider.setTheme(.dark)
      }
      Button(
        "alert.cancel".localized,
        role: .cancel,
      ) {}
    } message: {
      Text("settings.reset.alert.message".localized)
    }
    .alert(
      "settings.clear.audio.alert.title".localized,
      isPresented: $showClearAudioConfirmation,
    ) {
      Button(
        "alert.clear".localized,
        role: .destructive,
      ) {
        Task {
          _ = await AudioStore.shared.clearAllAudio()
          cc.ok1(#line, "cleared all audio")

          // Refresh disk size after clearing
          let size = await AudioStore.shared.diskSize()
          DispatchQueue.main.async {
            audioStoreDiskSize = size
            cc.ok2(
              #line,
              "Audio store disk size after clear: \(formatDiskSize(size))",
            )
          }
        }
      }
      Button(
        "alert.cancel".localized,
        role: .cancel,
      ) {}
    } message: {
      Text("settings.clear.audio.alert.message".localized)
    }
    .onAppear {
      isLoading = false
      cc.ok1(#line, #function, "isLoading: \(isLoading)")

      // Load audio store disk size
      Task {
        let size = await AudioStore.shared.diskSize()
        DispatchQueue.main.async {
          audioStoreDiskSize = size
          isLoadingDiskSize = false
          cc.ok2(#line, "Audio store disk size: \(formatDiskSize(size))")
        }
      }
    }
    .sheet(isPresented: $showBackgroundPlaybackInfo) {
      TipView(
        title: "settings.background.playback.info.title".localized,
        text: "settings.background.playback.info.message".localized
          + "\n\n"
          + "settings.background.playback.info.trigger".localized,
        isPresented: $showBackgroundPlaybackInfo,
      )
      .environmentObject(themeProvider)
      .presentationDetents([.medium])
    }
  } // View
} // SettingsView

// MARK: - Languages Section Content

struct LanguagesSectionContent: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  @Environment(\.sizeCategory) var sizeCategory
  @ObservedObject var controller: SettingsModalController
  let availableDocAuthors: [DatabaseInfo]
  let sortedLanguages: [ScvLanguage]
  @Binding var showDocLangPicker: Bool
  @Binding var showDocAuthorPicker: Bool
  @Binding var showRefLangPicker: Bool

  var shouldStackVertically: Bool {
    sizeCategory.isAccessibilityCategory
  }

  var docAuthorName: String {
    availableDocAuthors.first { $0.author == controller.docAuthor }?.authorName
      ?? controller.docAuthor
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Document Language
      Text("settings.search".localized)
        .font(.caption)
        .foregroundColor(themeProvider.theme.secondaryTextColor)

      Group {
        if shouldStackVertically {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Image(systemName: "globe")
                .foregroundColor(themeProvider.theme.secondaryTextColor
                  .opacity(themeProvider.theme.iconOpacity))
                .frame(minWidth: 44)
              Text("settings.document.language".localized)
                .font(.body)
                .foregroundColor(themeProvider.theme.textColor)
            }
            Button(action: { showDocLangPicker = true }) {
              Text(controller.docLang.displayName)
                .foregroundColor(themeProvider.theme.valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        } else {
          HStack {
            HStack {
              Image(systemName: "globe")
                .foregroundColor(themeProvider.theme.secondaryTextColor
                  .opacity(themeProvider.theme.iconOpacity))
                .frame(minWidth: 44)
              Text("settings.document.language".localized)
                .font(.body)
                .foregroundColor(themeProvider.theme.textColor)
            }
            Spacer()
            Button(action: { showDocLangPicker = true }) {
              Text(controller.docLang.displayName)
                .foregroundColor(themeProvider.theme.valueColor)
            }
          }
        }
      }
      .sheet(isPresented: $showDocLangPicker) {
        LanguagePickerModal(
          title: "settings.document.language".localized,
          selection: $controller.docLang,
          options: sortedLanguages,
          optionLabel: { $0.displayName },
        )
      }

      // Document Author
      Group {
        if shouldStackVertically {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Image(systemName: "person")
                .foregroundColor(themeProvider.theme.textColor
                  .opacity(themeProvider.theme.iconOpacity))
                .frame(minWidth: 44)
              Text("settings.document.author".localized)
                .font(.body)
                .foregroundColor(themeProvider.theme.textColor)
            }
            Button(action: { showDocAuthorPicker = true }) {
              Text(docAuthorName)
                .foregroundColor(themeProvider.theme.valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        } else {
          HStack {
            HStack {
              Image(systemName: "person")
                .foregroundColor(themeProvider.theme.textColor
                  .opacity(themeProvider.theme.iconOpacity))
                .frame(minWidth: 44)
              Text("settings.document.author".localized)
                .font(.body)
                .foregroundColor(themeProvider.theme.textColor)
            }
            Spacer()
            Button(action: { showDocAuthorPicker = true }) {
              Text(docAuthorName)
                .foregroundColor(themeProvider.theme.valueColor)
            }
          }
        }
      }
      .sheet(isPresented: $showDocAuthorPicker) {
        LanguagePickerModal(
          title: "settings.document.author".localized,
          selection: $controller.docAuthor,
          options: availableDocAuthors.map(\.author),
          optionLabel: { author in
            availableDocAuthors.first { $0.author == author }?
              .authorName ?? author
          },
        )
      }

      #if TODO_REFERENCE_LANGUAGE
        Divider()
          .padding(.vertical, 4)

        // Reference Language
        Group {
          if shouldStackVertically {
            VStack(alignment: .leading, spacing: 8) {
              Text("settings.reference.language".localized)
                .font(.caption)
                .foregroundColor(themeProvider.theme.textColor)
              Button(action: { showRefLangPicker = true }) {
                Text(controller.refLang.displayName)
                  .foregroundColor(themeProvider.theme.valueColor)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
          } else {
            HStack {
              Text("settings.reference.language".localized)
                .font(.caption)
                .foregroundColor(themeProvider.theme.textColor)
              Spacer()
              Button(action: { showRefLangPicker = true }) {
                Text(controller.refLang.displayName)
                  .foregroundColor(themeProvider.theme.valueColor)
              }
            }
          }
        }
        .sheet(isPresented: $showRefLangPicker) {
          LanguagePickerModal(
            title: "settings.reference.language".localized,
            selection: $controller.refLang,
            options: sortedLanguages,
            optionLabel: { $0.displayName },
          )
        }
      #endif
    }
  }
}

// MARK: - Audio Section Content

struct AudioSectionContent: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  @ObservedObject var controller: SettingsModalController
  @Binding var showBackgroundPlaybackInfo: Bool

  static func voiceName(for voiceId: String) -> String {
    let voices = AVFoundation.AVSpeechSynthesisVoice.speechVoices()
    return voices.first(where: { $0.identifier == voiceId })?.name ?? "Default"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("settings.speak".localized)
        .font(.caption)
        .foregroundColor(themeProvider.theme.secondaryTextColor)

      HStack {
        Image(systemName: controller
          .playPali ? "speaker.fill" : "speaker.slash")
          .foregroundColor(themeProvider.theme.secondaryTextColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.play.pali".localized,
          isOn: .constant(false),
        )
        .foregroundColor(themeProvider.theme.textColor)
        .disabled(true)
      }

      HStack {
        Image(systemName: controller.playDoc ? "speaker.fill" : "speaker.slash")
          .foregroundColor(themeProvider.theme.secondaryTextColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.play.document".localized,
          isOn: $controller.playDoc,
        )
        .foregroundColor(themeProvider.theme.textColor)
      }

      Divider()
        .padding(.vertical, 4)

      // Narrator voice selection
      Text("settings.narrator".localized)
        .font(.caption)
        .foregroundColor(themeProvider.theme.secondaryTextColor)

      VoicePickerView(
        selectedVoiceId: $controller.docVoiceId,
        pitch: $controller.docPitch,
        rate: $controller.docRate,
        language: controller.docLang,
      )

      Divider()
        .padding(.vertical, 4)

      // Narration customization section
      Text("settings.narration".localized)
        .font(.caption)
        .foregroundColor(themeProvider.theme.secondaryTextColor)

      // Pitch
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Image(systemName: "mountain.2")
          .foregroundColor(themeProvider.theme.textColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        VStack(alignment: .leading, spacing: 4) {
          Text("settings.pitch".localized)
            .font(.body)
            .foregroundColor(themeProvider.theme.textColor)
          Slider(value: $controller.docPitch, in: 0.5 ... 2.0, step: 0.1)
        }
        Text(String(format: "%.1f", controller.docPitch))
          .foregroundColor(themeProvider.theme.valueColor)
          .frame(minWidth: 44)
      }

      Divider()
        .padding(.vertical, 4)

      // Rate
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Image(systemName: "hare")
          .foregroundColor(themeProvider.theme.secondaryTextColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        VStack(alignment: .leading, spacing: 4) {
          Text("settings.rate".localized)
            .font(.body)
            .foregroundColor(themeProvider.theme.textColor)
          Slider(value: $controller.docRate, in: 0.1 ... 2.0, step: 0.1)
        }
        Text(String(format: "%.1f", controller.docRate))
          .foregroundColor(themeProvider.theme.valueColor)
          .frame(minWidth: 44)
      }

      Divider()
        .padding(.vertical, 4)

      // Sound Effects Volume (Playback Cues)
      SliderSettingRow(
        icon: "speaker.wave.2",
        label: "settings.sound.effects.volume".localized,
        value: Binding(
          get: { Double(controller.soundEffectVolume * 4.0) },
          set: { newValue in
            controller.soundEffectVolume = Float(newValue) / 4.0
          },
        ),
        in: 0 ... 4,
        step: 1,
        displayFormatter: { String(Int($0)) },
      )

      Divider()
        .padding(.vertical, 4)

      // Segment Pause
      SliderSettingRow(
        icon: "waveform",
        label: "settings.segment.pause".localized,
        value: $controller.segmentPause,
        in: 0.0 ... 1.0,
        step: 0.1,
        displayFormatter: { String(format: "%.2f", $0) + "s" },
      )

      Divider()
        .padding(.vertical, 4)

      // Background Playback
      Toggle(isOn: Binding(
        get: { controller.backgroundPlayback },
        set: { newValue in
          controller.backgroundPlayback = newValue
          if newValue {
            showBackgroundPlaybackInfo = true
          }
        },
      )) {
        HStack(spacing: 12) {
          Image(systemName: "lock.rectangle.on.rectangle")
            .foregroundColor(themeProvider.theme.textColor
              .opacity(themeProvider.theme.iconOpacity))
            .frame(minWidth: 44)
          Text("settings.background.playback".localized)
            .font(.body)
            .foregroundColor(themeProvider.theme.textColor)
        }
      }
    }
  }
}

// MARK: - Display Section Content

struct DisplaySectionContent: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  @ObservedObject var controller: SettingsModalController

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("settings.show".localized)
        .font(.caption)
        .foregroundColor(themeProvider.theme.textColor)

      HStack {
        Image(systemName: controller.showPali ? "eye.fill" : "eye.slash")
          .foregroundColor(themeProvider.theme.secondaryTextColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.show.pali".localized,
          isOn: $controller.showPali,
        )
        .foregroundColor(themeProvider.theme.textColor)
      }

      HStack {
        Image(systemName: controller.showDoc ? "eye.fill" : "eye.slash")
          .foregroundColor(themeProvider.theme.secondaryTextColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.show.document".localized,
          isOn: $controller.showDoc,
        )
        .foregroundColor(themeProvider.theme.textColor)
      }

      HStack {
        Image(systemName: controller.showRef ? "eye.fill" : "eye.slash")
          .foregroundColor(themeProvider.theme.secondaryTextColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.show.reference".localized,
          isOn: .constant(false),
        )
        .foregroundColor(themeProvider.theme.textColor)
        .disabled(true)
      }

      Divider()
        .padding(.vertical, 4)

      HStack {
        Image(systemName: controller
          .isDarkModeEnabled ? "moon.fill" : "sun.max.fill")
          .foregroundColor(themeProvider.theme.secondaryTextColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle("settings.dark.mode".localized, isOn: Binding(
          get: { controller.isDarkModeEnabled },
          set: { newValue in
            controller.isDarkModeEnabled = newValue
            themeProvider.setTheme(newValue ? .dark : .light)
          },
        ))
        .foregroundColor(themeProvider.theme.textColor)
      }

      Divider()
        .padding(.vertical, 4)

      HStack(spacing: 12) {
        Image(systemName: "textformat.characters.arrow.left.and.right")
          .foregroundColor(themeProvider.theme.secondaryTextColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        VStack(alignment: .leading, spacing: 8) {
          Text("settings.max.column.width".localized)
            .font(.body)
            .foregroundColor(themeProvider.theme.textColor)
          Slider(
            value: $controller.maxColumnWidth,
            in: MIN_COLUMN_WIDTH ... MAX_COLUMN_WIDTH,
            step: 10,
          )
          .foregroundColor(themeProvider.theme.textColor)
          Text(
            "Min: \(Int(MIN_COLUMN_WIDTH))pt - Max: \(Int(MAX_COLUMN_WIDTH))pt - Current: \(Int(controller.maxColumnWidth))pt",
          )
          .font(.caption)
          .foregroundColor(themeProvider.theme.secondaryTextColor)
        }
      }
    }
  }
}

#Preview {
  SettingsView(controller: SettingsModalController(from: Settings.shared))
    .environmentObject(ThemeProvider())
}
