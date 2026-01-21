//
//  GuidStoreTests.swift
//  scv-coreTests
//
//  Created by Claude on 2026-01-21.
//

import Foundation
import Testing

@testable import scvCore

@Suite struct GuidStoreTests {
    private let fileManager = FileManager.default

    @Test("default constructor creates store with expected paths")
    func defaultConstructor() throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = GuidStoreConfig(storePath: tempDir)
        let store = GuidStore(config: config)

        #expect(store.storePath == tempDir)
        #expect(store.folderPrefix == 2)
        #expect(store.suffix == "")
        #expect(store.defaultVolume == "common")
        #expect(fileManager.fileExists(atPath: store.storePath.path))

        try fileManager.removeItem(at: tempDir)
    }

    @Test("custom constructor with options")
    func customConstructor() throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = GuidStoreConfig(
            storeName: "sounds",
            folderPrefix: 3,
            suffix: ".ogg",
            defaultVolume: "audio",
            storePath: tempDir
        )
        let store = GuidStore(config: config)

        #expect(store.storePath == tempDir)
        #expect(store.folderPrefix == 3)
        #expect(store.suffix == ".ogg")
        #expect(store.defaultVolume == "audio")
        #expect(fileManager.fileExists(atPath: store.storePath.path))

        try fileManager.removeItem(at: tempDir)
    }

    @Test("guidPath returns correct file path")
    func guidPathBasic() throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = GuidStoreConfig(storePath: tempDir)
        let store = GuidStore(config: config)

        let guid = "abc123def456"
        let guidDir = String(guid.prefix(2))

        // Test basic path
        let path = store.guidPath(guid: guid, suffix: ".gif")
        let expectedPath = tempDir
            .appendingPathComponent("common")
            .appendingPathComponent(guidDir)
            .appendingPathComponent(guid + ".gif")

        #expect(path == expectedPath)

        // Test with custom volume and chapter
        let volume = "test-volume"
        let chapter = "test-chapter"
        let customPath = store.guidPath(guid: "tv-tc-1.2.3", volume: volume, chapter: chapter, suffix: ".json")
        let expectedCustomPath = tempDir
            .appendingPathComponent(volume)
            .appendingPathComponent(chapter)
            .appendingPathComponent("tv-tc-1.2.3.json")

        #expect(customPath == expectedCustomPath)

        try fileManager.removeItem(at: tempDir)
    }

    @Test("signaturePath resolves from signature dictionary")
    func signaturePathBasic() throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = GuidStoreConfig(storePath: tempDir)
        let store = GuidStore(config: config)

        let guid = "abc123def456"
        let guidDir = String(guid.prefix(2))
        let signature = ["guid": guid]

        let path = store.signaturePath(signature, suffix: ".txt")
        let expectedPath = tempDir
            .appendingPathComponent("common")
            .appendingPathComponent(guidDir)
            .appendingPathComponent(guid + ".txt")

        #expect(path == expectedPath)

        // Test with custom store and default suffix
        let config2 = GuidStoreConfig(
            storeName: "sounds",
            suffix: ".ogg",
            storePath: tempDir.appendingPathComponent("sounds")
        )
        let store2 = GuidStore(config: config2)
        let signature2 = ["guid": guid]
        let path2 = store2.signaturePath(signature2)
        let expectedPath2 = tempDir
            .appendingPathComponent("sounds")
            .appendingPathComponent("common")
            .appendingPathComponent(guidDir)
            .appendingPathComponent(guid + ".ogg")

        #expect(path2 == expectedPath2)

        try fileManager.removeItem(at: tempDir)
    }

    @Test("clearVolume removes only files in specified volume")
    func clearVolumeRemovesFiles() async throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = GuidStoreConfig(storePath: tempDir)
        let store = GuidStore(config: config)

        // Create files in different volumes
        let fDel1 = store.guidPath(guid: "del1", volume: "clear")
        let fDel2 = store.guidPath(guid: "del2", volume: "clear")
        let fSave = store.guidPath(guid: "54321", volume: "save")

        try "delete-me".write(to: fDel1, atomically: true, encoding: .utf8)
        try "delete-me".write(to: fDel2, atomically: true, encoding: .utf8)
        try "save-me".write(to: fSave, atomically: true, encoding: .utf8)

        // Verify files exist
        #expect(fileManager.fileExists(atPath: fDel1.path))
        #expect(fileManager.fileExists(atPath: fDel2.path))
        #expect(fileManager.fileExists(atPath: fSave.path))

        // Clear only the "clear" volume
        let count = try await store.clearVolume("clear")

        // Verify results
        #expect(count == 2)
        #expect(!fileManager.fileExists(atPath: fDel1.path))
        #expect(!fileManager.fileExists(atPath: fDel2.path))
        #expect(fileManager.fileExists(atPath: fSave.path))

        try fileManager.removeItem(at: tempDir)
    }

    @Test("clearVolume returns 0 for non-existent volume")
    func clearVolumeNonExistent() async throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = GuidStoreConfig(storePath: tempDir)
        let store = GuidStore(config: config)

        let count = try await store.clearVolume("non-existent")
        #expect(count == 0)

        try fileManager.removeItem(at: tempDir)
    }
}
