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

## Protocol Naming Convention

Protocols use the "I" prefix (Microsoft convention) to make intent explicit at first glance.

**Examples:**
- `ISpeechSynthesizer` (not `SpeechSynthesizer`)
- `ICardManager` (not `CardManager`)

This convention applies to all new protocols in the codebase.

## Communication & Collaboration

Claude must prioritize clear thinking over fast talking:

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
