# scv-tasks Framework

## Overview

scv-tasks provides a task management system for SC-Voice development through the **ITaskWorld protocol** - a stable API abstraction for programmatic task operations. The framework is built on:

- **File-based persistence** - Tasks stored in `Tasks/` directory as pretty-printed JSON
- **UUIDV7 identifiers** - Chronologically sortable IDs with efficient filename encoding
- **Task stack** - Context switching via stack stored in `.task-world.json`
- **CLI tool** - Command-line interface (optional, see `task help`)

## ITaskWorld Protocol (Primary API)

All task operations flow through the ITaskWorld protocol, enabling stable code contracts, testability, and future persistence changes.

**Location:** `scv-tasks/Sources/scvTasks/ITaskWorld.swift`

**Why this abstraction:**
- Code uses stable protocol, not direct WorldModel/TaskManager dependencies
- Easy testing via mock implementations (see: `scv-tasks/Tests/MockTaskWorld.swift`)
- Atomic, durable mutations - all changes auto-persisted to disk

### Queries

- `taskFrom(anyId: AnyTaskId) -> Task?` - Lookup by filename (T_AZvuCKoac) or UUID string
- `allTaskIds(showFileName: Bool) -> [AnyTaskId]` - All task IDs in world

### Mutations (Atomic & Durable)

- `createTask(name: String, summary: String) async throws -> Task` - Async with automatic retry on filename collision
- `createTaskSync(name: String, summary: String) throws -> Task` - Synchronous variant
- `updateTask(_ task: Task) throws` - Persist task changes
- `deleteTaskId(_ id: AnyTaskId) -> Bool` - Remove task

### Stack Operations (Context Switching)

- `stackTaskIds() -> [AnyTaskId]` - Current stack (UUIDV7 strings)
- `pushTaskId(_ id: AnyTaskId)` - Add to stack
- `popTaskId() -> AnyTaskId?` - Remove from top
- `currentTaskId() -> AnyTaskId?` - Peek at top
- `isStackTaskId(_ id: AnyTaskId) -> Bool` - Check stack membership
- `unstackTaskId(_ id: AnyTaskId)` - Remove from anywhere

### Preferences

- `limit: Int` - Display limit for lists (clamped 0+)
- `verbosity: Int` - Logging level (clamped 0-2)
- `lineLength: Int` - Text wrapping width (minimum 20)

## Implementation Files

### Task.swift - Core Model

**Purpose:** Persistent task data structure + file encoding/decoding.

**Persistent fields:**
- `uuid: UUIDV7` - Chronologically sortable ID (stored as "id" in JSON)
- `name: String`, `summary: String` - Task title and description
- `requiredTasks: [AnyTaskId]` - Dependencies; task blocked if any required task state != .done
- `plannedActions: [Action]`, `completedActions: [Action]` - Ordered step lists
- `references: [Reference]` - Auto-sorted by decreasing relevance
- `createdAt: Date`, `updatedAt: Date` - ISO 8601 timestamps

**Computed fields:**
- `idFile: String` - Filename part (e.g., "T_AZv_4Rvsc") derived from UUID
- `state: TaskState` - Computed: .blocked if dependency unmet, else .active if on stack, else .pending
- `taskWorld: ITaskWorld?` - Non-encoded world reference for state computation

**Helper methods:**
- `moveActionToCompleted(at:)`, `addPlannedAction()` - Action management
- `isBlocked`, `isActive`, `isDone` - State convenience properties

**UUID encoding:**
- `uuidToFilename()` - First 54 bits → 9-char URL-safe base64 (e.g., T_AZvuCKoac)
- URL-safe: `+`→`-`, `/`→`_`, `=` removed; chronologically sortable by timestamp prefix

See: `scv-tasks/Sources/scvTasks/Task.swift`

### TaskState.swift - State Enum

**Purpose:** Simple enum defining task lifecycle.

**Values:**
- `pending` 🐢 - Created, not started
- `blocked` 🔴 - Active but has unmet dependency
- `active` 🟢 - On stack (actively being worked on)
- `done` ☑️ - Completed

See: `scv-tasks/Sources/scvTasks/TaskState.swift`

### Action.swift - Action Model

**Purpose:** Represents a step within a task.

**Fields:**
- `id: UUID` - Unique action identifier
- `description: String` - Step description
- `taskId: String?` - Optional task ID for stack operations

See: `scv-tasks/Sources/scvTasks/Action.swift`

### Reference.swift - Reference Model

**Purpose:** Links to documentation or notes with relevance scoring.

**Fields:**
- `id: String` - Unique reference identifier (UUIDV7-derived base64)
- `text: String?` - Arbitrary note text
- `url: URL?` - Link to external resource
- `relevance: Double` - Score 0-1 for sorting priority

**Behavior:**
- Automatically clamped to 0...1 range
- Auto-generates id if not provided

See: `scv-tasks/Sources/scvTasks/Reference.swift`

### TaskWorld.swift - ITaskWorld Implementation

**Purpose:** Single API entry point implementing ITaskWorld protocol. Manages all task operations with atomic, durable mutations.

**Design:**
- Single-threaded (`@unchecked Sendable` for Swift concurrency)
- In-memory dual-key map: tasks keyed by filename + UUID string for fast lookup
- Loads all tasks on init; auto-persists on every mutation (no explicit save needed)
- Manages world state (stack, preferences) via WorldModel

**Persistence:**
- Tasks: `Tasks/T_*.json` (individual files)
- World state: `.task-world.json` (stack + preferences)

**Init:**
```swift
let world = TaskWorld(basePath: URL)  // defaults to current directory
```

See: `scv-tasks/Sources/scvTasks/TaskWorld.swift`

### WorldModel.swift - Stack & Preferences Manager

**Purpose:** Holds task stack (for context switching) and user preferences; persisted to `.task-world.json`.

**Managed state:**
- `taskStack: [TaskId]` - UUIDV7 values; top is current task
- `limit: Int` - Display limit (clamped 0+)
- `verbosity: Int` - Logging level (clamped 0-2)
- `lineLength: Int` - Wrap width (minimum 20)

**Stack operations:**
- `pushTask()`, `popTask()`, `currentTask()`, `clearStack()`

See: `scv-tasks/Sources/scvTasks/WorldModel.swift`

### TaskManager.swift - Low-level File I/O

**Purpose:** File-level persistence; reads/writes individual task JSON files.

**Responsibilities:**
- Save tasks to `Tasks/T_*.json` with pretty-printing and sorted keys
- Load tasks from filesystem
- ISO 8601 date encoding/decoding

See: `scv-tasks/Sources/scvTasks/TaskManager.swift`

## CLI Tool

The `task` command is optional; for documentation see `task help` after installation.

**Installation:** Symlink `scv-tasks/.build/release/task_cli` to a location in your PATH, then use `task` commands.

For detailed usage: `task help` or `task help <command>`

See: `scv-tasks/Sources/CLI/task_cli.swift`

## File Storage

**Location:** `<PROJECT_ROOT>/Tasks/`

**Format:** `T_<9-char-url-safe-base64>.json` - pretty-printed JSON with sorted keys

Example:
```json
{
  "completedActions" : [ ],
  "createdAt" : "2026-01-24T01:53:50Z",
  "id" : "019BEDB5-2738-7000-8D8A-C7C5CCC3841B",
  "name" : "Task name",
  "plannedActions" : [ ],
  "references" : [ ],
  "requiredTasks" : [ ],
  "summary" : "Description",
  "updatedAt" : "2026-01-24T01:53:50Z"
}
```

**Filename encoding:** First 54 bits of UUIDV7 → 9 base64 chars; chronologically sortable by 48-bit timestamp prefix.

**Time windows by prefix:**
- `T_AZ` (2 chars) = ~2 years
- `T_AZv` (3 chars) = ~4 minutes
- `T_AZvt` (4 chars) = ~4 seconds

## Design Decisions

1. **File-based storage** - Simple, git-friendly, human-readable diffs
2. **UUIDV7 IDs** - Chronologically sortable with natural time-window prefixes
3. **URL-safe base64 filenames** - Path-safe, compact (9 chars = 54 bits)
4. **Pretty-printed JSON** - Git-friendly diffs with sorted keys
5. **Protocol-first API** - Stable ITaskWorld abstraction enables testing and future changes
6. **Dual-key in-memory map** - Fast lookup by filename or UUID
7. **Atomic durable mutations** - No explicit save calls needed

## Future Enhancements

- Task dependency validation
- Markdown export of task details
- Bulk operations (batch create, filter by state)
- Task templates for recurring patterns
- Integration with git commit hooks
