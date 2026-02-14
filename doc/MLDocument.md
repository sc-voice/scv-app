# MLDocument API

MLDocument is the core application data structure that represents 
a SuttaCentral-aligned sutta 
using trilingual (up to three languages) segments 
keyed and aligned by SuttaCentral ID (scid).

MLDocuments are trilingual in the sense that each language fulfills a separate role:
- **Pali** The Mahāsaṅgīti root text language (i.e., Pali)
- **Document** The contemporary primary translation language (e.g., DE)
- **Reference** The contemporary reference translation language (e.g., EN)

Each MLDocument segment has the following fields:

- `scid:String` - SuttaCentral ID (see SuttaRef and SuttaCentralId) 
- `pli:String?` - the segment text obtained from the ebt-data/root/pli/ms JSON file 
- `doc:String?` - the segment text obtained from the ebt-data/translation/DOC_LANG/DOC_AUTHOR JSON file 
- `ref:String?` - the segment text obtained from the ebt-data/translation/REF_LANG/REF_AUTHOR JSON file 
- `matched:Bool?` - true if the segment matches client criteria

See: `scv-core/Sources/MLDocument.swift`

## Overview

MLDocument wraps a dictionary of segments (`segMap: [String: Segment]`) keyed by scid, along with metadata about the document. It supports:

- **Multi-language segments**: Each segment contains `doc` (document language text) and optional `pli` (Pali text)
- **Persistence**: Conforms to Codable for storage via SwiftData
- **Actor isolation**: Uses @unchecked Sendable to cross actor boundaries (being refactored)
- **Serialization**: Can export as SuttaCentral-format JSON

## Public Properties

### Core Data
- `segMap: [String: Segment]` - Segments keyed by scid (e.g., "mn1:0.1"). Mutable to support segment merging during construction.

### Sutta Reference (read-only after init)
- `sutta_uid: String` - Sutta identifier (e.g., "mn1"). Set via `public private(set)`.
- `docLang: String` - Document language code (e.g., "en", "de"). Set via `public private(set)`.
- `docAuthor: String` - Document translator/author identifier. Set via `public private(set)`.
- `docAuthorName: String` - Display name of document author. Set via `public private(set)`.

### Selection Tracking
- `currentScid: String?` - Currently selected segment ID for UI focus. Mutable to support UI interactions.

## Initializer

MLDocument uses a verbose initializer with many defaulted parameters (for Codable/SwiftData support), but in practice only the public properties are populated:

```swift
public init(
  segMap: [String: Segment] = [:],
  sutta_uid: String = "",
  docLang: String = "",
  docAuthor: String = "",
  docAuthorName: String = "",
  currentScid: String? = nil,
  // ... 29 additional private parameters with defaults
)
```

**Typical usage:** Created via the factory method `MLDocument.create()` which handles all initialization logic outside the actor.

## Methods

### Data Access

#### `segments() -> [Segment]`
Returns all segments sorted in SuttaCentral ID order.

Uses `SuttaCentralId.compareLow()` for proper numeric/alphabetic ordering (e.g., "mn1:1.1" before "mn1:1.10").

#### `var allSegments: [Segment]`
Convenience computed property returning all segments from segMap (unsorted).

#### `var matchedSegments: [Segment]`
Convenience computed property filtering to only segments with `matched == true`.

Useful for search results showing only matches.

### Display

#### `var computedTitle: String`
Returns best-guess title in precedence order:

1. Use `title` field if non-empty
2. Extract first sentence from `blurb`
3. Fall back to `sutta_uid`

#### `indexOfScid(_ scid: String) -> Int?`
Returns the index of a segment in the sorted segments array.

Useful for navigating UI lists by scid.

### Serialization

#### `asSuttaCentralJson() -> String?`
Exports segments as SuttaCentral-format JSON.

Returns dictionary `{"scid": "text", ...}` with:
- Sorted keys for stable output
- 2-space indentation
- Segment text from `segment.doc`

Example output:
```json
{
  "an1.1:0.1": "Numbered Discourses 1.1–10",
  "an1.1:0.2": "The Chapter on Ones",
  "an1.1:1.1": ""
}
```

## Factory Method (Planned)

### `create(suttaRef:docSegments:pliSegments:) -> MLDocument`

Static factory to construct MLDocument from Sendable segment data, enabling safe actor boundary crossing.

**Parameters:**
- `suttaRef: SuttaRef` - Source sutta reference with lang, author, suttaUid
- `docSegments: [Segment]` - Document language segments (Sendable)
- `pliSegments: [Segment]` - Pali segments (Sendable)

**Returns:** MLDocument with segments merged

**Behavior:**
- If `suttaRef.lang == "pli"`: Use docSegments as both doc and pli
- Otherwise: Merge pliSegments' text into docSegments' pli field
- Populate metadata from suttaRef

**Usage:** Called outside actor with Sendable segment arrays, returns non-Sendable MLDocument.

## Private Properties

MLDocument has 29 private properties that are not exposed in the public API:
- Metadata: `author`, `author_uid`, `title`, `blurb`, `category`, `type`, `footer`, `hyphen`
- Search/stats: `score`, `segsMatched`, `minWord`, `maxWord`, `stats`, `langSegs`, `trilingual`
- Data sources: `bilaraPaths`, `lang`
- Reference language: `refLang`, `refAuthor`, `refAuthorName`, `refFooter`
- Document footer: `docFooter`

These are maintained for Codable/persistence but are not used by the application. Future refactoring can remove them.

## Codable Conformance

MLDocument implements full Codable support via explicit encode/decode methods. All properties (public and private) are encoded/decoded to support SwiftData persistence.

## Actor Isolation

Currently marked with `@unchecked Sendable` to cross EbtData actor boundary. Refactoring extracts segment building to factory method, allowing removal of unsafe annotation.

