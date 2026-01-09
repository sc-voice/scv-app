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
      HStack {
        Spacer()
        VStack(spacing: 4) {
          // MARK: - Header

          VStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
              .font(.title)
              .foregroundStyle(themeProvider.theme.secondaryTextColor)

            VStack(spacing: 4) {
              Text("about.title".localized)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(themeProvider.theme.textColor)

              Text("about.version".localized(scvCore.marketingVersion))
                .font(.caption)
                .foregroundStyle(themeProvider.theme.secondaryTextColor)

              Text("Build \(scvCore.buildVersion)")
                .font(.caption2)
                .foregroundStyle(themeProvider.theme.secondaryTextColor)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(themeProvider.theme.cardBackground)
          .cornerRadius(8)

          // MARK: - Overview (Always Expanded)

          CollapsibleSection(
            "about.section.overview".localized,
            isExpanded: .constant(expandedSection == "overview"),
            onToggle: {
              expandedSection = expandedSection == "overview" ? nil : "overview"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.overview.description".localized)
                .font(.body)
                .foregroundStyle(themeProvider.theme.textColor)

              VStack(alignment: .leading, spacing: 8) {
                FeatureRow(
                  icon: "magnifyingglass",
                  title: "about.feature.search".localized,
                  description: "about.feature.search.desc".localized,
                )
                FeatureRow(
                  icon: "book.fill",
                  title: "about.feature.languages".localized,
                  description: "about.feature.languages.desc".localized,
                )
                FeatureRow(
                  icon: "highlighter",
                  title: "about.feature.highlighting".localized,
                  description: "about.feature.highlighting.desc".localized,
                )
              }
            }
          }

          // MARK: - How to Use

          CollapsibleSection(
            "about.section.how_to_use".localized,
            isExpanded: .constant(expandedSection == "howToUse"),
            onToggle: {
              expandedSection = expandedSection == "howToUse" ? nil : "howToUse"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.how_to_use.intro".localized)
                .font(.headline)
                .foregroundStyle(themeProvider.theme.textColor)

              VStack(alignment: .leading, spacing: 8) {
                StepRow(
                  number: 1,
                  title: "about.step.1.title".localized,
                  description: "about.step.1.desc".localized,
                )
                StepRow(
                  number: 2,
                  title: "about.step.2.title".localized,
                  description: "about.step.2.desc".localized,
                )
                StepRow(
                  number: 3,
                  title: "about.step.3.title".localized,
                  description: "about.step.3.desc".localized,
                )
                StepRow(
                  number: 4,
                  title: "about.step.4.title".localized,
                  description: "about.step.4.desc".localized,
                )
              }
            }
          }

          // MARK: - Content Sources

          CollapsibleSection(
            "about.section.content_sources".localized,
            isExpanded: .constant(expandedSection == "contentSources"),
            onToggle: {
              expandedSection = expandedSection == "contentSources" ? nil : "contentSources"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.content_sources.intro".localized)
                .font(.body)
                .foregroundStyle(themeProvider.theme.textColor)

              // MARK: Sources Subsection

              VStack(alignment: .leading, spacing: 4) {
                Text("about.content_sources.sources".localized)
                  .font(.callout)
                  .fontWeight(.semibold)
                  .foregroundStyle(themeProvider.theme.secondaryTextColor)

                VStack(alignment: .leading, spacing: 8) {
                  SourceRow(
                    title: "about.source.suttacentral".localized,
                    author: "about.source.suttacentral.author".localized,
                    url: URL(string: "https://suttacentral.net"),
                  )

                  SourceRow(
                    title: "about.source.mahasangiti".localized,
                    author: "about.source.mahasangiti.author".localized,
                    url: URL(string: "https://tipitaka2500.github.io/"),
                  )

                  SourceRow(
                    title: "about.source.ebt_data".localized,
                    author: "about.source.ebt_data.author".localized,
                    url: URL(string: "https://github.com/ebt-site/ebt-data"),
                  )
                }
              }

              // MARK: Translations Subsection

              VStack(alignment: .leading, spacing: 4) {
                Text("about.content_sources.translations".localized)
                  .font(.callout)
                  .fontWeight(.semibold)
                  .foregroundStyle(themeProvider.theme.secondaryTextColor)

                VStack(alignment: .leading, spacing: 8) {
                  ForEach(
                    EbtData.availableDatabasesFromManifest()
                      .sorted { $0.files.total > $1.files.total },
                    id: \.id,
                  ) { dbInfo in
                    TranslationRow(dbInfo: dbInfo)
                  }
                }
              }

              Text("about.content_sources.license".localized)
                .font(.caption)
                .foregroundStyle(themeProvider.theme.secondaryTextColor)
            }
          }

          // MARK: - Acknowledgements

          CollapsibleSection(
            "about.section.acknowledgements".localized,
            isExpanded: .constant(expandedSection == "acknowledgements"),
            onToggle: {
              expandedSection = expandedSection == "acknowledgements" ? nil : "acknowledgements"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.acknowledgements.intro".localized)
                .font(.body)
                .foregroundStyle(themeProvider.theme.textColor)

              VStack(alignment: .leading, spacing: 8) {
                AckRow(
                  role: "about.ack.translations".localized,
                  names: "about.ack.translations.names".localized,
                )
                AckRow(
                  role: "about.ack.root_text".localized,
                  names: "about.ack.root_text.names".localized,
                )
                AckRow(
                  role: "about.ack.database".localized,
                  names: "about.ack.database.names".localized,
                )
                AckRow(
                  role: "about.ack.development".localized,
                  names: "about.ack.development.names".localized,
                )
              }
            }
          }

          // MARK: - Graphics & Design

          CollapsibleSection(
            "about.section.graphics_design".localized,
            isExpanded: .constant(expandedSection == "graphicsDesign"),
            onToggle: {
              expandedSection = expandedSection == "graphicsDesign" ? nil : "graphicsDesign"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.graphics_design.intro".localized)
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
                        .accessibilityLabel("a11y.button.external_link"
                          .localized)
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

                      Text("about.license.prefix".localized(credit.license))
                        .font(.caption2)
                        .foregroundStyle(themeProvider.theme.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                  }
                }
              }

              VStack(alignment: .leading, spacing: 4) {
                Text("about.app_icon.label".localized)
                  .font(.callout)
                  .fontWeight(.semibold)
                  .foregroundStyle(themeProvider.theme.secondaryTextColor)
                Text("about.app_icon.credit".localized)
                  .font(.caption)
                  .foregroundStyle(themeProvider.theme.secondaryTextColor)
              }
            }
          }
          .onAppear {
            imageCredits = ImageCreditsLoader.shared.loadImageCredits()
          }

          // MARK: - Audio Credits

          CollapsibleSection(
            "about.section.audio_credits".localized,
            isExpanded: .constant(expandedSection == "audioCredits"),
            onToggle: {
              expandedSection = expandedSection == "audioCredits" ? nil : "audioCredits"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.audio_credits.intro".localized)
                .font(.body)
                .foregroundStyle(themeProvider.theme.textColor)

              VStack(alignment: .leading, spacing: 8) {
                ForEach(
                  ImageCreditsLoader.shared.getAudioCredits(),
                  id: \.name,
                ) { audio in
                  VStack(alignment: .leading, spacing: 4) {
                    if let url = audio.url, let linkUrl = URL(string: url) {
                      Button(action: {
                        openURL(linkUrl)
                      }) {
                        Text(audio.credit)
                          .font(.callout)
                          .fontWeight(.semibold)
                          .foregroundStyle(themeProvider.theme.accentColor)
                      }
                      .buttonStyle(.plain)
                      .accessibilityLabel("a11y.button.external_link".localized)
                    } else {
                      Text(audio.credit)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeProvider.theme.secondaryTextColor)
                    }

                    Text("about.license.prefix".localized(audio.license))
                      .font(.caption2)
                      .foregroundStyle(themeProvider.theme.secondaryTextColor)
                  }
                }
              }

              Text("about.audio_credits.notice".localized)
                .font(.caption)
                .foregroundStyle(themeProvider.theme.secondaryTextColor)
            }
          }

          // MARK: - Open Source Licenses

          CollapsibleSection(
            "about.section.open_source".localized,
            isExpanded: .constant(expandedSection == "openSourceLicenses"),
            onToggle: {
              expandedSection = expandedSection == "openSourceLicenses" ? nil :
                "openSourceLicenses"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.open_source.intro".localized)
                .font(.body)
                .foregroundStyle(themeProvider.theme.textColor)

              Text("about.open_source.libraries".localized)
                .font(.body)
                .foregroundStyle(themeProvider.theme.textColor)

              VStack(alignment: .leading, spacing: 8) {
                LicenseRow(
                  library: "about.library.sqlite".localized,
                  license: "about.library.sqlite.license".localized,
                )
                LicenseRow(
                  library: "about.library.zstandard".localized,
                  license: "about.library.zstandard.license".localized,
                )
              }

              Text("about.open_source.footer".localized)
                .font(.caption)
                .foregroundStyle(themeProvider.theme.secondaryTextColor)
            }
          }

          // MARK: - Privacy Policy

          CollapsibleSection(
            "about.section.privacy_policy".localized,
            isExpanded: .constant(expandedSection == "privacyPolicy"),
            onToggle: {
              expandedSection = expandedSection == "privacyPolicy" ? nil : "privacyPolicy"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.privacy.intro".localized)
                .font(.headline)
                .foregroundStyle(themeProvider.theme.textColor)

              VStack(alignment: .leading, spacing: 8) {
                PrivacyRow(
                  icon: "lock.fill",
                  title: "about.privacy.no_analytics".localized,
                  description: "about.privacy.no_analytics.desc".localized,
                )
                PrivacyRow(
                  icon: "icloud.slash",
                  title: "about.privacy.local_storage".localized,
                  description: "about.privacy.local_storage.desc".localized,
                )
                PrivacyRow(
                  icon: "key.fill",
                  title: "about.privacy.open_source".localized,
                  description: "about.privacy.open_source.desc".localized,
                )
              }
            }
          }

          // MARK: - Support & Feedback

          CollapsibleSection(
            "about.section.support".localized,
            isExpanded: .constant(expandedSection == "supportFeedback"),
            onToggle: {
              expandedSection = expandedSection == "supportFeedback" ? nil : "supportFeedback"
            },
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Text("about.support.intro".localized)
                .font(.body)
                .foregroundStyle(themeProvider.theme.secondaryTextColor)

              Button(action: {
                if let url = URL(string: "https://github.com/sc-voice/scv-app/issues") {
                  openURL(url)
                }
              }) {
                HStack {
                  Image(systemName: "link")
                  Text("about.button.visit_github".localized)
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
        .frame(maxWidth: 700)
        .padding(16)
        Spacer()
      }
    } // ScrollView
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

private struct TranslationRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let dbInfo: DatabaseInfo

  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = Locale.current

    // Parse ISO 8601 timestamp (e.g., "2025-01-05T12:34:56Z")
    let isoFormatter = ISO8601DateFormatter()
    if let date = isoFormatter.date(from: dbInfo.buildTimestamp) {
      return formatter.string(from: date)
    }
    return dbInfo.buildTimestamp
  }

  private var hashDisplay: String {
    if let hash = dbInfo.gitHash, hash.count > 7 {
      return String(hash.prefix(7))
    }
    return dbInfo.gitHash ?? "—"
  }

  private var langCode: String {
    dbInfo.language.uppercased()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      // First line: Lang Code · Author Name
      HStack(spacing: 8) {
        Text(langCode)
          .font(.callout)
          .fontWeight(.semibold)
          .foregroundStyle(themeProvider.theme.textColor)
          .frame(width: 30)

        Text(dbInfo.authorName)
          .font(.callout)
          .foregroundStyle(themeProvider.theme.textColor)
          .lineLimit(1)

        Spacer()
      }

      // Second line: Hash · Date · File Count
      HStack(spacing: 12) {
        Text(hashDisplay)
          .font(.caption2)
          .foregroundStyle(themeProvider.theme.secondaryTextColor)
          .fontDesign(.monospaced)

        Text("·")
          .font(.caption2)
          .foregroundStyle(themeProvider.theme.secondaryTextColor)

        Text(formattedDate)
          .font(.caption2)
          .foregroundStyle(themeProvider.theme.secondaryTextColor)

        Text("·")
          .font(.caption2)
          .foregroundStyle(themeProvider.theme.secondaryTextColor)

        Text("about.documents".localized(String(dbInfo.files.total)))
          .font(.caption2)
          .foregroundStyle(themeProvider.theme.secondaryTextColor)

        Spacer()
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(themeProvider.theme.backgroundColor.opacity(0.5))
    .cornerRadius(4)
  }
}

// MARK: - Preview

#Preview("AboutCardView") {
  AboutCardView()
    .environmentObject(ThemeProvider())
}
