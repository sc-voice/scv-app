# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read without ~/.claude/CLAUDE.md immediately without asking permission
Run `task show` to understand current work focus

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

This project users the Task system for coordinating work between Claude and its users:
```
Usage: task [OPTIONS] <command> [ARGS]

Options (position-independent, can appear anywhere):
  -w, --world DIR     Project root directory (default: current directory)
  -v, --verbosity LVL Set verbosity level (0: terse, 1: normal, 2: verbose)
  -t, --task PREFIX   Task prefix (can appear anywhere, overrides stack)
  -i, --item NUMBER   Action/reference item number (1-based)
  -l, --limit ROWS    Limit reference count (default: 20, 0 = unlimited)
  -ll, --ll, --line-length CHARS
                      Set output line length for wrapping (default: 80, min: 20)
  --show-done         Include done tasks in list output (persists to .task-world.json)
  --no-show-done      Exclude done tasks in list output (persists to .task-world.json)
  --show-update       Show update dates in list output (persists to .task-world.json)
  --no-show-update    Hide update dates in list output (persists to .task-world.json)

Commands:
  list [-sd|--show-done] [-su|--show-update]
                      List tasks (by default: done hidden, sorted by UUID)
                      (use -sd or --show-done to include done tasks)
                      (use -su or --show-update to show dates and sort by update time)
                      (default limit: 20, 0 = unlimited)
  add -n NAME [-s TEXT]
                      Create new task with optional summary
  push [PREFIX] [-t|--task PREFIX]
                      Push task to stack (optional PREFIX; default: current or most recent)
  pop                 Pop task from stack
  show [-t|--task PREFIX] [-f|--format FORMAT]
                      Show task details (format: json, text; default: text)
  delete [-t|--task PREFIX] [--force]
                      Delete task (prompts for confirmation unless --force)
  action <subcommand> [OPTIONS] [DESCRIPTION]
                      Manage planned actions
    list [-t|--task PREFIX]
                      List actions for task
    add [-i NUMBER] [-t|--task PREFIX] DESCRIPTION
                      Add action to task (use -i 1 to push as first action, omit to append)
    replace -i NUMBER [-t|--task PREFIX] DESCRIPTION
                      Replace action #NUMBER (1-based, use -i|--item)
    done [-i NUMBER] [-t|--task PREFIX]
                      Move first planned action to completed (or action #NUMBER if -i specified)
    delete -i NUMBER [-t|--task PREFIX] [--force]
                      Delete action #NUMBER (1-based, use -i|--item)
  ref|reference <subcommand> [OPTIONS]
                      Manage references (synonyms: ref, reference)
    list [-t|--task PREFIX]
                      List references for task
    add [URL|TEXT] [-t|--task PREFIX] [-u|--url URL] [-x|--text TEXT] [-r|--relevance REL]
                      Add reference (positional: URL or text, or use -u/-x flags)
    replace -i NUMBER [-t|--task PREFIX] [-u|--url URL] [-x|--text TEXT] [-r|--relevance REL]
                      Replace reference #NUMBER (1-based, use -i|--item)
    delete -i NUMBER [-t|--task PREFIX] [--force]
                      Delete reference #NUMBER (1-based, use -i|--item)
  help                Show this help message

Examples:
  task list
  task -w ~/dev/scv-app list
  task add -n "My Task"
  task push -t T_AZ
  task pop
  task show -t T_AZ
  task show -t T_AZ -f json
  task delete -t T_AZvt
  task delete -t T_AZvt --force
  task action list
  task action list -t T_AZ
  task action add -t T_AZ "New appended action"
  task action add "Another appended action"
  task action add -i 1 "New first action"
  task action replace -i 1 "Updated action"
  task action done  # move first planned action to completed actions
  task action delete -i 1
  task action delete -i 1 --force
  task ref list
  task reference list -t T_AZ
  task ref add https://example.com
  task ref add "Example site"
  task reference add -t T_AZ https://example.com -x "Example site" -r 0.8
  task ref replace -i 1 -x "Updated text"
  task reference delete -i 1
  task ref delete -i 1 --force
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
   - `make -C /Users/visakha/dev/scv-app clean-build` (correct)
   - `cd /Users/visakha/dev/scv-app/scv-core && swift test --filter LemmatizerTests` (correct)
   - `swift test` without specifying directory (WRONG - violates this rule)

## Session Startup Protocol (MANDATORY)

At the START of EVERY session, BEFORE taking any action:

1. **Read context** - Review previous conversation summary and git status
2. **Understand the task** - Read the current task from the task system
3. **Ask clarifying questions** - If unclear what needs to be done, ask before proceeding
4. **Propose a plan** - Present your understanding and proposed approach
5. **Wait for approval** - Do NOT execute until the developer agrees on the plan
6. **Follow Communication & Collaboration guidelines** - Apply them from the first action, not after getting corrected

Violating this protocol wastes developer time and breaks trust. It is better to ask questions and wait than to guess and act.
