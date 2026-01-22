# GuidStore: Swift Implementation

A file-based storage system for managing GUID-identified items with hierarchical directory organization.

**Status**: Implemented and tested ✓
**Source**: scv-core/Sources/scvCore/GuidStore.swift
**Tests**: scv-core/Tests/GuidStoreTests.swift (6 tests, all passing)

## Overview

GuidStore provides persistent storage for items identified by globally unique identifiers (GUIDs). It organizes files using a hierarchical directory structure to avoid filesystem performance issues with large numbers of files in a single directory.

Ported from JavaScript reference implementation (memo-again/src/guid-store.js) with full Swift concurrency support.

## Directory Structure

Files are organized as:
```
storePath/
├── volume1/
│   ├── chapter_prefix_1/
│   │   ├── guid1.suffix
│   │   ├── guid2.suffix
│   │   └── ...
│   ├── chapter_prefix_2/
│   │   └── ...
│   └── ...
├── volume2/
│   └── ...
└── ...
```

**Components:**
- **storePath** - Root directory (typically in app's documents folder)
- **volume** - Logical container (e.g., "common", "cache", "user-data")
- **chapter** - Subdirectory based on GUID prefix (configurable length, default: 2 chars)
- **guid** - Full GUID filename with optional suffix (extension)

## Configuration

```swift
struct GuidStoreConfig {
    var storeName: String = "guid-store"
    var folderPrefix: Int = 2              // Chars to use for chapter subdirectory
    var suffix: String = ""                // Default file extension
    var defaultVolume: String = "common"   // Default volume name
    var storePath: URL?                    // Custom store location (auto-computed if nil)
}
```

## Core API

### Initialization

```swift
let config = GuidStoreConfig(
    storeName: "my-store",
    folderPrefix: 3,
    suffix: ".json",
    defaultVolume: "cache"
)
let store = GuidStore(config: config)
```

### Path Resolution

**guidPath(guid:volume:suffix:)**
- Resolves file path for a GUID
- Creates intermediate directories as needed
- Returns `URL` to the file location

```swift
let path = store.guidPath(guid: "abc123def456", volume: "common", suffix: ".json")
// Returns: documents/guid-store/common/ab/abc123def456.json
```

**guidPath(guid:volume:chapter:suffix:)**
- Explicit chapter specification
- Useful when chapter logic differs from prefix-based

```swift
let path = store.guidPath(
    guid: "abc123def456",
    volume: "common",
    chapter: "custom-chapter",
    suffix: ".json"
)
```

**signaturePath(signature:volume:suffix:)**
- Creates path from a signature object (dictionary/struct)
- Extracts `guid` field from signature
- Useful for complex storage scenarios

```swift
let signature = ["guid": "abc123def456", "type": "note"]
let path = store.signaturePath(signature, volume: "common", suffix: ".json")
```

### Volume Management

**listVolumes()**
- Asynchronously lists all volume names in the store
- Returns array of volume name strings
- Useful for iterating over volumes or finding orphaned data

```swift
let volumes = try await store.listVolumes()
for volume in volumes {
    print("Found volume: \(volume)")
}
```

**clearVolume(_:)**
- Asynchronously deletes all files in a volume
- Returns count of deleted files
- Useful for cache clearing or resetting state

```swift
let deletedCount = try await store.clearVolume("cache")
print("Deleted \(deletedCount) files")
```

## Usage Patterns

### Storing JSON Data

```swift
struct Note: Codable {
    let id: String
    let title: String
    let content: String
}

let note = Note(
    id: "abc123def456",
    title: "My Note",
    content: "Important information"
)

let path = store.guidPath(guid: note.id, suffix: ".json")
let encoded = try JSONEncoder().encode(note)
try encoded.write(to: path)
```

### Retrieving Data

```swift
let path = store.guidPath(guid: "abc123def456", suffix: ".json")
let data = try Data(contentsOf: path)
let note = try JSONDecoder().decode(Note.self, from: data)
```

### Cache Management

```swift
// Use separate volume for cache
let cachePath = store.guidPath(
    guid: itemId,
    volume: "cache",
    suffix: ".cache"
)

// Clear entire cache
_ = try await store.clearVolume("cache")
```

## Implementation Considerations

### Thread Safety
- GuidStore is not inherently thread-safe
- File operations should be coordinated via appropriate task isolation
- Consider protecting shared access with MainActor or actor isolation

### Directory Creation
- Automatically creates volume and chapter directories as needed
- Uses `FileManager` with `createIntermediateDirectories: true`

### Error Handling
- File I/O operations throw standard Foundation errors
- Path resolution itself doesn't throw (creates directories)
- Callers must handle file read/write errors separately

### Storage Location
- Default: `FileManager.default.urls(for: .documentDirectory).first`
- Can be customized via `config.storePath`
- Consider app requirements: Documents vs. Cache vs. Temporary

## Testing

GuidStore includes comprehensive test coverage:

**Test Suite**: GuidStoreTests (6 tests, all passing)
- ✓ Default constructor creates store with expected paths
- ✓ Custom constructor with options
- ✓ guidPath returns correct file path
- ✓ signaturePath resolves from signature dictionary
- ✓ clearVolume removes only files in specified volume
- ✓ clearVolume returns 0 for non-existent volume

Run tests:
```bash
cd scv-core && swift test --no-parallel --filter GuidStoreTests
```

## Comparison with JavaScript Version

| Aspect | JavaScript | Swift |
|--------|------------|-------|
| File path resolution | (guid, opts) with flexible overloads | Type-safe parameters, overloaded methods |
| Directory creation | Implicit on path resolution | Explicit, on-demand via FileManager |
| Async operations | clearVolume() async | clearVolume() async with proper concurrency handling |
| File iteration | Files.files() generator | Recursive FileManager.contentsOfDirectory() |
| Error handling | Implicit exceptions | Throws standard Foundation errors |
| Type safety | Dynamic options objects | Structs with defined properties |
| Thread safety | Not thread-safe | Not thread-safe; use task isolation for coordination |
| Test framework | Mocha/should.js | Swift Testing (@Suite, @Test, #expect) |

## Swift Concurrency

GuidStore is designed for Swift 6 concurrency model:

- **clearVolume()** is async/throws and can be called with `try await`
- **Path resolution methods** are synchronous and side-effect free (safe to call from any context)
- **Directory creation** happens automatically but doesn't block - uses non-throwing operations
- Recommended usage: Protect shared GuidStore instances with actor isolation or MainActor if needed

Example with concurrency:
```swift
@MainActor class AudioCacheManager {
    private let store: GuidStore

    func clearCache() async throws {
        let count = try await store.clearVolume("audio-cache")
        print("Cleared \(count) audio files")
    }

    func getCachePath(audioId: String) -> URL {
        // Path resolution is safe to call without await
        return store.guidPath(guid: audioId, volume: "audio-cache")
    }
}
```

## Implementation Details

- **Language**: Swift 6.0+
- **Minimum deployment**: iOS 16+, macOS 13+
- **Dependencies**: Foundation only
- **File operations**: Foundation FileManager API
- **Error handling**: Throws standard `CocoaError` from FileManager operations
- **Default locations**: `FileManager.default.urls(for: .documentDirectory)`

## Related Concepts

- **GUID** - Globally unique identifier (UUID in Swift context)
- **Volume** - Logical partition for different data categories
- **Chapter** - Performance optimization for filesystem with many files
- **Signature** - Metadata object identifying stored content

## References

- **Swift implementation**: scv-core/Sources/scvCore/GuidStore.swift
- **Swift tests**: scv-core/Tests/GuidStoreTests.swift
- **JavaScript reference**: memo-again/src/guid-store.js
- **JavaScript tests**: memo-again/test/guid-store.js
