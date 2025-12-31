//
//  AboutCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-03.
//

import scvCore
import SwiftUI

// MARK: - Image Credit Model

struct ImageCredit: Decodable {
  let filename: String
  let license: String
  let credit: String

  enum CodingKeys: String, CodingKey {
    case license
    case credit
    case images
    case properties
    case filename
  }

  init(filename: String, license: String, credit: String) {
    self.filename = filename
    self.license = license
    self.credit = credit
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let propertiesContainer = try container.nestedContainer(
      keyedBy: CodingKeys.self,
      forKey: .properties,
    )
    license = try propertiesContainer.decode(String.self, forKey: .license)
    credit = try propertiesContainer.decode(String.self, forKey: .credit)

    var imagesArray = try container.nestedUnkeyedContainer(forKey: .images)
    let firstImage = try imagesArray.nestedContainer(keyedBy: CodingKeys.self)
    filename = try firstImage.decode(String.self, forKey: .filename)
  }
}

// MARK: - Image Credits Loader

@MainActor
class ImageCreditsLoader {
  static let shared = ImageCreditsLoader()
  private var cachedCredits: [String: ImageCredit]?
  private let cc = ColorConsole(#file, #function, dbg.AppRootView.other)

  func loadImageCredits() -> [String: ImageCredit] {
    if let cached = cachedCredits {
      return cached
    }

    let startTime = Date()

    // Convert generated imageCreditsData to ImageCredit objects
    var credits: [String: ImageCredit] = [:]
    for (name, creditInfo) in imageCreditsData {
      credits[name] = ImageCredit(
        filename: name,
        license: creditInfo.license,
        credit: creditInfo.credit,
      )
    }

    let elapsed = Date().timeIntervalSince(startTime) * 1000
    cc.ok2(
      "loadImageCredits() Loaded \(credits.count) image credits from generated data (\(String(format: "%.1f", elapsed))ms)",
    )

    cachedCredits = credits
    return credits
  }

  func getImageUrl(for imageName: String) -> String? {
    imageCreditsData[imageName]?.url
  }

  func getAudioCredits() -> [(
    name: String,
    credit: String,
    license: String,
    url: String?,
  )] {
    audioCreditsData.map { key, value in
      (name: key, credit: value.credit, license: value.license, url: value.url)
    }.sorted { $0.credit < $1.credit }
  }
}

// MARK: - AboutCardView

/// About card view with collapsible sections for app information
public struct AboutCardView: View {
  var card: (any ICard)?
  var cardManager: (any ICardManager)?
  @EnvironmentObject var themeProvider: ThemeProvider
  @Environment(\.openURL) var openURL
  @State private var imageCredits: [String: ImageCredit] = [:]
  @State private var expandedSection: String? = nil
  let cc = ColorConsole(#file, #function, dbg.AppRootView.other)

  public init<Card: ICard, Manager: ICardManager>(
    card: Card? = nil,
    cardManager: Manager? = nil,
  )
    where Manager.ManagedCard == Card
  {
    self.card = card
    self.cardManager = cardManager
  }

  public init() {
    card = nil
    cardManager = nil
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 4) {
        // MARK: - Header

        VStack(spacing: 12) {
          Image(systemName: "info.circle.fill")
            .font(.title)
            .foregroundStyle(themeProvider.theme.secondaryTextColor)

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

        CollapsibleSection("Overview", isExpanded: .constant(expandedSection == "overview" || expandedSection == nil)) {
          VStack(alignment: .leading, spacing: 12) {
            Text(
              "Search and read Buddhist scriptures (suttas) in multiple languages with powerful search capabilities and beautiful typography.",
            )
            .font(.body)
            .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              FeatureRow(
                icon: "magnifyingglass",
                title: "Full-Text Search",
                description: "Search across thousands of suttas",
              )
              FeatureRow(
                icon: "book.fill",
                title: "Multiple Languages",
                description: "English, German, Portuguese, and more",
              )
              FeatureRow(
                icon: "highlighter",
                title: "Highlighting",
                description: "See matched segments and quotes",
              )
            }
          }
        }

        // MARK: - How to Use

        CollapsibleSection("How to Use", isExpanded: .constant(expandedSection == "howToUse"), onToggle: {
          expandedSection = expandedSection == "howToUse" ? nil : "howToUse"
        }) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Getting started with SC-Voice:")
              .font(.headline)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              StepRow(
                number: 1,
                title: "Create a Search Card",
                description: "Tap the '+' button to create a new card",
              )
              StepRow(
                number: 2,
                title: "Enter a Query",
                description: "Search for a word, phrase, or sutta UID",
              )
              StepRow(
                number: 3,
                title: "View Results",
                description: "Browse matching suttas and segments",
              )
              StepRow(
                number: 4,
                title: "Open Suttas",
                description: "Tap results to read the full text",
              )
            }
          }
        }

        // MARK: - Content Sources

        CollapsibleSection("Content Sources", isExpanded: .constant(expandedSection == "contentSources"), onToggle: {
          expandedSection = expandedSection == "contentSources" ? nil : "contentSources"
        }) {
          VStack(alignment: .leading, spacing: 12) {
            Text("This app uses the following content sources:")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            SourceRow(
              title: "SuttaCentral",
              author: "Bhikkhu Sujato & Team",
              url: URL(string: "https://suttacentral.net"),
            )

            SourceRow(
              title: "Mahāsaṅgīti",
              author: "Tipiṭaka Buddhavasse 2500",
              url: URL(string: "https://tipitaka2500.github.io/"),
            )

            SourceRow(
              title: "EBT-Data",
              author: "Other Early Buddhist Text Translations aligned to SuttaCentral content",
              url: URL(string: "https://github.com/ebt-site/ebt-data"),
            )

            Text(
              "All texts are available under Creative Commons licenses, allowing free use and distribution with proper attribution.",
            )
            .font(.caption)
            .foregroundStyle(themeProvider.theme.secondaryTextColor)
          }
        }

        // MARK: - Acknowledgements

        CollapsibleSection("Acknowledgements", isExpanded: .constant(expandedSection == "acknowledgements"), onToggle: {
          expandedSection = expandedSection == "acknowledgements" ? nil : "acknowledgements"
        }) {
          VStack(alignment: .leading, spacing: 12) {
            Text("SC-Voice builds on the work of many contributors:")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              AckRow(
                role: "Translations",
                names: "Bhikkhu Sujato (EN), Sabbamitta Silashin (DE), SV theravada.ru (RU), Bhikkhu Brahmali (EN), John Kelly (EN), Ayya Soma (EN), Noé Ismet (FR), and Sonja Büge (DE)",
              )
              AckRow(
                role: "Root Text",
                names: "Mahāsaṅgīti Tipiṭaka Buddhavasse 2500",
              )
              AckRow(role: "Database", names: "SuttaCentral team")
              AckRow(role: "Development", names: "SC-Voice contributors")
            }
          }
        }

        // MARK: - Graphics & Design

        CollapsibleSection("Graphics & Design", isExpanded: .constant(expandedSection == "graphicsDesign"), onToggle: {
          expandedSection = expandedSection == "graphicsDesign" ? nil : "graphicsDesign"
        }) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Background images and themes:")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 12) {
              // Display theme credits dynamically
              ForEach(
                imageCredits.sorted(by: { $0.key < $1.key }),
                id: \.key,
              ) { name, credit in
                HStack(alignment: .top, spacing: 12) {
                  // Thumbnail image
                  Image(name, bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(4)

                  // Credit info
                  VStack(alignment: .leading, spacing: 4) {
                    // Clickable title
                    if let url = ImageCreditsLoader.shared
                      .getImageUrl(for: name),
                      let linkUrl = URL(string: url)
                    {
                      Button(action: {
                        openURL(linkUrl)
                      }) {
                        Text(
                          name
                            .replacingOccurrences(of: "-", with: " ")
                            .capitalized,
                        )
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeProvider.theme.linkColor)
                        .underline()
                      }
                    } else {
                      Text(
                        name
                          .replacingOccurrences(of: "-", with: " ")
                          .capitalized,
                      )
                      .font(.callout)
                      .fontWeight(.semibold)
                      .foregroundStyle(themeProvider.theme.secondaryTextColor)
                    }

                    Text(credit.credit)
                      .font(.caption)
                      .foregroundStyle(themeProvider.theme.textColor)

                    Text("License: \(credit.license)")
                      .font(.caption2)
                      .foregroundStyle(themeProvider.theme.secondaryTextColor)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)

                  Spacer()
                }
              }
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("App Icon")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(themeProvider.theme.secondaryTextColor)
              Text("Designed by Friends of Voice")
                .font(.caption)
                .foregroundStyle(themeProvider.theme.secondaryTextColor)
            }
          }
        }
        .onAppear {
          imageCredits = ImageCreditsLoader.shared.loadImageCredits()
        }

        // MARK: - Audio Credits

        CollapsibleSection("Audio Credits", isExpanded: .constant(expandedSection == "audioCredits"), onToggle: {
          expandedSection = expandedSection == "audioCredits" ? nil : "audioCredits"
        }) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Sound effects and audio:")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              ForEach(
                ImageCreditsLoader.shared.getAudioCredits(),
                id: \.name,
              ) { audio in
                VStack(alignment: .leading, spacing: 4) {
                  Text(audio.credit)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeProvider.theme.secondaryTextColor)

                  Text("License: \(audio.license)")
                    .font(.caption2)
                    .foregroundStyle(themeProvider.theme.secondaryTextColor)

                  if let url = audio.url, let linkUrl = URL(string: url) {
                    Button(action: {
                      openURL(linkUrl)
                    }) {
                      Text("View source")
                        .font(.caption)
                        .foregroundStyle(themeProvider.theme.linkColor)
                        .underline()
                    }
                  }
                }
              }
            }

            Text("Audio sourced from Freesound.org and original compositions.")
              .font(.caption)
              .foregroundStyle(themeProvider.theme.secondaryTextColor)
          }
        }

        // MARK: - Open Source Licenses

        CollapsibleSection("Open Source Licenses", isExpanded: .constant(expandedSection == "openSourceLicenses"), onToggle: {
          expandedSection = expandedSection == "openSourceLicenses" ? nil : "openSourceLicenses"
        }) {
          VStack(alignment: .leading, spacing: 12) {
            Text(
              "All SC-Voice source code is licensed under the MIT License unless otherwise noted.",
            )
            .font(.body)
            .foregroundStyle(themeProvider.theme.textColor)

            Text("The following libraries are also included:")
              .font(.body)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              LicenseRow(library: "SQLite", license: "Public Domain")
              LicenseRow(library: "Zstandard", license: "BSD License")
            }

            Text("See GitHub repository for full license information.")
              .font(.caption)
              .foregroundStyle(themeProvider.theme.secondaryTextColor)
          }
        }

        // MARK: - Privacy Policy

        CollapsibleSection("Privacy Policy", isExpanded: .constant(expandedSection == "privacyPolicy"), onToggle: {
          expandedSection = expandedSection == "privacyPolicy" ? nil : "privacyPolicy"
        }) {
          VStack(alignment: .leading, spacing: 12) {
            Text("SC-Voice respects your privacy:")
              .font(.headline)
              .foregroundStyle(themeProvider.theme.textColor)

            VStack(alignment: .leading, spacing: 8) {
              PrivacyRow(
                icon: "lock.fill",
                title: "No Analytics",
                description: "We do not track your searches or usage",
              )
              PrivacyRow(
                icon: "icloud.slash",
                title: "Local Storage",
                description: "All data is stored locally on your device",
              )
              PrivacyRow(
                icon: "key.fill",
                title: "Open Source",
                description: "Review the code to verify our privacy practices",
              )
            }
          }
        }

        // MARK: - Support & Feedback

        CollapsibleSection("Support & Feedback", isExpanded: .constant(expandedSection == "supportFeedback"), onToggle: {
          expandedSection = expandedSection == "supportFeedback" ? nil : "supportFeedback"
        }) {
          VStack(alignment: .leading, spacing: 12) {
            Text(
              "Found a bug? Have a suggestion? Visit our GitHub repository to report issues or contribute.",
            )
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
        }
      }
      .padding(16)
      .frame(maxWidth: 700)
    }
    .scrollContentBackground(.hidden)
    // .background(themeProvider.theme.backgroundColor)
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
        .foregroundColor(themeProvider.theme.secondaryTextColor)
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
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(themeProvider.theme.secondaryTextColor)

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
  @Environment(\.openURL) var openURL
  let title: String
  let author: String
  let url: URL?

  var body: some View {
    let content = VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.callout)
        .fontWeight(.semibold)
        .foregroundStyle(url != nil ? themeProvider.theme
          .linkColor : themeProvider.theme.textColor)
      Text(author)
        .font(.caption)
        .foregroundStyle(themeProvider.theme.secondaryTextColor)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(themeProvider.theme.backgroundColor.opacity(0.5))
    .cornerRadius(4)

    if let url {
      Button(action: { openURL(url) }) {
        content
      }
    } else {
      content
    }
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
        .foregroundStyle(themeProvider.theme.secondaryTextColor)
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
        .foregroundColor(themeProvider.theme.secondaryTextColor)
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
