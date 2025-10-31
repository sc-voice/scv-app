# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Workflow

Work is organized into "work sessions" that end with a git commit.

Each work session must start with:

1. answering developer questions
2. defining a single Objective
3. defining a Plan to meet that objective 
4. defining a Test to verify that objective has been met

With all above in place, work can begin and the plan can be followed step-by-step.

Once the entire Test passes, developer approval is required for git commit

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

