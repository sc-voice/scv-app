# EBT Database Schema

SC-Voice uses per-author SQLite databases to store Buddhist scripture translations. This document describes the database structure, build process, and query patterns.

## Overview

- **Purpose**: Efficient full-text search and segment retrieval for Buddhist suttas (scriptures)
- **Architecture**: One database per language/author combination (e.g., `ebt-en-sujato.db`)
- **Storage**: Compressed with zstd in app bundle; decompressed to app Caches on first use
- **Access Layer**: `EbtData` actor (thread-safe via Swift actor isolation)

## Database Schema

### 1. metadata table
Stores information about the translation and build process.

```sql
CREATE TABLE metadata (
  language TEXT,
  author TEXT,
  author_name TEXT,
  git_hash TEXT,
  build_timestamp TEXT,
  files INTEGER,
  json TEXT,
  PRIMARY KEY (language, author)
);
```

**Columns:**
- `language`: Language code (e.g., "en", "de", "fr")
- `author`: Author identifier (e.g., "sujato", "sabbamitta")
- `author_name`: Human-readable author name
- `git_hash`: Git commit hash of ebt-data repository (nullable)
- `build_timestamp`: ISO 8601 timestamp when database was built
- `files`: Count of source translation files included in this database
- `json`: Optional JSON metadata about the author (nullable)

**Example:**
```
language  | author  | author_name | git_hash | build_timestamp | files | json
----------|---------|-------------|----------|-----------------|-------|------
en        | sujato  | Bhikkhu S.  | abc123   | 2024-11-20...   | 150   | {...}
```

---

### 2. suttas table
Index of all suttas (scripture documents) in the database.

```sql
CREATE TABLE suttas (
  sutta_key TEXT PRIMARY KEY,
  total_segments INTEGER
);
```

**Columns:**
- `sutta_key`: Unique identifier in format `language/author/scid`
  - Example: `en/sujato/mn1` (Majjhima Nikaya discourse 1)
- `total_segments`: Number of segments in this sutta

**Example:**
```
sutta_key          | total_segments
-------------------|----------------
en/sujato/mn1      | 47
en/sujato/an1.1    | 3
en/sujato/dn1      | 152
```

---

### 3. segments table
Individual text segments of suttas, enabling paragraph-level search and retrieval.

```sql
CREATE TABLE segments (
  sutta_key TEXT,
  segment_id TEXT,
  segment_text TEXT
);
```

**Columns:**
- `sutta_key`: Reference to sutta (e.g., `en/sujato/mn1`)
- `segment_id`: Unique segment identifier within sutta (e.g., `mn1:1.0`, `mn1:1.1`)
  - Format: `scid:section.subsegment`
  - `:0.0` and `:0.1` are headers; `:1.1`, `:1.2`, etc. are content
- `segment_text`: The actual text content of the segment

**Example:**
```
sutta_key      | segment_id   | segment_text
----------------|--------------|-------------------------------------------
en/sujato/an1.2 | an1.2:1.0    | 2
en/sujato/an1.2 | an1.2:1.1    | Mendicants, I do not see a single...
en/sujato/an1.2 | an1.2:1.2    | The sound of a woman occupies...
```

---

### 4. segments_fts table
Virtual FTS5 (Full-Text Search) index for fast keyword queries.

```sql
CREATE VIRTUAL TABLE segments_fts USING fts5(
  sutta_key UNINDEXED,
  segment_id UNINDEXED,
  segment_text
);
```

**Purpose**: Enables fast keyword search via `MATCH` operator
- `sutta_key` and `segment_id` marked `UNINDEXED` (not searchable but available in results)
- `segment_text` is indexed for full-text search

**Auto-population**: `segments_ai` trigger automatically inserts rows when segments are added

---

### 5. segments_ai trigger
Maintains FTS index when segments are inserted.

```sql
CREATE TRIGGER segments_ai AFTER INSERT ON segments BEGIN
  INSERT INTO segments_fts(sutta_key, segment_id, segment_text)
  VALUES (new.sutta_key, new.segment_id, new.segment_text);
END;
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
2. **Create schema**: Create metadata, suttas, segments tables and FTS index
3. **Insert metadata**: Store translation metadata from `_author.json`
4. **Process JSON files**: For each translation file:
   - Extract SCID from filename (e.g., `mn1` from `mn1_translation-en-sujato.json`)
   - Parse JSON to extract segments
   - Insert sutta into `suttas` table with segment count
   - Insert each segment into `segments` table (FTS automatically updated)
5. **Compress**: Compress database with zstd to reduce bundle size (~60-70% reduction)
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

### 1. Retrieve Sutta by Key

```swift
let translation = EbtData.shared.getTranslation(lang: "en", author: "sujato", suttaId: "an1.2")
// Returns JSON: {"an1.2:1.0": "2", "an1.2:1.1": "Mendicants...", "an1.2:1.2": "The sound..."}
```

### 2. Keyword Search (FTS)

```swift
let results = EbtData.shared.searchKeywords(lang: "en", author: "sujato", query: "suffering")
// Returns: ["en/sujato/dn1", "en/sujato/mn1", ...]  (sorted by relevance)
```

**SQL Query Used:**
```sql
SELECT s.sutta_key, COUNT(sf.rowid) as match_count, s.total_segments,
       CAST(COUNT(sf.rowid) AS FLOAT) / s.total_segments as relevance_pct,
       COUNT(sf.rowid) + (CAST(COUNT(sf.rowid) AS FLOAT) / s.total_segments) as combined_score
FROM segments_fts sf
JOIN suttas s ON sf.sutta_key = s.sutta_key
WHERE sf.segment_text MATCH ?
GROUP BY sf.sutta_key
ORDER BY combined_score DESC
LIMIT ?
```

**Scoring:** `combined_score = match_count + (match_count / total_segments)`

### 3. Phrase Search

```swift
let results = EbtData.shared.searchPhrase(lang: "en", author: "sujato", phrase: "noble eightfold path")
// Returns: Keyword search results filtered to exact phrase matches
```

### 4. Regex Search

```swift
let results = EbtData.shared.searchRegexp(lang: "en", author: "sujato", pattern: "suffer.*mind")
// Returns: Sutta keys matching regex pattern
```

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
- **Keyword search**: <500ms for typical queries (FTS5 indexed)
- **Phrase search**: ~1-2s (keyword search + content filtering)
- **Regex search**: 1-5s (regex evaluated on all segments)

### Actor Model
- Thread-safe via Swift actor isolation
- Databases cached after first opening
- Decompression occurs once per database per app session

---

## Manifest Format (db-manifest.json)

The manifest file (`scv-core/Sources/Resources/db-manifest.json`) contains metadata about all available databases:

```json
{
  "databases": [
    {
      "language": "en",
      "author": "sujato",
      "authorName": "Bhikkhu Sujato",
      "buildTimestamp": "2024-11-20T10:30:00Z",
      "files": 150,
      "gitHash": "abc123def456..."
    },
    {
      "language": "en",
      "author": "brahmali",
      "authorName": "Bhikkhu Brahmali",
      "buildTimestamp": "2024-11-20T10:32:00Z",
      "files": 140
    },
    ...
  ]
}
```

Generated by:
```bash
./scripts/build-ebt-data build-manifest
```

---

## See Also

- **EbtData.swift**: scv-core/Sources/EbtData.swift
- **build-ebt-data**: scripts/build-ebt-data
- **DatabaseManifest**: scv-core/Sources/DatabaseManifest.swift
