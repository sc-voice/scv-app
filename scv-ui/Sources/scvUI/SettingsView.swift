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

struct SettingsView: View {
  let cc = ColorConsole(#file, "SettingsView", dbg.ScvUI.other)
  @ObservedObject var controller: SettingsModalController
  @EnvironmentObject var themeProvider: ThemeProvider
  @Environment(\.dismiss) var dismiss
  @State private var showResetConfirmation = false
  @State private var showDocLangPicker = false
  @State private var showRefLangPicker = false
  @State private var showUILangPicker = false

  var buildNumber: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Settings")
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

      Form {
        // MARK: - Languages Section

        Section("Languages") {
          HStack {
            Text("Document Language")
            Spacer()
            Button(action: { showDocLangPicker = true }) {
              Text(controller.docLang.displayName)
                .foregroundColor(themeProvider.theme.valueColor)
            }
          }
          .sheet(isPresented: $showDocLangPicker) {
            Picker("Document Language", selection: $controller.docLang) {
              ForEach(ScvLanguage.allCases, id: \.self) { lang in
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
            Text("Reference Language")
            Spacer()
            Button(action: { showRefLangPicker = true }) {
              Text(controller.refLang.displayName)
                .foregroundColor(themeProvider.theme.valueColor)
            }
          }
          .sheet(isPresented: $showRefLangPicker) {
            Picker("Reference Language", selection: $controller.refLang) {
              ForEach(ScvLanguage.allCases, id: \.self) { lang in
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
            Text("UI Language")
            Spacer()
            Button(action: { showUILangPicker = true }) {
              Text(controller.uiLang.displayName)
                .foregroundColor(themeProvider.theme.valueColor)
            }
          }
          .sheet(isPresented: $showUILangPicker) {
            Picker("UI Language", selection: $controller.uiLang) {
              ForEach(ScvLanguage.uiLanguages, id: \.self) { lang in
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
        }

        // MARK: - Appearance Section

        Section("Appearance") {
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
        }

        // MARK: - Pali Voice Section

        Section("Pali Narration Voice") {
          VoicePickerView(
            selectedVoiceId: $controller.paliVoiceId,
            pitch: $controller.paliPitch,
            rate: $controller.paliRate,
            language: .pli,
          )
        }

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
            Text("Build")
            Spacer()
            Text(buildNumber)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
          }
        }

        // MARK: - Reset Button Section

        Section {
          Button("Reset Settings", role: .destructive) {
            showResetConfirmation = true
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(themeProvider.theme.backgroundColor)
    }
    .background(themeProvider.theme.backgroundColor)
    .onChange(of: showResetConfirmation) {
      if showResetConfirmation {
        cc.ok2(#line, "alert(Reset All Settings) presenting")
      }
    }
    .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
      Button("Reset", role: .destructive) {
        controller.resetToDefaults()
        themeProvider.setTheme(.dark)
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
    overlay(alignment: .bottom) {
      Divider()
    }
  }
}

#Preview {
  SettingsView(controller: SettingsModalController(from: Settings.shared))
}
