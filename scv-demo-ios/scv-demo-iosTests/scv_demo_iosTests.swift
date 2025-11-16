//
//  scv_demo_iosTests.swift
//  scv-demo-iosTests
//
//  Created by Visakha on 03/11/2025.
//

@testable import scv_demo_ios
import Testing

struct scv_demo_iosTests {
  @Test func uRLHandlerExtractsQueryParameter() {
    let url = URL(string: "sc-voice://search?q=dukkha")!
    let query = URLHandler.extractSearchQuery(from: url)
    #expect(query == "dukkha")
  }

  @Test func uRLHandlerWithMultipleParameters() {
    let url = URL(string: "sc-voice://search?q=anicca&lang=en")!
    let query = URLHandler.extractSearchQuery(from: url)
    #expect(query == "anicca")
  }

  @Test func uRLHandlerWithMissingQParameter() {
    let url = URL(string: "sc-voice://search?lang=en")!
    let query = URLHandler.extractSearchQuery(from: url)
    #expect(query == nil)
  }

  @Test func uRLHandlerWithEmptyQueryValue() {
    let url = URL(string: "sc-voice://search?q=")!
    let query = URLHandler.extractSearchQuery(from: url)
    #expect(query == "")
  }

  @Test func uRLHandlerWithSpecialCharacters() {
    let url = URL(string: "sc-voice://search?q=hello%20world")!
    let query = URLHandler.extractSearchQuery(from: url)
    #expect(query == "hello world")
  }
}
