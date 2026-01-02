//
//  SettingsView.swift
//  scv-ui
//
//  Created by Visakha on 20/11/2025.
//

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
  @State private var showDocLangPicker = false
  @State private var showDocAuthorPicker = false
  @State private var showRefLangPicker = false
  @State private var expandedSection: String? = "languages"

  private func toggleSection(_ section: String) {
    if expandedSection == section {
      expandedSection = nil
    } else {
      expandedSection = section
    }
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
    ScvLanguage.allCases.sorted { $0.code < $1.code }
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
            VStack(spacing: 4) {
              // MARK: - Languages Section

              CollapsibleSection(
                "settings.languages".localized,
                isExpanded: Binding(
                  get: { expandedSection == "languages" },
                  set: { _ in toggleSection("languages") },
                ),
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
              ) {
                AudioSectionContent(
                  controller: controller,
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
                Button(
                  "settings.reset.button".localized,
                  role: .destructive,
                ) {
                  showResetConfirmation = true
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
    .onAppear {
      isLoading = false
      cc.ok1(#line, #function, "isLoading: \(isLoading)")
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
      Group {
        if shouldStackVertically {
          VStack(alignment: .leading, spacing: 8) {
            Text("settings.document.language".localized)
              .font(.caption)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
            Button(action: { showDocLangPicker = true }) {
              Text(controller.docLang.displayName)
                .foregroundColor(themeProvider.theme.valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        } else {
          HStack {
            Text("settings.document.language".localized)
              .font(.caption)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
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

      Divider()
        .padding(.vertical, 4)

      // Document Author
      Group {
        if shouldStackVertically {
          VStack(alignment: .leading, spacing: 8) {
            Text("settings.document.author".localized)
              .font(.caption)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
            Button(action: { showDocAuthorPicker = true }) {
              Text(docAuthorName)
                .foregroundColor(themeProvider.theme.valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        } else {
          HStack {
            Text("settings.document.author".localized)
              .font(.caption)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
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
                .foregroundColor(themeProvider.theme.secondaryTextColor)
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
                .foregroundColor(themeProvider.theme.secondaryTextColor)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Document Narrator
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

      // Sound Effects Volume
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

      Text("settings.speak".localized)
        .font(.caption)
        .foregroundColor(themeProvider.theme.secondaryTextColor)

      HStack {
        Image(systemName: controller
          .playPali ? "speaker.fill" : "speaker.slash")
          .foregroundColor(themeProvider.theme.textColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.play.pali".localized,
          isOn: $controller.playPali,
        )
        // .disabled(true)
      }

      HStack {
        Image(systemName: controller.playDoc ? "speaker.fill" : "speaker.slash")
          .foregroundColor(themeProvider.theme.textColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.play.document".localized,
          isOn: $controller.playDoc,
        )
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
      HStack {
        Image(systemName: controller
          .isDarkModeEnabled ? "moon.fill" : "sun.max.fill")
          .foregroundColor(themeProvider.theme.textColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle("settings.dark.mode".localized, isOn: Binding(
          get: { controller.isDarkModeEnabled },
          set: { newValue in
            controller.isDarkModeEnabled = newValue
            themeProvider.setTheme(newValue ? .dark : .light)
          },
        ))
      }

      Divider()

      Text("settings.show".localized)
        .font(.caption)
        .foregroundColor(themeProvider.theme.secondaryTextColor)
        .padding(.top, 4)

      HStack {
        Image(systemName: controller.showPali ? "eye.fill" : "eye.slash")
          .foregroundColor(themeProvider.theme.textColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.show.pali".localized,
          isOn: $controller.showPali,
        )
      }

      HStack {
        Image(systemName: controller.showDoc ? "eye.fill" : "eye.slash")
          .foregroundColor(themeProvider.theme.textColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.show.document".localized,
          isOn: $controller.showDoc,
        )
      }

      HStack {
        Image(systemName: controller.showRef ? "eye.fill" : "eye.slash")
          .foregroundColor(themeProvider.theme.textColor
            .opacity(themeProvider.theme.iconOpacity))
          .frame(minWidth: 44)
        Toggle(
          "settings.show.reference".localized,
          isOn: $controller.showRef,
        )
      }
    }
  }
}

#Preview {
  SettingsView(controller: SettingsModalController(from: Settings.shared))
    .environmentObject(ThemeProvider())
}
