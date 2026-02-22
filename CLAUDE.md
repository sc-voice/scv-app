# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read without ~/.claude/CLAUDE.md immediately without asking permission
Run `task show` to understand current work focus

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

## Permissions

1. Claude can read any file in project except those in local/
  - EXCEPTION: Claude can read any file in project local/ebt-data
  - EXCEPTION: Claude can read any file in project local/bilara-data
  - EXCEPTION: Claude can read any file in project local/build
  - EXCEPTION: Claude can read any file in project local/audio
  - EXCEPTION: Claude can read/write local/*.log
2. Claude can read any file in project except those in secret/

## Code Best Practice

Production swift files should abide by doc/ColorConsole.md

## Protocol Naming Convention

Protocols use the "I" prefix (Microsoft convention) to make intent explicit at first glance.

**Examples:**
- `ISpeechSynthesizer` (not `SpeechSynthesizer`)
- `ICardManager` (not `CardManager`)

This convention applies to all new protocols in the codebase.

## Abbreviations

- `RTC` means Read The Code file that we are working with
- `RTD` means Read The Markdown file that we are working with

## Directory Context (CRITICAL)

Claude must be explicit and intentional about working directory for EVERY command:

1. BEFORE running any command, explicitly determine which directory it must run in
2. Use absolute paths or `-C` flag to run commands from correct directory
3. NEVER assume current working directory is correct
4. Especially critical for: make, git, swift build, swift test, and scripts
5. Examples:
   - `make -C /Users/visakha/dev/scv-app clean-build` (correct)
   - `cd /Users/visakha/dev/scv-app/scv-core && swift test --filter LemmatizerTests` (correct)
   - `swift test` without specifying directory (WRONG - violates this rule)

## Testing

To test build tools:
```bash
make test-tools
```

To test application:
```bash
make test-app
```

**Important:** Tests must run **serially** (not in parallel) because scv-core uses a global mutable localization bundle for testing. The `withLocalizationBundle()` helper in CardTests.swift swaps bundles to test multiple languages, which causes conflicts if tests run in parallel.

To run a specific test:
```bash
cd scv-core && swift test --filter CardTests
```
