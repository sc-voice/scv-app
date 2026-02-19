//
//  ThemesTests.swift
//  scv-core
//
//  Created by Visakha on 04/11/2025.
//

@testable import scvCore
import Testing

struct ThemesTests {
  @Test
  func test_inverseTheme() {
    #expect(AppTheme.inverseTheme(.light) == .dark)
    #expect(AppTheme.inverseTheme(.dark) == .light)
  }

  @Test
  func test_tipColors_dark() {
    let theme = AppTheme.dark.theme
    #expect(theme.tipBackground == .init(red: 0.106, green: 0.302, blue: 0.180))
    #expect(theme.tipForeground == .init(red: 1.0, green: 0.878, blue: 0.0))
  }

  @Test
  func test_tipColors_light() {
    let theme = AppTheme.light.theme
    #expect(theme.tipBackground == .init(red: 0.106, green: 0.302, blue: 0.180))
    #expect(theme.tipForeground == .init(red: 1.0, green: 0.878, blue: 0.0))
  }
}
