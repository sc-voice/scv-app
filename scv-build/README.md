# scv-build

Swift package that builds per-author SQLite databases for SC-Voice from translated EBT data sources.

## Purpose

Converts EBT translation data into optimized SQLite databases with:
- Full-text search (FTS5) tables for efficient searching
- Metadata tracking (language, author, git hash, build timestamp, schema version)
- Compressed distribution via zstandard (.zst)

## Requirements

- Swift 6.0+
- `zstd` command-line tool (for compression)
- Access to `local/ebt-data/` directory with translation files
- `scv-core` package (for `DatabaseInfo`, `EbtData.schemaVersion`, etc.)

## Usage

### Build single author database

```bash
swift run scv-build en:sujato
```

Output:
- Uncompressed: `local/build/ebt-en-sujato.db`
- Compressed: `scv-core/Sources/Resources/ebt-en-sujato.db.zst`

### Build multiple databases

```bash
swift run scv-build en:sujato de:sabbamitta en:brahmali
```

### Rebuild all databases from manifest

```bash
swift run scv-build --rebuild-from-manifest
```

Reads `db-manifest.json`, rebuilds all listed lang:author pairs.

### Manage manifest

```bash
# List all databases in manifest
swift run scv-build --list-manifest

# View metadata for specific database
swift run scv-build --list-metadata en:sujato

# Regenerate manifest from built databases
swift run scv-build --build-manifest
```

## Database Schema

### metadata table
- `language`: Language code (e.g., "en", "de", "pli")
- `author`: Author/translator (e.g., "sujato", "sabbamitta")
- `author_name`: Display name of author
- `git_hash`: Commit hash from ebt-data repo when built
- `build_timestamp`: ISO8601 timestamp when database was created
- `files`: Number of translation files processed
- `json`: Optional JSON metadata about author
- `schema_version`: Database schema compatibility version

### segments table
- `sutta_key`: Unique identifier (format: `suttaUid/lang/author`)
- `segment_id`: Segment number within sutta (e.g., "1.1", "2.3")
- `segment_text`: The translated text

### suttas table
- `sutta_key`: Unique identifier
- `total_segments`: Number of segments in this sutta

### segments_fts (FTS5 virtual table)
- Full-text search index on `segment_text`
- Used by EbtData for keyword/phrase searches

## Schema Versioning

When code in `EbtData` changes how it interprets database data, increment `EbtData.schemaVersion` in `scv-core/Sources/EbtData.swift`.

- Current version: `EbtData.schemaVersion = 3`
- EbtDBBuilder automatically writes matching version to `metadata.schema_version`
- Cached databases with mismatched schema are automatically invalidated and rebuilt

## Building for Distribution

Compressed databases (.zst) are generated and stored in:

```
scv-core/Sources/Resources/ebt-*.db.zst
```

### Workflow

1. **Local rebuild**: Run `swift run scv-build en:sujato`
   - Generates `.zst` file in `scv-core/Sources/Resources/`
   - File exists on disk and is included when you build the app

2. **Git**: `.zst` files are in `.gitignore`
   - NOT tracked by git (no binary bloat in repo)
   - Code changes (schema version, build logic) ARE committed

3. **App bundle**: When building app, Xcode includes all `.zst` files from Resources/
   - Users get them bundled with the app
   - Users decompress on first access (see `EbtData.ensureDecompressed()`)

4. **CI/CD** (future): Automated builds can regenerate `.zst` without committing them

## Troubleshooting

### "zstd not found"
Install zstandard:
```bash
brew install zstandard
```

### Database build fails
Check that translation files exist:
```bash
ls local/ebt-data/translation/en/sujato/sutta/
```

### Schema mismatch after code changes
The app automatically detects old cached databases and rebuilds them. To force rebuild locally:
```bash
rm scv-core/Sources/Resources/ebt-*.db.zst
swift run scv-build en:sujato  # rebuild specific database
```

## Implementation Details

See `Sources/scvBuild/Builders/EbtDBBuilder.swift` for:
- Database schema creation
- Translation file import
- FTS table population
- Compression workflow
