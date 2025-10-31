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

### Card Validation (completed)
04. [x] Localization edge cases - Test localization with invalid bundle or missing keys
03. [x] Card validation - Test constraints (e.g., typeId uniqueness per cardType)

### CardManager Testing (completed)
01. [x] CardManager deletion tests - Test edge cases (delete last card, delete middle card, concurrent deletes)
02. [x] CardManager concurrent operations - Test rapid add/remove operations

