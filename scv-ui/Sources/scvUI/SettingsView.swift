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

  public init(controller: SettingsModalController) {
    _controller = ObservedObject(wrappedValue: controller)
  }

  var buildNumber: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
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
        .opacity(0.5)

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
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeProvider.theme.backgroundColor)
        } else {
          Form {
            LanguagesSection(
              controller: controller,
              themeProvider: themeProvider,
              sortedLanguages: sortedLanguages,
              showDocLangPicker: $showDocLangPicker,
              showDocAuthorPicker: $showDocAuthorPicker,
              showRefLangPicker: $showRefLangPicker,
            )

            // MARK: - Accessibility Section

            Section("settings.accessibility".localized) {
              // MARK: - Vision Group

              Text("settings.vision".localized)
                .font(.caption)
                .foregroundColor(themeProvider.theme.secondaryTextColor)

              HStack {
                Image(systemName: controller
                  .isDarkModeEnabled ? "moon.fill" : "sun.max.fill")
                  .foregroundColor(themeProvider.theme.accentColor)
                Toggle("Dark Mode", isOn: Binding(
                  get: { controller.isDarkModeEnabled },
                  set: { newValue in
                    controller.isDarkModeEnabled = newValue
                    themeProvider.setTheme(newValue ? .dark : .light)
                  },
                ))
              }

              Divider()
                .padding(.vertical, 12)

              // MARK: - Audio Group

              Text("settings.audio".localized)
                .font(.caption)
                .foregroundColor(themeProvider.theme.secondaryTextColor)

              HStack {
                Image(systemName: "speaker.wave.2")
                  .foregroundColor(themeProvider.theme.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                  Text("settings.sound.effects.volume".localized)
                    .font(.body)
                  Slider(value: Binding(
                    get: { Double(controller.soundEffectVolume) },
                    set: { newValue in
                      controller.soundEffectVolume = Int(newValue)
                    },
                  ), in: 0 ... 4, step: 1)
                }
                Text("\(controller.soundEffectVolume)")
                  .font(.caption)
                  .foregroundColor(themeProvider.theme.secondaryTextColor)
                  .frame(width: 20)
              }

              Divider()
                .padding(.vertical, 12)

              HStack {
                Image(systemName: "waveform")
                  .foregroundColor(themeProvider.theme.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                  Text("settings.segment.pause".localized)
                    .font(.body)
                  Slider(value: Binding(
                    get: { controller.segmentPause },
                    set: { newValue in
                      controller.segmentPause = newValue
                    },
                  ), in: 0.0 ... 1.0, step: 0.1)
                }
                Text("\(String(format: "%.2f", controller.segmentPause))s")
                  .font(.caption)
                  .foregroundColor(themeProvider.theme.secondaryTextColor)
                  .frame(width: 35)
              }

              Divider()
                .padding(.vertical, 12)

              HStack {
                Image(systemName: "book")
                  .foregroundColor(themeProvider.theme.accentColor)
                Toggle(
                  "settings.play.pali".localized,
                  isOn: $controller.playPali,
                )
                .disabled(true)
              }

              HStack {
                Image(systemName: "doc.text")
                  .foregroundColor(themeProvider.theme.accentColor)
                Toggle(
                  "settings.play.document".localized,
                  isOn: $controller.playDoc,
                )
              }
            }

            // MARK: - Pali Voice Section

            // FUTURE: Enable Pali voice selection

            // Section("Pali Narration Voice") {
            //   VoicePickerView(
            //     selectedVoiceId: $controller.paliVoiceId,
            //     pitch: $controller.paliPitch,
            //     rate: $controller.paliRate,
            //     language: .pli,
            //   )
            // }

            // MARK: - Document Voice Section

            Section("Document Narration Voice") {
              VoicePickerView(
                selectedVoiceId: $controller.docVoiceId,
                pitch: $controller.docPitch,
                rate: $controller.docRate,
                language: controller.docLang,
              )
            }

            // MARK: - Build Section

            Section {
              HStack {
                Text("settings.build".localized)
                Spacer()
                Text(buildNumber)
                  .foregroundColor(themeProvider.theme.secondaryTextColor)
              }
            }

            // MARK: - Reset Button Section

            Section {
              Button(
                "settings.reset.button".localized,
                role: .destructive,
              ) {
                showResetConfirmation = true
              }
            }
          }
          .scrollContentBackground(.hidden)
          .frame(maxWidth: 500)
          .padding(.horizontal)
        }
      }

      if isLoading {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.black.opacity(1.0))
      }
    }
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
      cc.ok1(#line, #function)
      cc.ok2(#line, "isLoading: \(isLoading)")
      isLoading = false
    }
  }
}

// MARK: - Languages Section

struct LanguagesSection: View {
  @ObservedObject var controller: SettingsModalController
  let themeProvider: ThemeProvider
  let sortedLanguages: [ScvLanguage]
  @Binding var showDocLangPicker: Bool
  @Binding var showDocAuthorPicker: Bool
  @Binding var showRefLangPicker: Bool

  var availableDocAuthors: [DatabaseInfo] {
    EbtData.authorsForLanguageFromManifest(controller.docLang.code)
      .sorted { $0.files.total > $1.files.total }
  }

  var docAuthorName: String {
    availableDocAuthors.first { $0.author == controller.docAuthor }?.authorName
      ?? controller.docAuthor
  }

  var body: some View {
    Section("settings.languages".localized) {
      HStack {
        Text("settings.document.language".localized)
        Spacer()
        Button(action: { showDocLangPicker = true }) {
          Text(controller.docLang.displayName)
            .foregroundColor(themeProvider.theme.valueColor)
        }
      }
      .sheet(isPresented: $showDocLangPicker) {
        Picker(
          "settings.document.language".localized,
          selection: $controller.docLang,
        ) {
          ForEach(sortedLanguages, id: \.self) { lang in
            Text(lang.displayName).tag(lang)
          }
        }
        #if os(iOS)
        .pickerStyle(.wheel)
        .presentationDetents([.medium])
        #else
        .pickerStyle(.menu)
        #endif
      }

      HStack {
        Text("settings.document.author".localized)
        Spacer()
        Button(action: { showDocAuthorPicker = true }) {
          Text(docAuthorName)
            .foregroundColor(themeProvider.theme.valueColor)
        }
      }
      .sheet(isPresented: $showDocAuthorPicker) {
        Picker(
          "settings.document.author".localized,
          selection: $controller.docAuthor,
        ) {
          ForEach(availableDocAuthors, id: \.author) { info in
            Text(info.authorName).tag(info.author)
          }
        }
        #if os(iOS)
        .pickerStyle(.wheel)
        .presentationDetents([.medium])
        #else
        .pickerStyle(.menu)
        #endif
      }

      #if TODO_REFERENCE_LANGUAGE
        HStack {
          Text("settings.reference.language".localized)
          Spacer()
          Button(action: { showRefLangPicker = true }) {
            Text(controller.refLang.displayName)
              .foregroundColor(themeProvider.theme.valueColor)
          }
        }
        .sheet(isPresented: $showRefLangPicker) {
          Picker(
            "settings.reference.language".localized,
            selection: $controller.refLang,
          ) {
            ForEach(sortedLanguages, id: \.self) { lang in
              Text(lang.displayName).tag(lang)
            }
          }
          #if os(iOS)
          .pickerStyle(.wheel)
          .presentationDetents([.medium])
          #else
          .pickerStyle(.menu)
          #endif
        }
      #endif
    }
  }
}

// MARK: - Helper Extension

extension View {
  func borderBottom() -> some View {
    overlay(alignment: .bottom) {
      Divider()
    }
  }
}

#Preview {
  SettingsView(controller: SettingsModalController(from: Settings.shared))
    .environmentObject(ThemeProvider())
}
