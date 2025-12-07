//
//  BundleExtension.swift
//  scv-ui
//
//  Created by Claude on 2025-12-06.
//

import Foundation

extension Bundle {
  /// Returns the scvUI package bundle, handling both app and preview contexts
  static var scvUI: Bundle {
    // Try to find the module bundle first
    #if DEBUG
      // In preview context, search for the bundle in simulator directory
      let bundleName = "scvUI_scvUI"

      // Search candidates:
      // 1. Main bundle (when running in app)
      // 2. Framework bundle (when running as framework)
      // 3. Preview bundle (when running in Xcode preview)
      let candidates = [
        Bundle.main.resourceURL?.appendingPathComponent(bundleName + ".bundle"),
        // Preview context - search in app's Frameworks directory
        Bundle.main.bundleURL.appendingPathComponent("Frameworks")
          .appendingPathComponent(bundleName + ".bundle"),
        // Simulator preview context
        Bundle.main.bundleURL.deletingLastPathComponent()
          .appendingPathComponent(bundleName + ".bundle"),
      ]

      for candidate in candidates {
        if let candidate,
           FileManager.default.fileExists(atPath: candidate.path)
        {
          if let bundle = Bundle(url: candidate) {
            return bundle
          }
        }
      }
    #endif

    // Fallback to module bundle
    return .module
  }
}
