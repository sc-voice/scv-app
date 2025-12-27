//
//  AboutCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-03.
//

import scvCore
import SwiftUI

// MARK: - AboutCardView

/// About card view with collapsible sections for app information
public struct AboutCardView: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  @Environment(\.openURL) var openURL
  let cc = ColorConsole(#file, #function, dbg.AppRootView.other)

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // MARK: - Header

        VStack(spacing: 12) {
          Image(systemName: "info.circle.fill")
            .font(.system(size: 48))
            .foregroundStyle(themeProvider.theme.accentColor)

          VStack(spacing: 4) {
            Text("SC-Voice")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundStyle(themeProvider.theme.textColor)

            Text("Version \(scvCore.appVersion)")
              .font(.caption)
              .foregroundStyle(themeProvider.theme.secondaryTextColor)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(themeProvider.theme.cardBackground)
        .cornerRadius(8)

        // MARK: - Overview (Always Expanded)

        CollapsibleSection("Overview", initiallyExpanded: true) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Search and read Buddhist scriptures (suttas) in multiple languages with powerful search capabilities and beautiful typography.")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              FeatureRow(
                icon: "magnifyingglass",
                title: "Full-Text Search",
                description: "Search across thousands of suttas"
              )
              FeatureRow(
                icon: "book.fill",
                title: "Multiple Languages",
                description: "English, German, Portuguese, and more"
              )
              FeatureRow(
                icon: "highlighter",
                title: "Highlighting",
                description: "See matched segments and quotes"
              )
            }
          }
        }

        // MARK: - How to Use

        CollapsibleSection("How to Use") {
          VStack(alignment: .leading, spacing: 12) {
            Text("Getting started with SC-Voice:")
              .font(.headline)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              StepRow(number: 1, title: "Create a Search Card", description: "Tap the '+' button to create a new card")
              StepRow(number: 2, title: "Enter a Query", description: "Search for a word, phrase, or sutta UID")
              StepRow(number: 3, title: "View Results", description: "Browse matching suttas and segments")
              StepRow(number: 4, title: "Open Suttas", description: "Tap results to read the full text")
            }
          }
        }

        // MARK: - Data Sources

        CollapsibleSection("Data Sources") {
          VStack(alignment: .leading, spacing: 12) {
            Text("This app uses the following sources:")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            Button(action: {
              if let url = URL(string: "https://suttacentral.net") {
                openURL(url)
              }
            }) {
              SourceRow(title: "SuttaCentral", author: "Bhikkhu Sujato & Team")
            }

            SourceRow(title: "Mahāsaṅgīti", author: "Tipiṭaka Buddhavasse 2500")

            Text("All texts are available under Creative Commons licenses, allowing free use and distribution with proper attribution.")
              .font(.caption)
              .foregroundStyle(themeProvider.theme.secondaryTextColor)
          }
        }

        // MARK: - Acknowledgements

        CollapsibleSection("Acknowledgements") {
          VStack(alignment: .leading, spacing: 12) {
            Text("SC-Voice builds on the work of many contributors:")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              AckRow(role: "Translations", names: "Bhikkhu Sujato (EN), Sabbamitta Silashin (DE), SV theravada.ru (RU), Bhikkhu Brahmali (EN), John Kelly (EN), Ayya Soma (EN), Noé Ismet (FR), and Sonja Büge (DE)")
              AckRow(role: "Root Text", names: "Mahāsaṅgīti Tipiṭaka Buddhavasse 2500")
              AckRow(role: "Database", names: "SuttaCentral team")
              AckRow(role: "Development", names: "SC-Voice contributors")
            }
          }
        }

        // MARK: - Open Source Licenses

        CollapsibleSection("Open Source Licenses") {
          VStack(alignment: .leading, spacing: 12) {
            Text("This app uses these open source libraries:")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              LicenseRow(library: "SwiftUI", license: "Apple")
              LicenseRow(library: "SwiftData", license: "Apple")
              LicenseRow(library: "Zstandard", license: "BSD License")
            }

            Text("See GitHub repository for full license information.")
              .font(.caption)
              .foregroundStyle(themeProvider.theme.secondaryTextColor)
          }
        }

        // MARK: - Privacy Policy

        CollapsibleSection("Privacy Policy") {
          VStack(alignment: .leading, spacing: 12) {
            Text("SC-Voice respects your privacy:")
              .font(.headline)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              PrivacyRow(icon: "lock.fill", title: "No Analytics", description: "We do not track your searches or usage")
              PrivacyRow(icon: "icloud.slash", title: "Local Storage", description: "All data is stored locally on your device")
              PrivacyRow(icon: "key.fill", title: "Open Source", description: "Review the code to verify our privacy practices")
            }
          }
        }

        // MARK: - Support & Feedback

        VStack(spacing: 12) {
          Text("Support & Feedback")
            .font(.headline)
            .foregroundStyle(themeProvider.theme.textColor)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text("Found a bug? Have a suggestion? Visit our GitHub repository to report issues or contribute.")
            .font(.body)
            .foregroundStyle(themeProvider.theme.secondaryTextColor)

          Button(action: {
            if let url = URL(string: "https://github.com/sc-voice") {
              openURL(url)
            }
          }) {
            HStack {
              Image(systemName: "link")
              Text("Visit GitHub")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(themeProvider.theme.accentColor)
            .foregroundColor(.white)
            .cornerRadius(6)
          }
        }
        .padding(12)
        .background(themeProvider.theme.cardBackground)
        .cornerRadius(8)
      }
      .padding(16)
    }
    .background(themeProvider.theme.backgroundColor)
  }
}

// MARK: - Helper Components

private struct FeatureRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.headline)
        .foregroundColor(themeProvider.theme.accentColor)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.callout)
          .fontWeight(.semibold)
          .foregroundStyle(themeProvider.theme.textColor)
        Text(description)
          .font(.caption)
          .foregroundStyle(themeProvider.theme.secondaryTextColor)
      }
    }
  }
}

private struct StepRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let number: Int
  let title: String
  let description: String

  var body: some View {
    HStack(spacing: 12) {
      Text("\(number)")
        .font(.headline)
        .fontWeight(.bold)
        .foregroundColor(.white)
        .frame(width: 28, height: 28)
        .background(themeProvider.theme.accentColor)
        .cornerRadius(4)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.callout)
          .fontWeight(.semibold)
          .foregroundStyle(themeProvider.theme.textColor)
        Text(description)
          .font(.caption)
          .foregroundStyle(themeProvider.theme.secondaryTextColor)
      }
    }
  }
}

private struct SourceRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let title: String
  let author: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.callout)
        .fontWeight(.semibold)
        .foregroundStyle(themeProvider.theme.textColor)
      Text(author)
        .font(.caption)
        .foregroundStyle(themeProvider.theme.secondaryTextColor)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(themeProvider.theme.backgroundColor.opacity(0.5))
    .cornerRadius(4)
  }
}

private struct AckRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let role: String
  let names: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(role)
        .font(.callout)
        .fontWeight(.semibold)
        .foregroundStyle(themeProvider.theme.accentColor)
      Text(names)
        .font(.caption)
        .foregroundStyle(themeProvider.theme.textColor)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct LicenseRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let library: String
  let license: String

  var body: some View {
    HStack {
      Text(library)
        .font(.callout)
        .fontWeight(.semibold)
        .foregroundStyle(themeProvider.theme.textColor)
      Spacer()
      Text(license)
        .font(.caption)
        .foregroundStyle(themeProvider.theme.secondaryTextColor)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(themeProvider.theme.backgroundColor.opacity(0.5))
    .cornerRadius(4)
  }
}

private struct PrivacyRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.headline)
        .foregroundColor(themeProvider.theme.accentColor)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.callout)
          .fontWeight(.semibold)
          .foregroundStyle(themeProvider.theme.textColor)
        Text(description)
          .font(.caption)
          .foregroundStyle(themeProvider.theme.secondaryTextColor)
      }
    }
  }
}

// MARK: - Preview

#Preview("AboutCardView") {
  AboutCardView()
    .environmentObject(ThemeProvider())
}
