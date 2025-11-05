//
//  ThemesTests.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import XCTest
@testable import scvCore

final class ThemesTests: XCTestCase {
  func test_inverseTheme() {
    XCTAssertEqual(AppTheme.inverseTheme(.light), .dark)
    XCTAssertEqual(AppTheme.inverseTheme(.dark), .light)
  }
}
