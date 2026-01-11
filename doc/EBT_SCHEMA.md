# EBT Database Schema

SC-Voice uses per-author SQLite databases to store Buddhist scripture translations. This document describes the database structure, build process, and query patterns.

## Overview

- **Purpose**: Efficient full-text search and segment retrieval for Buddhist suttas (scriptures)
- **Architecture**: One database per language/author combination (e.g., `ebt-en-sujato.db`)
- **Storage**: Compressed with zstd in app bundle; decompressed to app Caches on first use
- **Access Layer**: `EbtData` actor (thread-safe via Swift actor isolation)

## Database Schema

### 1. metaprops table (NEW)
Schema-free key/value store for database properties. Replaces fixed-column metadata table to enable adding new properties without schema migrations.

```sql
CREATE TABLE metaprops (
  key TEXT PRIMARY KEY,
  value TEXT
);
```

**Required keys (always present):**
- `language`: Language code (e.g., "en", "de", "fr")
- `author`: Author identifier (e.g., "sujato", "sabbamitta")
- `author_name`: Human-readable author name
- `author_type`: Author type ("root" or "translator")
- `git_hash`: Git commit hash of ebt-data repository HEAD
- `git_hash_timestamp`: ISO 8601 timestamp of ebt-data commit
- `build_timestamp`: ISO 8601 timestamp when database was built
- `schema_version`: Database schema version number
- `files_sutta`: Integer count of sutta files
- `files_vinaya`: Integer count of vinaya files
- `files_other`: Integer count of other files

**Optional keys (present only if available):**
- `author_url`: URL for author info page (if available)

**Example:**
```
key                | value
-------------------|----------------------------
language           | en
author             | sujato
author_name        | Bhikkhu Sujato
author_type        | translator
git_hash           | e698ed7a40cd12509f88e1ddc
git_hash_timestamp | 2025-12-19T04:13:06Z
build_timestamp    | 2025-12-19T04:13:06Z
schema_version     | 7
files_sutta        | 4167
files_vinaya       | 0
files_other        | 0
```

**Benefits:**
- New properties can be added without schema migrations
- Each database is self-contained with its own metadata
- Easy to query: `SELECT value FROM metaprops WHERE key='git_hash'`
- Easy to update: `INSERT OR REPLACE INTO metaprops VALUES (?, ?)`

---

### 2. metadata table (DEPRECATED)
**Migration**: This table is being replaced by `metaprops`. Databases will support both tables during transition period, with gradual migration to metaprops. Once all code uses metaprops, this table will be dropped.

Original schema (for reference):
```sql
CREATE TABLE metadata (
  language TEXT,
  author TEXT,
  author_name TEXT,
  git_hash TEXT,
  build_timestamp TEXT,
  files INTEGER,
  files_breakdown TEXT,
  json TEXT,
  schema_version TEXT,
  PRIMARY KEY (language, author)
);
```

**Why replaced:**
- Fixed columns require schema migrations to add new properties
- metaprops key/value model avoids schema changes
- Reduces coupling between app and database schema versions

---

### 3. suttas table
Index of all suttas (scripture documents) in the database.

```sql
CREATE TABLE suttas (
  suttaUid TEXT PRIMARY KEY,
  total_segments INTEGER
);
```

**Columns:**
- `suttaUid`: Unique sutta identifier in format `scid` (language and author stored separately in database path)
  - Example: `mn1`, `an1.1`, `dn1`
- `total_segments`: Number of segments in this sutta

**Example:**
```
suttaUid | total_segments
---------|----------------
mn1      | 47
an1.1    | 3
dn1      | 152
```

**Note:** Language and author are implicit in the database file path (e.g., `ebt-en-sujato.db` contains English translations by Bhikkhu Sujato).

---

### 4. segments table
Individual text segments of suttas, with lemmatized forms for advanced search.

```sql
CREATE TABLE segments (
  suttaUid TEXT,
  scid TEXT,
  text TEXT,
  lemmas TEXT
);
```

**Columns:**
- `suttaUid`: Reference to sutta (e.g., `an1.2`) - matches suttas.suttaUid
- `scid`: Unique segment identifier within sutta (e.g., `an1.2:1.0`, `an1.2:1.1`)
  - Format: `scid:section.subsegment`
  - `:0.0` and `:0.1` are headers; `:1.1`, `:1.2`, etc. are content
- `text`: The actual text content of the segment
- `lemmas`: Space-padded lemmatized forms of words, used for lemma-based search
  - Example: "men shaving their heads" → " man shave their head "

**Example:**
```
suttaUid | scid       | text                              | lemmas
---------|------------|-----------------------------------|-----------------------------------
an1.2    | an1.2:1.0  | 2                                 |  2
an1.2    | an1.2:1.1  | Mendicants, I do not see a...     |  mendicant i do not see a...
an1.2    | an1.2:1.2  | The sound of a woman occupies...  |  the sound of a woman occupy...
```

---

## Build Process

The `build-ebt-data` Swift script builds databases from JSON translation files.

### Input Data Structure

```
local/ebt-data/translation/
├── en/                          # Language directory
│   └── sujato/                  # Author directory
│       ├── sutta/               # Sutta translations
│       │   ├── dn/
│       │   │   └── dn1_translation-en-sujato.json
│       │   ├── mn/
│       │   │   └── mn1_translation-en-sujato.json
│       │   └── an/
│       │       └── an1.1_translation-en-sujato.json
│       └── vinaya/              # Monastic law translations
│           └── pli-tv-bi-vb/
│               └── pli-tv-bi-vb1_translation-en-sujato.json
├── de/
│   └── sabbamitta/
│       ├── sutta/
│       └── vinaya/
└── fr/
    └── noeismet/
        └── sutta/
```

### JSON File Format

Each JSON file represents a sutta with segments as key-value pairs:

```json
{
  "mn1:1.0": "Middle Length Discourses 1",
  "mn1:1.1": "The Root of Suffering",
  "mn1:1.2": "Thus have I heard. At one time the Buddha...",
  "mn1:1.3": "It leads solely to disenchantment, to dispassion...",
  ...
}
```

**Segment ID Format:**
- `mn1:1.0` - Section number + heading (0.0, 0.1, 0.2...)
- `mn1:1.1`, `mn1:1.2` - Content segments

### Build Steps

1. **Parse arguments**: Extract `lang:author` pairs from command line
2. **Create schema**: Create metadata, suttas, and segments tables
3. **Insert metadata**: Store translation metadata with schema version number
4. **Process JSON files**: For each translation file:
   - Extract SCID from filename (e.g., `mn1` from `mn1_translation-en-sujato.json`)
   - Parse JSON to extract segments
   - Lemmatize each segment text using language-specific Lemmatizer
   - Insert sutta into `suttas` table with segment count
   - Insert each segment into `segments` table with original text and lemmatized forms
5. **Compress**: Compress database with zstd to reduce bundle size (~82% reduction)
6. **Generate manifest**: Create `db-manifest.json` for app to discover available databases

### Build Example

```bash
./scripts/build-ebt-data en:sujato de:sabbamitta
```

**Output:**
```
Building selected databases: en/sujato, de/sabbamitta
  Building ebt-en-sujato.db...
    ✓ 5235 suttas, 427193 segments (89.3 MB)
    ✓ Compressed to 15.2 MB (82.9% reduction)
  Building ebt-de-sabbamitta.db...
    ✓ 3200 suttas, 285104 segments (62.1 MB)
    ✓ Compressed to 9.8 MB (84.2% reduction)

SUCCESS: Built 2 author databases
  Total: 8435 suttas, 712297 segments
  Time elapsed: 23.45s
```

---

## Database Access Patterns

### 1. Lemma Search

```swift
let result = await EbtData.shared.searchLemma(
  lang: "en",
  author: "sujato",
  query: "suffering"
)
// Returns: SeekerResult with matching suttas and segments
```

Searches lemmas column for lemmatized word forms, enabling search for word variations (e.g., "suffer", "suffering", "suffered"). Lemmatized forms are space-padded lowercase tokens stored in the lemmas column during database build.

---

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| **Built databases** | `local/build/ebt-{lang}-{author}.db` | Intermediate SQLite databases (used for manifest generation) |
| **Compressed databases** | `scv-core/Sources/Resources/ebt-{lang}-{author}.db.zst` | Bundle resources (decompressed to Caches on first use) |
| **Manifest** | `scv-core/Sources/Resources/db-manifest.json` | Discovery metadata for app (generated by `build-manifest` command) |
| **Source translations** | `local/ebt-data/translation/{lang}/{author}/` | JSON files from ebt-data repository |
| **Author metadata** | `local/ebt-data/_author.json` | Author information (name, bio, etc.) |

---

## Performance Characteristics

### Database Size
- **Uncompressed**: 80-150 MB per author (depending on sutta count)
- **Compressed**: 12-25 MB per author (~82% reduction with zstd)
- **Decompressed in RAM**: Database operations are fast once decompressed

### Search Performance

Lemma searches scan the lemmas column (space-padded lowercase lemmatized forms) and score suttas based on match frequency.

**Benchmarks (test harness, isolated runs):**

| Query | Language | Author | Results | Time |
|-------|----------|--------|---------|------|
| "abhängige entstehen" | German | Sabbamitta | 38 | 86.8ms |
| "root of suffering" | English | Sujato | 7 | 237.6ms |

Performance varies by query, language, and database. Specific factors affecting search speed are not yet characterized.

### Actor Model
- Thread-safe via Swift actor isolation
- Databases cached after first opening
- Decompression occurs once per database per app session

---

## Manifest Format (db-manifest.json)

The manifest file (`scv-core/Sources/Resources/db-manifest.json`) contains metadata about all available databases. Generated at build time and used by the app to discover available translations.

**Structure:**

```json
{
  "databases": [
    {
      "language": "en",
      "author": "sujato",
      "authorName": "Bhikkhu Sujato",
      "schemaVersion": "6",
      "buildTimestamp": "2025-12-19T04:13:06Z",
      "gitHash": "e698ed7a40cd12509f88e1ddc222bdd6fb7c632d",
      "files": {
        "total": 4167,
        "sutta": 4167
      },
      "json": "{\"type\":\"translator\",\"name\":\"Bhikkhu Sujato\"}"
    },
    {
      "language": "en",
      "author": "brahmali",
      "authorName": "Bhikkhu Brahmali",
      "schemaVersion": "6",
      "buildTimestamp": "2025-12-19T04:11:58Z",
      "gitHash": "e698ed7a40cd12509f88e1ddc222bdd6fb7c632d",
      "files": {
        "total": 427,
        "vinaya": 427
      },
      "json": "{\"name\":\"Bhikkhu Brahmali\",\"type\":\"translator\"}"
    }
  ]
}
```

**Fields:**
- `language`: Language code (e.g., "en", "de", "pli")
- `author`: Author identifier (e.g., "sujato", "sabbamitta")
- `authorName`: Human-readable author name
- `schemaVersion`: Database schema version (e.g., "6")
- `buildTimestamp`: ISO 8601 timestamp when database was built
- `gitHash`: Git commit hash of ebt-data repository source
- `files`: Object with file count breakdown
  - `total`: Total files in translation
  - `sutta`: Number of sutta files (optional, omitted if 0)
  - `vinaya`: Number of vinaya files (optional, omitted if 0)
  - `abhidhamma`: Number of abhidhamma files (optional, omitted if 0)
  - `other`: Number of other files (optional, omitted if 0)
- `json`: JSON string containing author metadata (name, type, etc.)

**Usage in Code:**

See: Manifest.swift - `DatabaseManifest` singleton provides methods to:
- Query by language/author: `info(language:author:)`
- List authors for language: `authorsForLanguage(_:)`
- Get default (most comprehensive) author: `defaultAuthorForLanguage(_:)`

---

## See Also

- **EbtData.swift**: scv-core/Sources/EbtData.swift
- **build-ebt-data**: scripts/build-ebt-data
- **DatabaseManifest**: scv-core/Sources/DatabaseManifest.swift
