# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

IMPORTANT! READ IMMEDIATELY WITHOUT ASKING PERMISSION: 
  - global CLAUDE.md
  - WORK.md

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

### ColorConsole Logging

ColorConsole (See: scv-core/Sources/ColorConsole.swift) handles output filtering internally via verbosity levels. Do NOT use conditional checks.

**Initialization:**
- Pass verbosity level at init: `let cc = ColorConsole(#file, #function, dbg.Module.level)`
- Use `dbg` constants from codebase (e.g., `dbg.SuttaPlayer.other`)
- Each module/class can have its own verbosity level

**Usage patterns:**
- `ok1()`: End of happy path, just before leaving method. Output if verbosity >= 1
- `bad1()`: End of sad path (error/exception), just before leaving method. Output if verbosity >= 1
- `ok2()`: Anywhere else on happy path (entry, intermediate steps, branches). Output if verbosity >= 2
- `bad2()`: Anywhere else on sad path (non-fatal errors, error diagnostics). Output if verbosity >= 2

**Pattern to AVOID:**
```swift
if dbgSearch > 1 {
  cc.ok2(#line, "message")  // Wrong - redundant conditional
}
```

**Pattern to USE:**
```swift
cc.ok2(#line, "message")  // Correct - ColorConsole checks verbosity internally
```

ColorConsole returns nil if output is filtered, allowing `@discardableResult` to silence unused value warnings.

### Protocol Naming Convention

Protocols use the "I" prefix (Microsoft convention) to make intent explicit at first glance.

**Examples:**
- `ISpeechSynthesizer` (not `SpeechSynthesizer`)
- `ICardManager` (not `CardManager`)

This convention applies to all new protocols in the codebase.

## Claude commands

Always read user Claude.md at beginning of chat or whenever existing chat is cleared.

- rtf means READ THE FILE

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

## Backlog

See `doc/Backlog.md` for project backlog items.
