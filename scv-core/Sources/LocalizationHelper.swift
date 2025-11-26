//
//  LocalizationHelper.swift
//  scv-core
//
//  Created by Visakha on 30/10/2025.
//

import Foundation

/// Global bundle for localization - configurable for testing
private let localizationBundleLock = NSLock()
private nonisolated(unsafe) var _localizationBundle = Bundle.module

var localizationBundle: Bundle {
  get {
    localizationBundleLock.withLock { _localizationBundle }
  }
  set {
    localizationBundleLock.withLock { _localizationBundle = newValue }
  }
}

public extension String {
  /// Localized version of the string
  var localized: String {
    NSLocalizedString(self, bundle: localizationBundle, comment: "")
  }

  /// Localized version with format arguments
  func localized(_ arguments: CVarArg...) -> String {
    String(
      format: NSLocalizedString(self, bundle: localizationBundle, comment: ""),
      arguments: arguments,
    )
  }
}
