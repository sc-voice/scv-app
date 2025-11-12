//
//  LocalizationHelper.swift
//  scv-core
//
//  Created by Visakha on 30/10/2025.
//

import Foundation

/// Global bundle for localization - configurable for testing
@MainActor
var localizationBundle = Bundle.module

extension String {
    /// Localized version of the string
    @MainActor
    var localized: String {
        return NSLocalizedString(self, bundle: localizationBundle, comment: "")
    }

    /// Localized version with format arguments
    @MainActor
    func localized(_ arguments: CVarArg...) -> String {
        return String(
            format: NSLocalizedString(self, bundle: localizationBundle, comment: ""),
            arguments: arguments
        )
    }
}
