//
//  Localize.swift
//  scv-core
//
//  ## Localization Resources
//
//  Localization files stored in scv-core/Sources/Resources/{lang}.lproj/Localizable.strings
//
//  Primary language: EN
//  All EN localization keys must have corresponding translations in all supported language folders.
//
//  ## Localizable.strings Format
//
//  Keys must be sorted alphabetically.
//  Each key must be preceded by a comment explaining user context.
//  If parameters are used, an additional comment must specify what the values represent.
//
//  Examples:
//
//  Simple key with context comment:
//  ```
//  /* Synthesis modal: header title */
//  "synthesis.title" = "Preparing Audio";
//  ```
//
//  Formatted string with parameters:
//  ```
//  /* Error message when translation not found for language/author combination */
//  "translation.not.found" = "Translation not found for %@ / %@";
//  ```
//
//  Multi-parameter format requiring separate parameter comment:
//  ```
//  /* Voice synthesis error: voice not responding after timeout (format: voice name, file:line debug info) */
//  /* Parameters: 1) voice name, 2) error identifier */
//  "voice.error.not_responding" = "The \"%@\" voice is not responding. Try a different voice or enable background playback. [%@]";
//  ```
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
