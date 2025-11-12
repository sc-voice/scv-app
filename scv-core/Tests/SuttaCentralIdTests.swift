//
//  SuttaCentralIdTests.swift
//  scv-core
//
//  Created by Claude on 2025-11-01.
//

import Foundation
@testable import scvCore
import Testing

@Suite
struct SuttaCentralIdTests {
    // MARK: - Initialization Tests

    @Test
    func initializationWithValidScid() throws {
        let scid = try SuttaCentralId("mn1.1")
        #expect(scid.scid == "mn1.1")
    }

    @Test
    func initializationWithNilThrows() {
        #expect(throws: SuttaCentralIdError.self) {
            try SuttaCentralId(nil)
        }
    }

    @Test
    func initializationWithComplexScid() throws {
        let scid = try SuttaCentralId("sn45.8:1.2")
        #expect(scid.scid == "sn45.8:1.2")
    }

    // MARK: - Basename Tests

    @Test
    func basenameExtractsLastComponent() {
        let result = SuttaCentralId.basename("root/pli/ms/sutta/mn1_root-pli-ms.json")
        #expect(result == "mn1_root-pli-ms.json")
    }

    @Test
    func basenameWithSingleComponent() {
        let result = SuttaCentralId.basename("filename.txt")
        #expect(result == "filename.txt")
    }

    @Test
    func basenameWithEmptyString() {
        let result = SuttaCentralId.basename("")
        #expect(result == "")
    }

    // MARK: - Test Method Tests

    @Test
    func validScidFormat() {
        #expect(SuttaCentralId.test("mn1.1"))
        #expect(SuttaCentralId.test("sn45.8"))
        #expect(SuttaCentralId.test("thig1.1"))
        #expect(SuttaCentralId.test("dn1"))
    }

    @Test
    func validScidWithSpaces() {
        #expect(SuttaCentralId.test("mn 1.1"))
        #expect(SuttaCentralId.test("sn 45.8"))
    }

    @Test
    func multipleScids() {
        #expect(SuttaCentralId.test("mn1.1, sn45.8"))
        #expect(SuttaCentralId.test("mn1.1, sn45.8, thig1.1"))
    }

    @Test
    func invalidFormat() {
        #expect(!SuttaCentralId.test("invalid"))
        #expect(!SuttaCentralId.test("123"))
    }

    @Test
    func caseInsensitive() {
        #expect(SuttaCentralId.test("MN1.1"))
        #expect(SuttaCentralId.test("SN45.8"))
    }

    // MARK: - Languages Tests

    @Test
    func languagesExtractsLanguageCodes() {
        let result = SuttaCentralId.languages("mn1.1/en/sujato")
        #expect(result == ["en"])
    }

    @Test
    func languagesMultipleLanguages() {
        let result = SuttaCentralId.languages("mn1.1/en/sujato, mn1.1/pli/ms")
        #expect(result.contains("en"))
        #expect(result.contains("pli"))
    }

    @Test
    func languagesInvalidScid() {
        let result = SuttaCentralId.languages("invalid")
        #expect(result.isEmpty)
    }

    @Test
    func languagesCaseInsensitive() {
        let result = SuttaCentralId.languages("MN1.1/EN/sujato")
        #expect(result == ["en"])
    }

    // MARK: - Range Tests

    @Test
    func rangeLowSimpleId() {
        let result = SuttaCentralId.rangeLow("mn1.1")
        #expect(result == "mn1.1")
    }

    @Test
    func rangeLowWithRange() {
        let result = SuttaCentralId.rangeLow("mn1-5")
        #expect(result == "mn1")
    }

    @Test
    func rangeLowWithSuffix() {
        let result = SuttaCentralId.rangeLow("mn1.1-3/en")
        #expect(result == "mn1.1/en")
    }

    @Test
    func rangeHighSimpleId() {
        let result = SuttaCentralId.rangeHigh("mn1.1")
        #expect(result == "mn1.1")
    }

    @Test
    func rangeHighWithRange() {
        let result = SuttaCentralId.rangeHigh("mn1-5:1")
        #expect(result == "mn5:1.9999")
    }

    @Test
    func rangeHighWithoutSegment() {
        let result = SuttaCentralId.rangeHigh("mn1-5")
        #expect(result == "mn5")
    }

    // MARK: - PartNumber Tests

    @Test
    func partNumberSimpleInteger() throws {
        let result = try SuttaCentralId.partNumber("5", "mn1.1")
        #expect(result == [5])
    }

    @Test
    func partNumberWithLetterSuffix() throws {
        let result = try SuttaCentralId.partNumber("1a", "mn1.1")
        #expect(result.count == 2)
        #expect(result[0] == 1)
        #expect(result[1] == 1) // 'a' is the 1st letter
    }

    @Test
    func partNumberWithMultipleLetters() throws {
        let result = try SuttaCentralId.partNumber("mn1", "mn1:50.2")
        #expect(result.count == 2)
        #expect(result[0] == 1)
        #expect(result[1] == 13) // 'm' is the 13th letter
    }

    @Test
    func partNumberInvalidThrows() {
        #expect(throws: SuttaCentralIdError.self) {
            try SuttaCentralId.partNumber("xyz", "mn1.1")
        }
    }

    // MARK: - Sutta Property Tests

    @Test
    func suttaPropertySimple() throws {
        let scid = try SuttaCentralId("mn1.1")
        #expect(scid.sutta == "mn1.1")
    }

    @Test
    func suttaPropertyWithSegments() throws {
        let scid = try SuttaCentralId("mn1.1:1.2")
        #expect(scid.sutta == "mn1.1")
    }

    // MARK: - Groups Property Tests

    @Test
    func groupsPropertyWithSegments() throws {
        let scid = try SuttaCentralId("mn1.1:1.2.3")
        #expect(scid.groups == ["1", "2", "3"])
    }

    @Test
    func groupsPropertyWithoutSegments() throws {
        let scid = try SuttaCentralId("mn1.1")
        #expect(scid.groups == nil)
    }

    // MARK: - Nikaya Property Tests

    @Test
    func nikayaPropertyBasic() throws {
        let scid = try SuttaCentralId("mn1.1")
        #expect(scid.nikaya == "mn")
    }

    @Test
    func nikayaPropertyComplex() throws {
        let scid = try SuttaCentralId("tha-ap1.1:1.2")
        #expect(scid.nikaya == "tha-ap")
    }

    // MARK: - Parent Property Tests

    @Test
    func parentPropertyWithGroups() throws {
        let scid = try SuttaCentralId("mn1:2.3.4")
        let parent = scid.parent
        #expect(parent != nil)
        #expect(parent?.scid == "mn1:2.3.")
    }

    @Test
    func parentPropertyAtRoot() throws {
        let scid = try SuttaCentralId("mn1:2.")
        let parent = scid.parent
        #expect(parent != nil)
        #expect(parent?.scid == "mn1:")
    }

    @Test
    func parentPropertyWithoutSegments() throws {
        let scid = try SuttaCentralId("mn1.1")
        let parent = scid.parent
        #expect(parent == nil)
    }

    // MARK: - StandardForm Tests

    @Test
    func standardFormConversion() throws {
        let scid = try SuttaCentralId("mn1.1")
        #expect(scid.standardForm() == "MN1.1")
    }

    @Test
    func standardFormMultipleAbbreviations() throws {
        let scid = try SuttaCentralId("sn45.8:1.2")
        #expect(scid.standardForm() == "SN45.8:1.2")
    }

    @Test
    func standardFormThig() throws {
        let scid = try SuttaCentralId("thig1.1")
        #expect(scid.standardForm() == "Thig1.1")
    }

    // MARK: - SectionParts Tests

    @Test
    func sectionPartsSimple() throws {
        let scid = try SuttaCentralId("mn1.2.3")
        #expect(scid.sectionParts() == ["mn1", "2", "3"])
    }

    @Test
    func sectionPartsWithSegment() throws {
        let scid = try SuttaCentralId("mn1.2:3.4")
        #expect(scid.sectionParts() == ["mn1", "2"])
    }

    // MARK: - SegmentParts Tests

    @Test
    func segmentPartsWithSegment() throws {
        let scid = try SuttaCentralId("mn1.1:1.2.3")
        #expect(scid.segmentParts() == ["1", "2", "3"])
    }

    @Test
    func segmentPartsWithoutSegment() throws {
        let scid = try SuttaCentralId("mn1.1")
        #expect(scid.segmentParts() == nil)
    }

    // MARK: - Add Tests

    @Test
    func addToDocumentId() throws {
        let scid = try SuttaCentralId("mn1.1")
        let result = try scid.add(0, 2)
        #expect(result.scid == "mn1.3")
    }

    @Test
    func addToSegmentId() throws {
        let scid = try SuttaCentralId("mn1.1:1.2")
        let result = try scid.add(0, 1)
        #expect(result.scid == "mn1.1:1.3")
    }

    @Test
    func addMultipleIncrements() throws {
        let scid = try SuttaCentralId("mn1.1.1")
        let result = try scid.add(1, 2, 3)
        #expect(result.scid == "mn2.3.4")
    }

    // MARK: - Description Tests

    @Test
    func descriptionReturnsScid() throws {
        let scid = try SuttaCentralId("mn1.1")
        #expect(scid.description == "mn1.1")
    }

    // MARK: - Match Tests

    @Test
    func matchExactMatch() {
        #expect(SuttaCentralId.match("mn1.1", "mn1.1"))
    }

    @Test
    func matchWithPattern() {
        #expect(SuttaCentralId.match("mn1.1", "mn1.*"))
    }

    @Test
    func matchRangeInclusion() {
        #expect(SuttaCentralId.match("mn1.3", "mn1.1-5"))
    }

    @Test
    func matchRangeExclusion() {
        #expect(!SuttaCentralId.match("mn1.6", "mn1.1-5"))
    }

    @Test
    func matchMultiplePatterns() {
        #expect(SuttaCentralId.match("mn1.1", "sn45.8, mn1.1, dn1"))
    }

    // MARK: - Compare Tests

    @Test
    func compareHighEqualIds() {
        let result = SuttaCentralId.compareHigh("mn1", "mn1")
        #expect(result == 0)
    }

    @Test
    func compareHighGreater() {
        let result = SuttaCentralId.compareHigh("mn2", "mn1")
        #expect(result > 0)
    }

    @Test
    func compareHighLess() {
        let result = SuttaCentralId.compareHigh("mn1", "mn2")
        #expect(result < 0)
    }

    @Test
    func compareLowEqualIds() {
        let result = SuttaCentralId.compareLow("mn1", "mn1")
        #expect(result == 0)
    }

    @Test
    func compareLowGreater() {
        let result = SuttaCentralId.compareLow("mn2", "mn1")
        #expect(result > 0)
    }

    @Test
    func compareLowLess() {
        let result = SuttaCentralId.compareLow("mn1", "mn2")
        #expect(result < 0)
    }

    // MARK: - ScidRegExp Tests

    @Test
    func scidRegExpWithGlobPattern() throws {
        let regex = SuttaCentralId.scidRegExp("mn*")
        #expect(regex != nil)
    }

    @Test
    func scidRegExpNilPattern() throws {
        let regex = SuttaCentralId.scidRegExp(nil)
        #expect(regex != nil)
    }

    @Test
    func scidRegExpEmptyPattern() throws {
        let regex = SuttaCentralId.scidRegExp("")
        #expect(regex != nil)
    }

    // MARK: - Real-world Examples

    @Test
    func realWorldMajjhimaNikayaId() throws {
        let scid = try SuttaCentralId("mn1.1:1.2")
        #expect(scid.sutta == "mn1.1")
        #expect(scid.nikaya == "mn")
        #expect(scid.groups == ["1", "2"])
        #expect(scid.standardForm() == "MN1.1:1.2")
    }

    @Test
    func realWorldSamyuttaNikayaId() throws {
        let scid = try SuttaCentralId("sn45.8:1.2.3")
        #expect(scid.sutta == "sn45.8")
        #expect(scid.nikaya == "sn")
        #expect(scid.groups?.count == 3)
    }

    @Test
    func realWorldThigAthaId() throws {
        let scid = try SuttaCentralId("thig1.1")
        #expect(scid.nikaya == "thig")
        #expect(scid.standardForm() == "Thig1.1")
    }

    @Test
    func realWorldDhammapada() throws {
        let scid = try SuttaCentralId("dhp1")
        #expect(scid.sutta == "dhp1")
        #expect(scid.nikaya == "dhp")
    }
}
