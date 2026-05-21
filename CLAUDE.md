# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read without ~/.claude/CLAUDE.md immediately without asking permission

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

The build system uses make:
```
SC-Voice Build Targets

  make rebuild           Update version, clean, build and test and all packages
  make test              Run all package tests (shortcut for test-app)
  make test-app          Run all application tests
  make test-core         Run scv-core tests serially (excludes integration tests)
  make test-core-verbose Run scv-core tests serially with verbose output
  make test-tools        Run scv-build tests serially
  make test-tasks        Run scv-tasks tests serially
  make test-ui           Run scv-ui tests serially
  make test-zstd-integration Run zstd integration tests (database decompression)
  make test-research     Run research tests (platform API exploration)
  make test-content      Verify all manifest databases are present in build
  make build             Build all (core and iOS) with new version
  make build-core        Build scv-core package
  make build-ui	        Build scv-ui package
  make build-tools 			Build scv-build package (build tools)
  make build-tasks       Build scv-tasks package (task CLI)
  make build-ios         Build scv-ios app with new version
  make build-db DB=lang:author    Build single database (e.g. make build-db DB=en:sujato)
  make suid-list         Regenerate suid-list.json from ebt-pli-ms.db
  make content						Pull latest ebt-data and rebuild all databases from manifest
  make clean             Clean all build artifacts and apply SwiftFormat
  make clean-core        Clean scv-core package
  make clean-content 		Clean database content
  make clean-ui          Clean scv-ui package
  make clean-ios         Clean scv-ios app build artifacts
  make clean-db DB=lang:author    Clean database caches (e.g. make clean-db DB=en:sujato)
  make clean-cache       Clean all app caches from ~/Library/Caches
  make clean-lemmatizer  Clean all lemmatizer cache files
  make format            Apply SwiftFormat to project
  make mock-response-view Build and launch mock-response-view app
  make version-major     Increment major version (X.0.0)
  make version-minor     Increment minor version (X.Y.0)
  make version-patch     Increment patch version (X.Y.Z)
  make commit            Review and approve commit from .commit-msg file
```

## Permissions

1. Claude can read any file in project except those in local/
  - EXCEPTION: Claude can read any file in project local/ebt-data
  - EXCEPTION: Claude can read any file in project local/bilara-data
  - EXCEPTION: Claude can read any file in project local/build
  - EXCEPTION: Claude can read any file in project local/audio
  - EXCEPTION: Claude can read/write local/*.log
2. Claude can read any file in project except those in secret/

## Protocol Naming Convention

Protocols use the "I" prefix (Microsoft convention) to make intent explicit at first glance.

**Examples:**
- `ISpeechSynthesizer` (not `SpeechSynthesizer`)
- `ICardManager` (not `CardManager`)

This convention applies to all new protocols in the codebase.

## Teamwork

Claude works WITH the developer, not FOR them - when something breaks, we both own it and fix it together.

Claude must prioritize clear thinking over fast talking or fast action:

1. **Stop speculating immediately** - When you don't know something, say so. Don't theorize or guess
2. **Ask questions instead of assuming** - If unclear what the user wants, ask before proceeding
3. **Test before theorizing** - Create tests to expose actual behavior; let results guide investigation, not hunches
4. **When tests pass unexpectedly, stop** - Don't rationalize away unexpected results. Ask for clarification
5. **Waste of time is worse than silence** - Lengthy incorrect analysis wastes both parties' time and breaks trust

This applies especially when the user corrects you. Acknowledge the correction, understand it clearly, and move forward without defensive explanation.

## Directory Context (CRITICAL)

Claude must be explicit and intentional about working directory for EVERY command:

1. BEFORE running any command, explicitly determine which directory it must run in
2. Use absolute paths or `-C` flag to run commands from correct directory
3. NEVER assume current working directory is correct
4. Especially critical for: make, git, swift build, swift test, and scripts
5. Examples:
   - `make -C /Users/visakha/dev/scv-next clean-build` (correct)
   - `cd /Users/visakha/dev/scv-next/scv-core && swift test --filter LemmatizerTests` (correct)
   - `swift test` without specifying directory (WRONG - violates this rule)

