# Serialization and Fixtures

## Overview

This document describes the serialization versioning strategy and fixture management for backward compatibility testing.

## SerializationVersion

The `serializationVersion` constant in `Version.swift` tracks the current serialization format for Settings and Card objects. When the serialization format changes incompatibly, increment `serializationVersion`.

## Fixture Management Pattern

### Dual-Mode Tests

V1 serialization tests use a dual-mode approach controlled by the `GENERATE_V1_FIXTURES` flag:

#### Mode 1: Generate Fixtures (`GENERATE_V1_FIXTURES = true`)

When true, tests:
1. Create Settings/Card objects with test data
2. Encode them to JSON
3. **Save the JSON to fixture files** in `scv-core/Tests/Fixtures/`

**When to use:**
- When serialization format changes
- To create initial fixtures for a new serialization version
- To update fixtures after intentional format changes

#### Mode 2: Verify Fixtures (`GENERATE_V1_FIXTURES = false`)

When false, tests:
1. Create Settings/Card objects with test data (unused except to document expected structure)
2. **Load corresponding fixture files** from disk
3. Deserialize and verify all fields match expectations

**When to use:**
- Normal development and CI/CD
- To verify backward compatibility
- To ensure fixtures deserialize correctly

### Test Structure

Each test follows this pattern:

```swift
@Test func serializeDocLangSettingsMinimal() throws {
  /// Create test object
  let settings = Settings()
  // ... configure settings ...

  /// Encode/load fixture (respects GENERATE_V1_FIXTURES flag)
  let encoded = try Self.getFixtureJSON(settings, testName: "Settings_DocLangSettingsMinimal")

  /// Decode
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(Settings.self, from: encoded)

  /// Verify
  #expect(decoded.version == 1)
  #expect(decoded.docLang == .english)
  // ... more assertions ...
}
```

The `getFixtureJSON` helper determines whether to generate or load based on the flag.

## Fixture Files

Fixtures are stored in `scv-core/Tests/Fixtures/` with format:

```
V1_Settings_AllAtomicFields.json
V1_Settings_DocLangSettingsMinimal.json
V1_Settings_DocLangSettingsWithVoice.json
V1_Settings_DocLangSettingsMultipleLanguages.json
V1_Card_Sutta.json
V1_Card_Search.json
V1_Card_SearchWithMlDocs.json
V1_Card_SearchNil.json
V1_Card_SearchEmpty.json
```

Naming convention: `V{serializationVersion}_{ObjectType}_{Scenario}.json`

## Workflow

### Initial Setup (Serialization Version 1)

1. Create `V1SerializationTests.swift` with test cases
2. Set `GENERATE_V1_FIXTURES = true`
3. Run tests to generate fixture files
4. Set `GENERATE_V1_FIXTURES = false`
5. Commit both tests and fixtures to git

### During Development

- Keep `GENERATE_V1_FIXTURES = false`
- Tests load and verify fixtures
- Fixtures act as backward compatibility baseline

### When Format Changes (Serialization Version 2)

1. Increment `serializationVersion` in `Version.swift`
2. Create `V2SerializationTests.swift` (copy from V1, update as needed)
3. Set `GENERATE_V1_FIXTURES = true` in new test file
4. Run tests to generate new fixtures
5. Set `GENERATE_V1_FIXTURES = false`
6. Commit new tests and fixtures

### Before App Store Submission

**Important:** Do NOT change fixtures after app submission. Users may have serialized data in the old format.

- V1 fixtures are locked (in production)
- Only create new V2+ fixtures for new serialization versions
- Ensure migration logic handles all previous versions

## Implementation Details

### Settings Serialization Tests

See: `scv-core/Tests/V1SerializationTests.swift`

Tests serialization of:
- All atomic fields (version, docLang, refLang, etc.)
- docLangSettings dictionary structure (single language)
- docLangSettings with full voice configuration
- docLangSettings with multiple languages

### Card Serialization Tests

See: `scv-core/Tests/V1CardSerializationTests.swift`

Tests serialization of:
- Sutta card (nil searchResults)
- Search card with basic SearchResponse
- Search card with mlDocs (complex nested structure)
- Search card with nil searchResults (before search)
- Search card with empty SearchResponse (no results found)

## Notes

- Tests use hardcoded UUIDs from fixtures (generated values)
- All other fields compared against original test objects
- Fixtures are JSON and human-readable for debugging
- Each test is independent (no shared state)
