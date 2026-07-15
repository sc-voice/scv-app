import Foundation

public enum AppUpdateChecker {
  public struct UpdateInfo {
    public let version: String
    public let storeURL: URL
  }

  private struct AppStoreLookupResult: Decodable {
    let results: [VersionInfo]

    struct VersionInfo: Decodable {
      let version: String
      let trackViewUrl: String
    }
  }

  public static func checkForUpdate(
    bundleId: String = "net.sc-voice.app",
    currentVersion: String? = nil,
    urlSession: URLSession = .shared,
  ) async -> UpdateInfo? {
    let version = currentVersion ?? marketingVersion
    guard let url = URL(
      string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)",
    ) else {
      return nil
    }

    do {
      let (data, _) = try await urlSession.data(from: url)
      let decoder = JSONDecoder()
      let result = try decoder.decode(AppStoreLookupResult.self, from: data)

      guard let versionInfo = result.results.first else {
        return nil
      }

      guard versionInfo.version != version else {
        return nil
      }

      guard let storeURL = URL(string: versionInfo.trackViewUrl) else {
        return nil
      }

      return UpdateInfo(version: versionInfo.version, storeURL: storeURL)
    } catch {
      return nil
    }
  }
}
