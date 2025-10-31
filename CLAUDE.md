# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also ~/.claude/CLAUDE.md

## Communication Style

- Be direct and terse
- Use neutral affect
- Use hypotheses and avoid assertions
- Assertions can be used with source code line references
- Assertions can be used with url references

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

## Permissions

- you can read any file in project except those in secret/

## Testing

### scv-core Package Tests

Run tests with:
```bash
make test-core
```

**Important:** Tests must run **serially** (not in parallel) because scv-core uses a global mutable localization bundle for testing. The `withLocalizationBundle()` helper in CardTests.swift swaps bundles to test multiple languages, which causes conflicts if tests run in parallel.

For verbose output:
```bash
make test-core-verbose
```

To run a specific test:
```bash
cd scv-core && swift test --filter CardTests
```

## Backlog

### Card Testing
01. [x] Verify Card has UUID - Check if @Model auto-generates ID or if explicit UUID needed
02. [x] Add Codable to Card - Enable JSON serialization/deserialization of Card
03. [x] Card/SearchResponse relationship - Verify SearchResponse is properly modeled for SwiftData persistence
04. [x] Card identity preservation - Test that Card ID and createdAt survive save/load cycles
05. [ ] SearchResults persistence - Test that SearchResponse data in searchResults field survives SwiftData round-trip

### CardManager Testing
06. [ ] CardManager selection logic - Test that selectedCard remains valid after deletions
07. [ ] CardManager deletion tests - Test edge cases (delete last card, delete middle card, concurrent deletes)
08. [ ] CardManager concurrent operations - Test rapid add/remove operations

### Card Validation
09. [ ] Card validation - Test constraints (e.g., typeId uniqueness per cardType)
10. [ ] Localization edge cases - Test localization with invalid bundle or missing keys

