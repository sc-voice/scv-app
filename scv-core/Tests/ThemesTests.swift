//
//  ThemesTests.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

import Testing
@testable import scvCore

struct ThemesTests {
  @Test
  func test_inverseTheme() {
    #expect(AppTheme.inverseTheme(.light) == .dark)
    #expect(AppTheme.inverseTheme(.dark) == .light)
  }
}
