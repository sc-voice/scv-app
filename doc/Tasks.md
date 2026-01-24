# scv-tasks Framework

## Overview

scv-tasks is a task management system for SC-Voice development. It provides:

1. **Task model** - Core data structure with state, actions, and references
2. **Persistence** - File-based storage in `Tasks/` directory with pretty-printed JSON
3. **CLI tool** - Command-line interface for task operations
4. **Context switching** - WorldModel singleton for task stack management

## Architecture

### Task Model

Located in `scv-tasks/Sources/scvTasks/`

**Core fields:**
- `id`: UUIDV7 - Chronologically sortable identifier
- `name`: String - Task title
- `summary`: String - Brief description
- `state`: TaskState - blocked, active, or done
- `plannedActions`: [Action] - Ordered list of steps to execute
- `completedActions`: [Action] - Finished steps
- `references`: [Reference] - Links to documentation or notes
- `requiredTasks`: [UUIDV7] - Task dependencies (task is blocked if any required task isn't done)

**Action:**
- `description`: String - Step description
- `taskId`: String? - Optional task ID for push/pop stack tracking

**Reference:**
- `filePath(String)` - Project-relative path to .md file
- `text(String)` - Arbitrary note text

### File Storage

**Location:** `<PROJECT_ROOT>/Tasks/`

**Filename format:** `T_<9-char-url-safe-base64>.json`

- First 54 bits of UUIDV7 encode to 9 base64 characters
- URL-safe encoding: `+` → `-`, `/` → `_`, `=` removed
- Chronological ordering: first 48 bits = millisecond timestamp
- Example: `T_AZvttSc4c.json`

**Time windows by prefix length:**
- `T_AZ` (2 chars) = ~2 years
- `T_AZv` (3 chars) = ~4 minutes
- `T_AZvt` (4 chars) = ~4 seconds

### Persistence Format

Tasks are persisted as pretty-printed JSON with sorted keys (2-space indent):

```json
{
  "completedActions" : [ ],
  "createdAt" : "2026-01-24T01:53:50Z",
  "id" : "019BEDB5-2738-7000-8D8A-C7C5CCC3841B",
  "name" : "Task name",
  "plannedActions" : [ ],
  "references" : [ ],
  "requiredTasks" : [ ],
  "state" : "active",
  "summary" : "Description",
  "updatedAt" : "2026-01-24T01:53:50Z"
}
```

### WorldModel

Singleton stored in `world.json` at project root.

**Purpose:** Tracks task stack for context switching

**Fields:**
- `taskStack`: [TaskId] - Stack of active task IDs

**Methods:**
- `pushTask(_ id)` - Add to stack
- `popTask()` - Remove from stack
- `currentTask()` - Peek at top
- `clearStack()` - Empty stack

## CLI Tool

### Commands

**list** - Show all tasks with status emoji (sorted by descending ID - newest first)
```bash
task list
task -w ~/dev/scv-app list
```

Output format: `<filename> <emoji> <name>`
- 🚫 blocked
- 🟢 active
- ☑️ done

Tasks are sorted in descending order by UUIDV7 ID, showing newest tasks first.

**new** - Create new task
```bash
task new -n "Task Name" -s "Optional summary"
task new --name "Task Name" --summary "Summary"
```

**show** - Display task details
```bash
task show -t T_AZv        # Case-sensitive
task show -t azvt         # Case-insensitive fallback
task show -t AZv          # Shows ambiguous matches
task show -t T_AZv -f json
task show -t T_AZv --format text
```

Formats: `text` (default), `json`

**delete** - Remove task with confirmation
```bash
task delete -t T_AZv      # Interactive prompt
task delete -t AZv --force # Skip confirmation
```

### Global Options

**-w, --world DIR** - Project root directory (default: `projectRoot()` from scvCore)

All commands inherit this option:
```bash
task -w ~/custom-project list
task --world ~/custom-project show -t T_AZv
```

### Prefix Matching

- Auto-prepends `T_` if not present: `-t AZv` → `-t T_AZv`
- Case-sensitive first, case-insensitive fallback
- Shows multiple matches if ambiguous

## Backlog Integration

All SC-Voice backlog items from `doc/Backlog.md` are registered as tasks:

**Current Release (3 tasks):**
- T_AZvttSc4c: AudioStore Phase 4 — CachedSynthesizer Implementation
- T_AZvt220Rc: AudioStore Phase 5 — M4A Optimization
- T_AZvt220Xc: Create Background Audio Feature

**Next Release - Accessibility (3 tasks):**
- T_AZvt220dc: Test VoiceOver accessibility labels
- T_AZvt220ic: Fix accessibility layout adaptation
- T_AZvt220nc: Add keyboard accessibility

**Next Release - Search & Infrastructure (3 tasks):**
- T_AZvt220uc: Mark matched segments in MLDocument with lemmaRegexp
- T_AZvt26U1c: Investigate phrase search vs keyword search score differences
- T_AZvt26U7c: Make EbtData SQL query methods async

**Future Release (2 tasks):**
- T_AZvt26VBc: Redesign Lemmatizer cache for performance
- T_AZvt26VGc: Optimize Sutta rendering pipeline
- T_AZvt26VLc: Add offline support for searched suttas

## Editing Tasks

For complex edits (adding actions, references, state changes):

1. Edit task JSON directly: `Tasks/T_*.json`
2. Pretty-print format with sorted keys for git tracking
3. Reload with CLI when needed

## Integration Points

- **scvCore**: Uses `projectRoot()` for default world directory
- **swift-uuidv7**: Provides UUIDV7 type for chronological task IDs
- **scv-app**: Tasks stored in project root, not in scv-tasks package

## Design Decisions

1. **File-based storage** - Simple, git-friendly, no database
2. **UUIDV7 IDs** - Chronologically sortable, natural time-window prefixes
3. **URL-safe base64 filenames** - Path-safe, compact (9 chars = 54 bits)
4. **Pretty-printed JSON** - Human-readable diffs, git-friendly
5. **Prefix-based lookup** - Efficient ambiguity detection without parsing
6. **Singleton WorldModel** - Single source of truth for context switching
7. **CLI-first management** - Programmatic additions, manual editing for complexity

## Future Enhancements

- Task dependencies (requiredTasks validation)
- Markdown export of task details
- Bulk operations (batch create, filter by state)
- Task templates for recurring patterns
- Integration with git commit hooks
