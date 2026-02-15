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
- `resolveTask(id: AnyTaskId?) throws -> Task` - Resolve a task by query or current task (see below)

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

### Task Resolution

- `resolveTask(id: AnyTaskId?) throws -> Task` - Resolve task by id or current task from stack
  - If `id == nil`: Returns current task; throws if stack empty
  - If `id != nil`: Delegates to `resolveTaskLevenstein(_ query: AnyTaskId)`
  - Throws `TaskResolutionError.notFound` or `.ambiguous` on failure

**Examples:**
```swift
let world = TaskWorld()

// Resolve current task from stack
let current = try world.resolveTask(id: nil)

// Resolve by exact filename
let task1 = try world.resolveTask(id: "T_AZvuCKoac")

// Resolve by prefix
let task2 = try world.resolveTask(id: "T_AZv")

// Resolve by typo (Levenshtein fuzzy match)
let task3 = try world.resolveTask(id: "AZvt220r")  // → T_AZvt220Rc

// Resolve by UUID string
let task4 = try world.resolveTask(id: "019C61C1-713B-7000-8056-D32844EE5B9F")
```

### Task Resolution Examples

`resolveTask()` supports multiple query formats with fuzzy matching as fallback:

```swift
let world = TaskWorld()

// Query by full filename
try world.resolveTask(id: "T_AZvuCKoac")       // → exact match

// Query by prefix (case-insensitive) - needs at least ~8 chars to stay within distance threshold
try world.resolveTask(id: "T_AZvuCKo")        // → matches T_AZvuCKoac if unique
try world.resolveTask(id: "vuckoac")          // → auto-adds T_ prefix, matches T_AZvuCKoac if unique

// Query by typo or partial string (Levenshtein fuzzy match)
try world.resolveTask(id: "AZvt220r")          // → closest match by edit distance
try world.resolveTask(id: "T_AZvucKoac")       // → case error, recovers via case-insensitive tiebreaker

// Query by full UUID string
try world.resolveTask(id: "019C61C1-713B-7000-8056-D32844EE5B9F")  // → exact UUID match

// Query by nil (current task from stack)
try world.resolveTask(id: nil)                 // → top of stack, throws if empty
```

**Error cases:**
- `.notFound` - No task found within fuzzy match distance threshold
- `.ambiguous` - Multiple tasks equally close (requires longer prefix to disambiguate)

See: `scv-tasks/Sources/scvTasks/TaskWorld.swift` (resolveTask, resolveTaskLevenstein)

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

**Instance methods:**
- `moveActionToCompleted(at:)` - Move action from planned to completed
- `addPlannedAction(_ action:)` - Add new planned action
- `isBlocked`, `isActive`, `isDone` - State convenience properties

**Static UUID encoding methods:**
- `uuidToFilename(_ uuid:) -> String` - First 54 bits → `T_` prefix + 9-char URL-safe base64 (e.g., `T_AZvuCKoac`)
- `uuidToBase64(_ uuid:) -> String` - Full 128-bit UUID → 24-char URL-safe base64 string
- `shortId(_ uuid:) -> String` - First 54 bits → 8-char identifier (truncated base64, chars 3-10)
- URL-safe encoding: `+`→`-`, `/`→`_`, `=` removed; chronologically sortable by 48-bit timestamp prefix

**State computation:**
- `state` property evaluates dependencies via `taskWorld` to determine if task is `.blocked`, `.active`, `.done`, or `.pending`
- `.done` when all requiredTasks are done AND task has completedActions AND no plannedActions

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
- `id: String?` - Unique action identifier (auto-generated via `Task.shortId()`)
- `name: String?` - Optional action name
- `description: String` - Step description
- `complexity: String?` - Optional complexity indicator (e.g., "simple", "complex")
- `duration: TimeInterval?` - Optional estimated duration in seconds
- `test: String?` - Optional test description or command to verify completion

See: `scv-tasks/Sources/scvTasks/Action.swift`

### Reference.swift - Reference Model

**Purpose:** Links to documentation or notes with relevance scoring.

**Fields:**
- `id: String` - Unique reference identifier; auto-generated via `Task.uuidToBase64(UUIDV7())` if not provided
- `text: String?` - Arbitrary note text
- `url: URL?` - Link to external resource
- `relevance: Double` - Score 0-1 for sorting priority (auto-clamped to 0...1 range)

**Behavior:**
- References are auto-sorted by decreasing relevance, then by id
- Relevance automatically clamped to 0...1 range
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

**Properties:**
- `limit`, `verbosity`, `lineLength` - Proxy to WorldModel preferences
- `showDone`, `showUpdate` - Additional WorldModel toggles for display control

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
- `showDone: Bool` - Whether to display completed tasks
- `showUpdate: Bool` - Whether to show update timestamps

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

## Public Module API

### scvTasks.swift - Module Exports

**Purpose:** Defines public type aliases and exports for the scv-tasks module.

**Exports:**
- `typealias TaskId = UUIDV7` - Core task identifier type
- `typealias AnyTaskId = String` - Accept both filenames (T_AZvuCKoac) or UUID strings

See: `scv-tasks/Sources/scvTasks/scvTasks.swift`

## Usage Examples

### Creating a Task

```swift
let world = TaskWorld(basePath: projectRoot)
let task = try await world.createTask(
  name: "Implement feature X",
  summary: "Add new functionality to module Y"
)
```

### Managing Task State

```swift
// Query a task
if let task = world.taskFrom(anyId: "T_AZvuCKoac") {
  print("Task state: \(task.state)")
}

// Check task completion
if task.isDone {
  print("Task completed!")
}

// Add planned action
var task = try world.taskFrom(anyId: taskId)!
task.addPlannedAction(Action(description: "Implement core logic"))
try world.updateTask(task)
```

### Stack Operations (Context Switching)

```swift
// Push task onto stack
world.pushTaskId(taskId)

// Get current task
if let currentId = world.currentTaskId() {
  let current = world.taskFrom(anyId: currentId)
}

// Pop task off stack
if let lastId = world.popTaskId() {
  print("Finished task: \(lastId)")
}
```

### Managing References

```swift
var task = try world.taskFrom(anyId: taskId)!
task.references.append(Reference(
  text: "See implementation guide",
  url: URL(string: "https://example.com/guide"),
  relevance: 0.9
))
try world.updateTask(task)
```

## CLI Design: Resources and Commands

The CLI (`task_cli.swift`) uses a unified architecture with two-level command structure: **nouns** (resources) and **verbs** (command types).

### IResource Protocol

All CLI resources implement a common protocol:

```swift
protocol IResource {
  var type: ResourceType { get }
  var id: String { get }  // Stable identifier (not transient position)
}
```

**Why:** Consolidates noun-specific logic (task, action, reference) into uniform handlers.

### ResourceType Enum

```swift
enum ResourceType {
  case task           // Primary resource
  case action         // Sub-resource: step within a task
  case reference      // Sub-resource: link/doc within a task
}
```

### Resource Implementations

**TaskResource:**
```swift
struct TaskResource: IResource {
  let type: ResourceType = .task
  let id: String  // Task prefix like "T_AZvuCKoac"
}
```

**ActionResource:**
```swift
struct ActionResource: IResource {
  let type: ResourceType = .action
  let taskId: String          // Which task contains this action
  let id: String              // Action's stable id from Action.id
}
```

**ReferenceResource:**
```swift
struct ReferenceResource: IResource {
  let type: ResourceType = .reference
  let taskId: String          // Which task contains this reference
  let id: String              // Reference's stable id from Reference.id
}
```

**Note:** Item numbers (1-based indices from CLI) are transient presentation artifacts. Reordering destroys correspondence. Handlers use stable `id` property instead.

### CommandType Enum

Unified verbs apply to all resources:

```swift
enum CommandType {
  case list       // Show items (tasks, actions, references)
  case add        // Create new item
  case replace    // Update existing item
  case delete     // Remove item
  case done       // Mark action as completed
  case push       // Add task to stack (task-specific)
  case pop        // Remove task from stack (task-specific)
  case show       // Display full details (task-specific)
  case initialize // Setup task infrastructure
}
```

### CommonOptions Struct

Unified option fields for all commands (eliminates naming inconsistency):

```swift
struct CommonOptions {
  let name: String?           // Primary identifier
  let description: String?    // Longer text content (replaces "summary")
  let url: URL?              // Reference URL
  let relevance: Double?     // Scoring (0-1)
  let format: String?        // Output format (json, text)
  let force: Bool            // Skip confirmation
  let showDone: Bool?        // Include done items
  let showUpdate: Bool?      // Show update timestamps
}
```

**Consistency benefit:** Same field names across all commands encourage reusable patterns and simplify future additions.

### Command Struct

Unified representation of any CLI invocation:

```swift
struct Command {
  let type: CommandType        // The verb
  let resource: IResource?     // The noun (nil for initialize)
  let task: Task?             // Resolved task object (nil if not needed)
  let options: CommonOptions   // Unified options
}
```

**Design:**
- `parseArgs()` returns a single `Command` instead of tuple `(rootDirectory, command, commandArgs)`
- Task resolution happens once in `parseArgs()`, result included in `Command`
- Handlers receive fully validated, structured input

### Handler Pattern

All handlers follow uniform signature:

```swift
func handleList(command: Command) throws
func handleAdd(command: Command) throws
func handleReplace(command: Command) throws
func handleDelete(command: Command) throws
func handleDone(command: Command) throws
```

**Benefit:** 5-6 unified handlers replace 20+ noun-specific handlers; task-lookup duplication eliminated.

## References

- `scv-tasks/Sources/scvTasks/ITaskWorld.swift` - Primary protocol; all code depends on this interface
- `scv-tasks/Sources/scvTasks/Task.swift` - Core task model with UUID encoding and state computation
- `scv-tasks/Sources/scvTasks/Action.swift` - Task step with name, description, complexity, duration
- `scv-tasks/Sources/scvTasks/Reference.swift` - Documentation link with relevance scoring
- `scv-tasks/Sources/scvTasks/TaskState.swift` - Task lifecycle enum (pending, blocked, active, done)
- `scv-tasks/Sources/scvTasks/TaskWorld.swift` - ITaskWorld implementation with in-memory dual-key map
- `scv-tasks/Sources/scvTasks/WorldModel.swift` - Stack and preferences manager; persisted to `.task-world.json`
- `scv-tasks/Sources/scvTasks/TaskManager.swift` - Low-level file I/O for individual task JSON files
- `scv-tasks/Sources/scvTasks/scvTasks.swift` - Module public exports (TaskId, AnyTaskId)
- `scv-tasks/Sources/CLI/task_cli.swift` - Optional command-line tool for shell integration
- `Tasks/T_*.json` - Individual task files (pretty-printed, sorted keys)
- `.task-world.json` - Task stack and user preferences
- `doc/Backlog.md` - Project backlog and task templates

## Future Enhancements

- Task dependency validation
- Markdown export of task details
- Bulk operations (batch create, filter by state)
- Task templates for recurring patterns
- Integration with git commit hooks
