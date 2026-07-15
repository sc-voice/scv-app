import Foundation
import Testing

@testable import scvCore

@Suite struct AppUpdateCheckerTests {
  /// Requires a live network connection to the App Store (itunes.apple.com).
  @Test func checkForUpdateAgainstLiveAppStore() async throws {
    let storeVersion = await AppUpdateChecker.checkForUpdate(currentVersion: "")
    let storeVersionUnwrapped = try #require(storeVersion)

    let sameVersionResult = await AppUpdateChecker.checkForUpdate(
      currentVersion: storeVersionUnwrapped.version,
    )

    #expect(sameVersionResult == nil)
  }
}
