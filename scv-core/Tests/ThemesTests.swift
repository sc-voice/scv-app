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
}
