# SC-Voice (scv-app)

A localizable Swift application for searching and viewing Buddhist suttas (scriptures). The app provides a card-based interface where users can create multiple search and sutta viewer cards, with persistent data management via SwiftData.

Inspired by SC-Voice.net and authored by Friends of SC-Voice

## Features

- **Card-Based Interface** - Create and manage multiple search and sutta viewer cards
- **Search Functionality** - Search Buddhist scriptures with structured responses
- **Persistence** - SwiftData-based data persistence without external dependencies
- **Multi-Language Support** - Localized UI with English and Portuguese
- **Type-Safe Architecture** - Modern Swift with strong type system and data validation

## Project Structure

```
scv-app/
├── scv-core/               # Main Swift package
│   ├── Sources/scvCore/    # Core library implementation
│   ├── Tests/scvCoreTests/ # Comprehensive test suite
│   └── Resources/          # Localization strings and test data
├── Makefile                # Build automation
├── CLAUDE.md              # Development guidelines
└── README.md              # This file
```

## Core Components

### Card Model
Represents either a search card or sutta viewer card with:
- Type-safe `CardType` enum (`.search` | `.sutta`)
- Metadata: uuid, createdAt, name, typeId
- Search-specific: searchQuery, searchResults
- Sutta-specific: suttaReference
- Automatic localized display names

### CardManager
Observable state manager for card operations:
- CRUD operations with SwiftData persistence
- Card selection management
- Automatic default card creation
- Type-specific card tracking

### SearchResponse
Structures for Buddhist scripture search results:
- Nested metadata and results hierarchy
- Bilingual content (Pali/English) via MLDocument array
- Error handling with SearchErrorInfo
- Full Codable implementation

## Building and Testing

### Requirements
- Swift 6.0+
- iOS 26+ / macOS 15+
- No external package dependencies

### Run All Tests
```bash
make test
```

### Run Core Package Tests
```bash
# Standard run (serial - required for localization testing)
make test-core

# Verbose output
make test-core-verbose
```

### Run Specific Test
```bash
cd scv-core && swift test --filter CardTests
```

### Build Project
```bash
make build
```

### Clean Build Artifacts
```bash
make clean
```

## Build Management

The app includes pre-built, compressed SQLite databases with Buddhist scripture translations. These are bundled in the app and decompressed on first use.

### Building Databases

To rebuild databases after schema changes or to add new translations:

```bash
swift run scv-build en:sujato          # Build single database
swift run scv-build en:sujato de:sabbamitta  # Build multiple
swift run scv-build --rebuild-from-manifest  # Rebuild all from db-manifest.json
```

Generated `.zst` files are placed in `scv-core/Sources/Resources/` and automatically included in the app bundle.

### Schema Versioning

When EbtData code changes how it interprets database data:
1. Increment `EbtData.schemaVersion` in `scv-core/Sources/EbtData.swift`
2. Run scv-build to regenerate databases
3. New databases automatically embed the new schema version
4. Cached databases on devices with mismatched schema are auto-rebuilt

### For More Details

See `scv-build/README.md` for comprehensive documentation on:
- Database building and manifest management
- Schema definition and FTS configuration
- Distribution workflow and troubleshooting

## Architecture

### Patterns
- **Observable Pattern** - CardManager provides reactive state updates
- **Model/ViewModel Separation** - Card (model) and CardManager (view model)
- **Type Safety** - Enum-based card types with structured data
- **Dependency Injection** - ModelContext passed to CardManager
- **No External Dependencies** - Pure Swift implementation

### Localization
- String resources in `Resources/`
- Dynamic bundle swapping for multi-language testing
- Supported languages: English (en), Portuguese (pt-PT)

## Testing

The project includes comprehensive tests covering:
- Card model validation and edge cases
- CardManager operations (CRUD, concurrent operations)
- SearchResponse parsing and validation
- Localization with multiple language bundles
- Type constraints (e.g., typeId uniqueness per cardType)

**Note:** Tests must run serially (not in parallel) due to global mutable localization bundle swapping during testing.

## Development Workflow

See `CLAUDE.md` for development guidelines, testing requirements, and project conventions.

## License

See project root for license information.
