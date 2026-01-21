# GuidStore: Swift Implementation

A file-based storage system for managing GUID-identified items with hierarchical directory organization.

## Overview

GuidStore provides persistent storage for items identified by globally unique identifiers (GUIDs). It organizes files using a hierarchical directory structure to avoid filesystem performance issues with large numbers of files in a single directory.

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

## Comparison with JavaScript Version

| Aspect | JavaScript | Swift |
|--------|------------|-------|
| Directory creation | Implicit on path resolution | Explicit, on-demand via FileManager |
| Async operations | clearVolume() async | All I/O operations via async/await |
| File iteration | Files.files() generator | FileManager URLResourceKey iteration |
| Error handling | Implicit exceptions | Throws errors to caller |
| Type safety | Dynamic options objects | Structs with defined properties |

## Related Concepts

- **GUID** - Globally unique identifier (UUID in Swift context)
- **Volume** - Logical partition for different data categories
- **Chapter** - Performance optimization for filesystem with many files
- **Signature** - Metadata object identifying stored content

See: memo-again/src/guid-store.js for reference implementation
