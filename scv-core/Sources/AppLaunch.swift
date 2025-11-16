import Foundation
import scvMacros

/// Handles common application launch initialization
public enum AppLaunch {
  /// Initialize app launch with common setup
  public static func initialize() {
    // TODO: Use CCOK1 macro when Swift Package Manager fixes cross-package macro plugin discovery
    // Related issues:
    // - https://github.com/apple/swift-package-manager/issues/6950
    // - https://stackoverflow.com/questions/77386744/swift-macros-external-macro-implementation-type-could-not-be-found
    //
    // Current status (Swift 6.2):
    // - Macro package (scv-macros) builds successfully with plugin
    // - Macro plugin works within scv-macros package itself
    // - Dependent packages (scv-core, scv-ui) cannot find the plugin during
    // swift build
    // - Error: "external macro implementation type 'scvMacrosPlugin.CCOK1Macro'
    // could not be found"
    // - Even with swift-tools-version 6.1+ and latest SPM, plugin discovery
    // fails
    //
    // Workaround: Build through Xcode instead of command-line swift build
    //
    // When fixed, uncomment:
    // _ = #CCOK1(level: 1, "App launch initialized")

    let cc = ColorConsole(#file, #function, 1)
    let buildNumber = Bundle.main
      .infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    _ = cc.ok1(#line, "App launch initialized (Build \(buildNumber))")
  }
}
