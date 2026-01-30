import Foundation
import scvCore
import scvTasks
import UUIDV7

let DBG_TASK = 2

// Global state
nonisolated(unsafe) var commandTask: String? // T_BASE64 format (user-facing)
nonisolated(unsafe) var currentTaskUUIDV7: UUIDV7? // UUID format (internal)
nonisolated(unsafe) var commandItem: Int?

// Quick check: ensure task infrastructure exists before proceeding
// This prevents hanging when scvCore initializes in a directory without
// .task-world.json
// Exception: "init" command doesn't require existing infrastructure
do {
  let args = CommandLine.arguments
  let isInitCommand = args.contains("init")

  if !isInitCommand {
    var worldPath: String?

    // Check for --world flag in arguments
    for i in 0 ..< args.count {
      if args[i] == "-w" || args[i] == "--world", i + 1 < args.count {
        worldPath = args[i + 1]
        break
      }
    }

    let checkPath: String
    if let explicit = worldPath {
      checkPath = explicit
    } else {
      var currentPath = FileManager.default.currentDirectoryPath
      let fileManager = FileManager.default
      var found = false

      while true {
        let testPath = (currentPath as NSString)
          .appendingPathComponent(".task-world.json")
        if fileManager.fileExists(atPath: testPath) {
          found = true
          break
        }

        let parent = (currentPath as NSString).deletingLastPathComponent
        if parent == currentPath { break }
        currentPath = parent
      }

      if !found {
        print(
          "Error: Task infrastructure not found in current directory or ancestors.",
        )
        print("")
        print(
          "To initialize task infrastructure in the current directory, run:",
        )
        print("  task init")
        print("")
        print("Or specify a project location with --world:")
        print("  task --world /path/to/project list")
        exit(1)
      }
      checkPath = currentPath
    }
  }
} catch {
  print("Error: \(error)")
  exit(1)
}

// Parse command line arguments and initialize
do {
  let (rootDirectory, command, commandArgs) = try parseArgs()

  switch command {
  case "init":
    try handleInit(args: commandArgs, rootDirectory: rootDirectory)
  case "list":
    try handleList(args: commandArgs, rootDirectory: rootDirectory)
  case "add":
    try handleAdd(args: commandArgs, rootDirectory: rootDirectory)
  case "push":
    try handlePush(args: commandArgs, rootDirectory: rootDirectory)
  case "pop":
    try handlePop(args: commandArgs, rootDirectory: rootDirectory)
  case "show":
    try handleShow(args: commandArgs, rootDirectory: rootDirectory)
  case "delete":
    try handleDelete(args: commandArgs, rootDirectory: rootDirectory)
  case "action":
    try handleAction(args: commandArgs, rootDirectory: rootDirectory)
  case "ref", "reference":
    try handleReference(args: commandArgs, rootDirectory: rootDirectory)
  case "help", "-h", "--help":
    if !commandArgs.isEmpty {
      let helpTarget = commandArgs[0]
      let validCommands = Set([
        "init", "list", "add", "push", "pop", "show", "delete",
        "action", "ref", "reference",
      ])
      if validCommands.contains(helpTarget) {
        try printHelpForCommand(helpTarget)
      } else {
        print("Error: Unknown command '\(helpTarget)'")
        print(
          "Valid commands: init, list, add, push, pop, show, delete, action, ref, reference",
        )
      }
    } else {
      printUsage()
    }
  default:
    print("Error: Unknown command '\(command)'")
    printUsage()
    exit(1)
  }
} catch {
  print("Error: \(error)")
  exit(1)
}

// MARK: - Argument Parsing

func parseArgs() throws
  -> (rootDirectory: URL, command: String, commandArgs: [String])
{
  var rootDirectory: URL?
  var verbosityOverride: Int?
  var limitOverride: Int?
  var lineLengthOverride: Int?
  var showDoneOverride: Bool?
  var showUpdateOverride: Bool?
  var allArgs = Array(CommandLine.arguments.dropFirst())
  var globalOptionIndices = Set<Int>() // Track which indices are global options

  // First pass: extract global options from anywhere in the args
  var i = 0
  while i < allArgs.count {
    let arg = allArgs[i]

    if arg == "-w" || arg == "--world" {
      globalOptionIndices.insert(i)
      i += 1
      guard i < allArgs.count else {
        print("Error: -w/--world requires a directory path argument")
        exit(1)
      }
      rootDirectory = URL(fileURLWithPath: allArgs[i])
      globalOptionIndices.insert(i)
      i += 1
    } else if arg == "-v" || arg == "--verbosity" {
      globalOptionIndices.insert(i)
      i += 1
      guard i < allArgs.count else {
        print(
          "Error: -v/--verbosity requires a value (0: terse, 1: normal, 2: verbose)",
        )
        exit(1)
      }
      if let verbosity = Int(allArgs[i]), verbosity >= 0, verbosity <= 2 {
        verbosityOverride = verbosity
      } else {
        print("Error: -v/--verbosity requires value 0, 1, or 2")
        exit(1)
      }
      globalOptionIndices.insert(i)
      i += 1
    } else if arg == "-ll" || arg == "--ll" || arg == "--line-length" {
      globalOptionIndices.insert(i)
      i += 1
      guard i < allArgs.count else {
        print("Error: -ll/--ll/--line-length requires a value")
        exit(1)
      }
      guard let lineLength = Int(allArgs[i]), lineLength >= 20 else {
        print("Error: -ll/--ll/--line-length requires an integer value >= 20")
        exit(1)
      }
      lineLengthOverride = lineLength
      globalOptionIndices.insert(i)
      i += 1
    } else if arg == "-l" || arg == "--limit" {
      globalOptionIndices.insert(i)
      i += 1
      guard i < allArgs.count else {
        print("Error: -l/--limit requires a value")
        exit(1)
      }
      guard let limit = Int(allArgs[i]) else {
        print("Error: -l/--limit requires an integer value")
        exit(1)
      }
      limitOverride = limit
      globalOptionIndices.insert(i)
      i += 1
    } else if arg == "-i" || arg == "--item" {
      globalOptionIndices.insert(i)
      i += 1
      guard i < allArgs.count else {
        throw CliError.missingValue(arg)
      }
      guard let num = Int(allArgs[i]), num > 0 else {
        throw CliError.invalidActionNumber(allArgs[i])
      }
      commandItem = num
      globalOptionIndices.insert(i)
      i += 1
    } else if arg == "--no-show-done" {
      globalOptionIndices.insert(i)
      showDoneOverride = false
      i += 1
    } else if arg == "--show-done" {
      globalOptionIndices.insert(i)
      showDoneOverride = true
      i += 1
    } else if arg == "--no-show-update" {
      globalOptionIndices.insert(i)
      showUpdateOverride = false
      i += 1
    } else if arg == "--show-update" {
      globalOptionIndices.insert(i)
      showUpdateOverride = true
      i += 1
    } else {
      i += 1
    }
  }

  // Second pass: find command (first non-global-option argument)
  var commandIndex: Int?
  for (idx, _) in allArgs.enumerated() {
    if !globalOptionIndices.contains(idx) {
      commandIndex = idx
      break
    }
  }

  guard let commandIndex else {
    printUsage()
    exit(1)
  }

  let command = allArgs[commandIndex]
  // Pass only non-global-option args to the command
  let commandArgs = allArgs.enumerated()
    .filter { offset, _ in
      offset > commandIndex && !globalOptionIndices.contains(offset)
    }
    .map { _, arg in arg }

  // Set rootDirectory if not already specified via --world
  if rootDirectory == nil {
    if command == "init" {
      // init doesn't need to find .task-world.json, use current directory
      rootDirectory = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath,
        isDirectory: true,
      )
    } else {
      // Other commands need to find .task-world.json
      rootDirectory = try taskProjectRoot()
    }
  }

  let finalRootDirectory = rootDirectory!

  // Load or initialize WorldModel (skip for init)
  if command != "init" {
    let worldPath = finalRootDirectory
      .appendingPathComponent(".task-world.json")
    if FileManager.default.fileExists(atPath: worldPath.path) {
      do {
        let loadedWorld = try WorldModel.load(from: worldPath)
        // Replace shared instance with loaded one
        WorldModel.shared.taskStack = loadedWorld.taskStack
        WorldModel.shared.limit = loadedWorld.limit
        WorldModel.shared.verbosity = loadedWorld.verbosity
        WorldModel.shared.lineLength = loadedWorld.lineLength
        WorldModel.shared.showDone = loadedWorld.showDone
        WorldModel.shared.showUpdate = loadedWorld.showUpdate
      } catch {
        let cc = ColorConsole(#file, #function, DBG_TASK)
        cc.bad1(#line, "cannot load \(worldPath)")
        throw error
      }
    }

    // Apply verbosity, limit, lineLength, showDone, and showUpdate overrides if
    // specified
    if let verbosity = verbosityOverride {
      WorldModel.shared.verbosity = verbosity
    }
    if let limit = limitOverride {
      WorldModel.shared.limit = limit
    }
    if let lineLength = lineLengthOverride {
      WorldModel.shared.lineLength = lineLength
    }
    if let showDone = showDoneOverride {
      WorldModel.shared.showDone = showDone
    }
    if let showUpdate = showUpdateOverride {
      WorldModel.shared.showUpdate = showUpdate
    }
    if verbosityOverride != nil || limitOverride != nil || lineLengthOverride !=
      nil || showDoneOverride != nil || showUpdateOverride != nil
    {
      let worldPath = finalRootDirectory
        .appendingPathComponent(".task-world.json")
      try WorldModel.shared.save(to: worldPath)
    }
  }

  // Set commandTask from current top of stack, or newest task if stack empty
  // (skip for init)
  if command != "init" {
    if let taskId = WorldModel.shared.currentTask() {
      let base64 = Task.uuidToBase64(taskId)
      commandTask = "T_\(base64.prefix(9))"
      currentTaskUUIDV7 = taskId
    } else {
      // Stack is empty - default to newest task
      let taskManager = TaskManager(basePath: finalRootDirectory)
      let tasks = try taskManager.allTasks()
      if let newestTask = tasks.max(by: { $0.id < $1.id }) {
        commandTask = newestTask.idFile
        currentTaskUUIDV7 = newestTask.id
      }
    }
  }

  return (finalRootDirectory, command, commandArgs)
}

// MARK: - Helpers

func formatRelevanceBar(_ relevance: Double) -> String {
  let clamped = max(0, min(1, relevance))
  let scaled = clamped * 10 // 0-10 scale for 5 chars (2 per char)
  var bar = ""

  for i in 0 ..< 5 {
    let threshold = Double((4 - i) * 2)
    if scaled >= threshold + 2 {
      bar.append("█")
    } else if scaled > threshold + 1 {
      bar.append("▐")
    } else {
      bar.append("░")
    }
  }

  return bar
}

func wrapLine(_ line: String, maxLength: Int,
              hangingIndentWidth: Int = 5) -> String
{
  if line.count <= maxLength {
    return line
  }

  let hangingIndent = String(repeating: " ", count: hangingIndentWidth)
  let maxContentLength = maxLength - hangingIndentWidth

  var result = ""
  var remaining = String(line.dropFirst(hangingIndentWidth))

  while !remaining.isEmpty {
    if remaining.count <= maxContentLength {
      result += remaining
      break
    }

    // Find last space within maxContentLength
    let cutoffIndex = remaining.index(
      remaining.startIndex,
      offsetBy: maxContentLength,
      limitedBy: remaining.endIndex,
    ) ?? remaining.endIndex
    let beforeCutoff = String(remaining[..<cutoffIndex])

    if let lastSpace = beforeCutoff.lastIndex(of: " ") {
      // Space found within limit
      let lineContent = String(beforeCutoff[..<lastSpace])
      result += lineContent + "\n" + hangingIndent
      remaining = String(remaining[remaining.index(after: lastSpace)...])
    } else {
      // No space within limit, search entire remaining for any space
      if let anySpace = remaining.firstIndex(of: " ") {
        // Space found, use it even if exceeds limit
        let lineContent = String(remaining[..<anySpace])
        result += lineContent + "\n" + hangingIndent
        remaining = String(remaining[remaining.index(after: anySpace)...])
      } else {
        // No space found anywhere, append entire remaining (e.g., URL)
        result += remaining
        break
      }
    }
  }

  return String(line.prefix(hangingIndentWidth)) + result
}

// MARK: - Command Handlers

func handleList(args: [String], rootDirectory: URL) throws {
  // Parse command-line overrides
  var showDoneOverride: Bool?
  var showUpdateOverride: Bool?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-sd" || arg == "--show-done" {
      showDoneOverride = true
    } else if arg == "--no-show-done" {
      showDoneOverride = false
    } else if arg == "-su" || arg == "--show-update" {
      showUpdateOverride = true
    } else if arg == "--no-show-update" {
      showUpdateOverride = false
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  let world = TaskWorld(basePath: rootDirectory)

  // Use command-line overrides if specified, otherwise use persistent settings
  let showDone = showDoneOverride ?? world.showDone
  let showUpdate = showUpdateOverride ?? world.showUpdate

  let allTaskIds = world.allTaskIds(showFileName: true)
  let stackTaskIds = world.stackTaskIds()

  // Separate tasks into stack and non-stack groups
  // Display stack in reverse order (top of stack first)
  let stackTasks = stackTaskIds.reversed()
    .compactMap { world.taskFrom(anyId: $0) }
  let allNonStackTasks = allTaskIds
    .compactMap { world.taskFrom(anyId: $0) }
    .filter { !world.isStackTaskId($0.idFile) }

  // Sort non-stack tasks by update date (descending) if showUpdate is true,
  // otherwise by UUID (descending)
  let nonStackTasks = showUpdate
    ? allNonStackTasks.sorted { $0.updatedAt > $1.updatedAt }
    : allNonStackTasks.sorted { $0.id > $1.id }

  // Filter done tasks unless showDone is set
  let filteredStackTasks = showDone ? stackTasks : stackTasks
    .filter { $0.state != .done }
  let filteredNonStackTasks = showDone ? nonStackTasks : nonStackTasks
    .filter { $0.state != .done }
  let sortedTasks = filteredStackTasks + filteredNonStackTasks

  let effectiveLimit = world.limit
  var count = 0

  // Create date formatter if showing update dates
  let dateFormatter: DateFormatter?
  if showUpdate {
    let formatter = DateFormatter()
    // Get locale-specific short date format template with 2-digit year
    if let dateFormat = DateFormatter.dateFormat(
      fromTemplate: "yyMd",
      options: 0,
      locale: Locale.current,
    ) {
      // Append 24-hour time format (HH:mm)
      formatter.dateFormat = dateFormat + " HH:mm"
    } else {
      // Fallback if template generation fails
      formatter.dateStyle = .short
      formatter.timeStyle = .short
      formatter.locale = Locale.current
    }
    dateFormatter = formatter
  } else {
    dateFormatter = nil
  }

  for task in sortedTasks {
    if effectiveLimit > 0, count >= effectiveLimit {
      print("...")
      break
    }

    // Emoji based on task state
    let emoji = switch task.state {
    case .blocked:
      "🔴"
    case .pending:
      "🐢"
    case .active:
      world.isStackTaskId(task.idFile) ? "🟢" : "🐢"
    case .done:
      "☑️ "
    }

    count += 1

    let rowNum = String(format: "%3d", count)
    let separator = world.isStackTaskId(task.idFile) ? ":" : "."
    if let formatter = dateFormatter {
      let dateStr = formatter.string(from: task.updatedAt)
      print(
        "\(rowNum)\(separator) \(dateStr) \(task.idFile) \(emoji) \(task.name)",
      )
    } else {
      print("\(rowNum)\(separator) \(task.idFile) \(emoji) \(task.name)")
    }
  }
}

func handleAdd(args: [String], rootDirectory: URL) throws {
  var name: String?
  var summary: String?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-n" || arg == "--name" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      name = args[i]
    } else if arg == "-s" || arg == "--summary" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      summary = args[i]
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  guard let name else {
    throw CliError.missingRequired("-n/--name")
  }

  let world = TaskWorld(basePath: rootDirectory)
  let task = try world.createTaskSync(name: name, summary: summary ?? "")

  print("Created task: \(task.idFile) - \(task.name)")
}

func handleInit(args: [String], rootDirectory: URL) throws {
  // Check for unexpected arguments
  if !args.isEmpty {
    throw CliError.unknownOption(args[0])
  }

  let fileManager = FileManager.default
  let tasksDirectory = rootDirectory.appendingPathComponent(
    "Tasks",
    isDirectory: true,
  )
  let worldPath = rootDirectory.appendingPathComponent(".task-world.json")

  // Create Tasks directory if it doesn't exist
  if !fileManager.fileExists(atPath: tasksDirectory.path) {
    try fileManager.createDirectory(
      at: tasksDirectory,
      withIntermediateDirectories: true,
      attributes: nil,
    )
    print("Created Tasks directory")
  }

  // Create .task-world.json if it doesn't exist
  if !fileManager.fileExists(atPath: worldPath.path) {
    let world = WorldModel()
    try world.save(to: worldPath)
    print("Created .task-world.json")
  }

  print("Task infrastructure initialized in \(rootDirectory.path)")
}

func handlePush(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if !arg.hasPrefix("-") {
      // Positional argument: task prefix
      taskPrefix = arg
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  let task = try findTask(
    by: taskPrefix,
    from: tasks,
    rootDirectory: rootDirectory,
  )

  let world = TaskWorld(basePath: rootDirectory)

  // Remove from stack if present, then push to top
  world.unstackTaskId(task.idFile)
  world.pushTaskId(task.idFile)
  print("Pushed \(task.idFile) to stack")
}

func handlePop(args: [String], rootDirectory: URL) throws {
  var i = 0

  while i < args.count {
    let arg = args[i]
    throw CliError.unknownOption(arg)
  }

  let world = TaskWorld(basePath: rootDirectory)

  guard let poppedTaskId = world.popTaskId() else {
    throw CliError.missingRequired("task stack is empty")
  }

  if let task = world.taskFrom(anyId: poppedTaskId) {
    print("Popped \(task.idFile) from stack")
  } else {
    print("Popped task \(poppedTaskId) from stack")
  }
}

func handleShow(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var format = "text"
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg == "-f" || arg == "--format" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      format = args[i]
    } else if !arg.hasPrefix("-") {
      // Positional argument: task prefix
      taskPrefix = arg
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  let world = TaskWorld.shared
  let allTaskIds = world.allTaskIds(showFileName: true)
  let allTasks = allTaskIds.compactMap { world.taskFrom(anyId: $0) }
  let task = try findTask(
    by: taskPrefix,
    from: allTasks,
    rootDirectory: rootDirectory,
  )

  switch format.lowercased() {
  case "json":
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(task)
    if let json = String(data: data, encoding: .utf8) {
      print(json)
    }
  case "text":
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    dateFormatter.timeZone = TimeZone.current

    print(
      "Task: \(task.idFile) (Created: \(dateFormatter.string(from: task.createdAt)))",
    )
    print("Name: \(task.name)")
    print("Summary: \(task.summary)")
    print(
      "State: \(task.state.rawValue) (Updated: \(dateFormatter.string(from: task.updatedAt)))",
    )

    // Display blockers (required tasks that are not done)
    if !task.requiredTasks.isEmpty {
      var blockers: [(name: String, state: String)] = []
      for requiredTaskId in task.requiredTasks {
        if let requiredTask = world.taskFrom(anyId: requiredTaskId),
           requiredTask.state != TaskState.done
        {
          blockers.append((
            name: requiredTask.name,
            state: requiredTask.state.rawValue,
          ))
        }
      }

      if !blockers.isEmpty {
        print("\nBlockers:")
        for (index, blocker) in blockers.enumerated() {
          print("  \(index + 1). [\(blocker.state)] \(blocker.name)")
        }
      }
    }
    if !task.plannedActions.isEmpty {
      print("\nPlanned Actions:")
      let effectiveLimit = world.limit > 0 ? world.limit : task.plannedActions
        .count
      let displayPlannedActions = Array(task.plannedActions
        .prefix(effectiveLimit))
      for (index, action) in displayPlannedActions.enumerated() {
        print(wrapLine(
          "  \(index + 1). \(action.description)",
          maxLength: world.lineLength,
        ))
      }
      if task.plannedActions.count > effectiveLimit {
        print("  ...")
      }
    }
    if !task.completedActions.isEmpty {
      print("\nCompleted Actions:")
      let effectiveLimit = WorldModel.shared.limit > 0 ? WorldModel.shared
        .limit : task.completedActions.count
      let displayCompletedActions = Array(task.completedActions
        .prefix(effectiveLimit))
      for (index, action) in displayCompletedActions.enumerated() {
        print(wrapLine(
          "  \(index + 1). \(action.description)",
          maxLength: WorldModel.shared.lineLength,
        ))
      }
      if task.completedActions.count > effectiveLimit {
        print("  ...")
      }
    }
    if !task.references.isEmpty {
      print("\nReferences:")
      let effectiveLimit = WorldModel.shared.limit > 0 ? WorldModel.shared
        .limit : task.references.count
      let displayReferences = Array(task.references.prefix(effectiveLimit))
      let isClipped = task.references.count > effectiveLimit

      for (index, ref) in displayReferences.enumerated() {
        switch WorldModel.shared.verbosity {
        case 0: // Terse: index only
          print("  \(index + 1).")
        case 1: // Normal: 2 lines max
          var firstLine = "  \(index + 1). \(formatRelevanceBar(ref.relevance))"
          if let url = ref.url {
            firstLine += " \(url.absoluteString)"
            print(wrapLine(firstLine, maxLength: WorldModel.shared.lineLength))
            if let text = ref.text {
              print(wrapLine(
                "     \(text)",
                maxLength: WorldModel.shared.lineLength,
              ))
            }
          } else if let text = ref.text {
            firstLine += " \(text)"
            print(wrapLine(firstLine, maxLength: WorldModel.shared.lineLength))
          } else {
            print(firstLine)
          }
        case 2: // Verbose: all fields
          print("  \(index + 1).")
          print(wrapLine(
            "    id: \(ref.id)",
            maxLength: WorldModel.shared.lineLength,
          ))
          if let text = ref.text {
            print(wrapLine(
              "    text: \(text)",
              maxLength: WorldModel.shared.lineLength,
            ))
          }
          if let url = ref.url {
            print(wrapLine(
              "    url: \(url.absoluteString)",
              maxLength: WorldModel.shared.lineLength,
            ))
          }
          print("    relevance: \(String(format: "%.2f", ref.relevance))")
        default:
          break
        }
      }

      if isClipped {
        print("  ...")
      }
    }
  default:
    throw CliError.unknownFormat(format)
  }
}

func handleDelete(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var force = false
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg == "--force" {
      force = true
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()
  let task = try findTask(
    by: taskPrefix,
    from: tasks,
    rootDirectory: rootDirectory,
  )

  // Prompt for confirmation unless --force
  if !force {
    print("Delete task: \(task.idFile) - \(task.name)")
    print("Are you sure? (y/n): ", terminator: "")
    fflush(stdout)

    guard let response = readLine()?.lowercased(), response == "y" else {
      print("Cancelled")
      return
    }
  }

  // Delete the task file
  let filePath = rootDirectory.appendingPathComponent("Tasks")
    .appendingPathComponent("\(task.idFile).json")
  try FileManager.default.removeItem(at: filePath)

  print("Deleted task: \(task.idFile) - \(task.name)")
}

func handleAction(args: [String], rootDirectory: URL) throws {
  guard !args.isEmpty else {
    throw CliError
      .missingRequired("action subcommand (list, add, replace, delete)")
  }

  let subcommand = args[0]
  let subcommandArgs = Array(args.dropFirst())

  switch subcommand {
  case "list":
    try handleActionList(args: subcommandArgs, rootDirectory: rootDirectory)
  case "add":
    try handleActionAdd(args: subcommandArgs, rootDirectory: rootDirectory)
  case "replace":
    try handleActionReplace(args: subcommandArgs, rootDirectory: rootDirectory)
  case "done":
    try handleActionDone(args: subcommandArgs, rootDirectory: rootDirectory)
  case "delete":
    try handleActionDelete(args: subcommandArgs, rootDirectory: rootDirectory)
  default:
    throw CliError.unknownSubcommand(subcommand)
  }
}

func handleActionList(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg.hasPrefix("-") {
      throw CliError.unknownOption(arg)
    } else {
      break
    }

    i += 1
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()
  let task = try findTask(
    by: taskPrefix,
    from: tasks,
    rootDirectory: rootDirectory,
  )

  if task.plannedActions.isEmpty {
    print("No planned actions")
  } else {
    print("Planned Actions:")
    for (index, action) in task.plannedActions.enumerated() {
      print("  \(index + 1). \(action.description)")
    }
  }

  if !task.completedActions.isEmpty {
    print("\nCompleted Actions:")
    for (index, action) in task.completedActions.enumerated() {
      print("  \(index + 1). \(action.description)")
    }
  }
}

func handleActionAdd(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var description: String?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg.hasPrefix("-") {
      throw CliError.unknownOption(arg)
    } else {
      // Positional argument - description
      description = arg
      i += 1
      break
    }

    i += 1
  }

  // Check for extra positional arguments
  while i < args.count {
    let arg = args[i]
    if !arg.hasPrefix("-") {
      let cc = ColorConsole(#file, #function, 1)
      cc.bad1(
        #line,
        "Expected at most 1 positional argument, got extra: \(arg)",
      )
      try printHelpForCommand("action")
      throw CliError.invalidArgument("Too many positional arguments")
    }
    i += 1
  }

  guard let description else {
    throw CliError.missingRequired("DESCRIPTION")
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36, inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.idFile.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks
        .filter { $0.idFile.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.idFile < $1.idFile }) {
        print("  \(t.idFile) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task else {
    throw CliError.taskNotFound
  }

  // Add new action
  let newAction = Action(description: description)

  if let position = commandItem {
    // Convert 1-based position to 0-based index
    let index = position - 1
    guard index >= 0, index <= task.plannedActions.count else {
      throw CliError.invalidActionIndex(position, task.plannedActions.count + 1)
    }
    task.plannedActions.insert(newAction, at: index)
    task.updatedAt = Date()
    try taskManager.save(task)
    print(
      "Inserted action #\(position) in \(task.idFile): \(description)",
    )
  } else {
    // Append to end (default behavior)
    task.plannedActions.append(newAction)
    task.updatedAt = Date()
    try taskManager.save(task)
    print(
      "Added action #\(task.plannedActions.count) to \(task.idFile): \(description)",
    )
  }
}

func handleActionReplace(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var description: String?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg.hasPrefix("-") {
      throw CliError.unknownOption(arg)
    } else {
      // Positional argument - description
      description = arg
      break
    }

    i += 1
  }

  guard let actionNumber = commandItem else {
    throw CliError.missingRequired("-i/--item")
  }

  guard let description else {
    throw CliError.missingRequired("DESCRIPTION")
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36, inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.idFile.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks
        .filter { $0.idFile.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.idFile < $1.idFile }) {
        print("  \(t.idFile) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task else {
    throw CliError.taskNotFound
  }

  // Convert 1-based action number to 0-based index
  let actionIndex = actionNumber - 1
  guard actionIndex >= 0, actionIndex < task.plannedActions.count else {
    throw CliError.invalidActionIndex(actionNumber, task.plannedActions.count)
  }

  let oldDescription = task.plannedActions[actionIndex].description
  task.plannedActions[actionIndex].description = description
  task.updatedAt = Date()

  try taskManager.save(task)

  print("Replaced action #\(actionNumber) in \(task.idFile)")
  print("  Old: \(oldDescription)")
  print("  New: \(description)")
}

func handleActionDone(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  let actionNumber = commandItem ?? 1

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36, inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.idFile.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks
        .filter { $0.idFile.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.idFile < $1.idFile }) {
        print("  \(t.idFile) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task else {
    throw CliError.taskNotFound
  }

  // Convert 1-based action number to 0-based index
  let actionIndex = actionNumber - 1
  guard actionIndex >= 0, actionIndex < task.plannedActions.count else {
    throw CliError.invalidActionIndex(actionNumber, task.plannedActions.count)
  }

  let actionDescription = task.plannedActions[actionIndex].description

  // Move action from planned to completed
  task.moveActionToCompleted(at: actionIndex)

  try taskManager.save(task)

  print(
    "Completed action #\(actionNumber) in \(task.idFile): \(actionDescription)",
  )
}

func handleActionDelete(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var force = false
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg == "--force" {
      force = true
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  guard let actionNumber = commandItem else {
    throw CliError.missingRequired("-i/--item")
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36, inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.idFile.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks
        .filter { $0.idFile.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.idFile < $1.idFile }) {
        print("  \(t.idFile) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task else {
    throw CliError.taskNotFound
  }

  // Convert 1-based action number to 0-based index
  let actionIndex = actionNumber - 1
  guard actionIndex >= 0, actionIndex < task.plannedActions.count else {
    throw CliError.invalidActionIndex(actionNumber, task.plannedActions.count)
  }

  let actionDescription = task.plannedActions[actionIndex].description

  // Prompt for confirmation unless --force
  if !force {
    print(
      "Delete action #\(actionNumber) from \(task.idFile): \(actionDescription)",
    )
    print("Are you sure? (y/n): ", terminator: "")
    fflush(stdout)

    guard let response = readLine()?.lowercased(), response == "y" else {
      print("Cancelled")
      return
    }
  }

  task.plannedActions.remove(at: actionIndex)
  task.updatedAt = Date()

  try taskManager.save(task)

  print(
    "Deleted action #\(actionNumber) from \(task.idFile): \(actionDescription)",
  )
}

func handleReference(args: [String], rootDirectory: URL) throws {
  guard !args.isEmpty else {
    throw CliError
      .missingRequired("reference subcommand (list, add, replace, delete)")
  }

  let subcommand = args[0]
  let subcommandArgs = Array(args.dropFirst())

  switch subcommand {
  case "list":
    try handleReferenceList(args: subcommandArgs, rootDirectory: rootDirectory)
  case "add":
    try handleReferenceAdd(args: subcommandArgs, rootDirectory: rootDirectory)
  case "replace":
    try handleReferenceReplace(
      args: subcommandArgs,
      rootDirectory: rootDirectory,
    )
  case "delete":
    try handleReferenceDelete(
      args: subcommandArgs,
      rootDirectory: rootDirectory,
    )
  default:
    throw CliError.unknownSubcommand(subcommand)
  }
}

func handleReferenceList(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg.hasPrefix("-") {
      throw CliError.unknownOption(arg)
    } else {
      break
    }

    i += 1
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()
  let task = try findTask(
    by: taskPrefix,
    from: tasks,
    rootDirectory: rootDirectory,
  )

  if task.references.isEmpty {
    print("No references")
  } else {
    print("References:")
    for (index, ref) in task.references.enumerated() {
      print(
        "  \(index + 1). \(formatRelevanceBar(ref.relevance))",
        terminator: "",
      )
      if let url = ref.url {
        print(" \(url.absoluteString)", terminator: "")
      }
      if let text = ref.text {
        print(" \(text)", terminator: "")
      }
      print()
    }
  }
}

func handleReferenceAdd(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var url: URL?
  var text: String?
  var relevance = 0.5
  var i = 0
  var positionalArgs: [String] = []

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg == "-u" || arg == "--url" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      url = URL(string: args[i])
    } else if arg == "-x" || arg == "--text" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      text = args[i]
    } else if arg == "-r" || arg == "--relevance" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      guard let rel = Double(args[i]) else {
        throw CliError.invalidInteger(args[i])
      }
      relevance = rel
    } else if arg.hasPrefix("-") {
      throw CliError.unknownOption(arg)
    } else {
      positionalArgs.append(arg)
    }

    i += 1
  }

  // Process positional args: if looks like URL, treat as URL; otherwise text
  for positional in positionalArgs {
    if positional.contains("://"), url == nil {
      url = URL(string: positional)
    } else if url == nil, text == nil {
      text = positional
    } else if text == nil {
      text = positional
    }
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36, inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.idFile.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks
        .filter { $0.idFile.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.idFile < $1.idFile }) {
        print("  \(t.idFile) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task else {
    throw CliError.taskNotFound
  }

  // Add new reference
  let newRef = Reference(text: text, url: url, relevance: relevance)
  task.references.append(newRef)
  task.updatedAt = Date()

  try taskManager.save(task)

  print("Added reference #\(task.references.count) to \(task.idFile)")
}

func handleReferenceReplace(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var url: URL?
  var text: String?
  var relevance: Double?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg == "-u" || arg == "--url" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      url = URL(string: args[i])
    } else if arg == "-x" || arg == "--text" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      text = args[i]
    } else if arg == "-r" || arg == "--relevance" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      guard let rel = Double(args[i]) else {
        throw CliError.invalidInteger(args[i])
      }
      relevance = rel
    } else if arg.hasPrefix("-") {
      throw CliError.unknownOption(arg)
    } else {
      break
    }

    i += 1
  }

  guard let refNumber = commandItem else {
    throw CliError.missingRequired("-i/--item")
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36, inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.idFile.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks
        .filter { $0.idFile.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.idFile < $1.idFile }) {
        print("  \(t.idFile) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task else {
    throw CliError.taskNotFound
  }

  // Convert 1-based reference number to 0-based index
  let refIndex = refNumber - 1
  guard refIndex >= 0, refIndex < task.references.count else {
    throw CliError.invalidActionIndex(refNumber, task.references.count)
  }

  var ref = task.references[refIndex]

  // Update fields that were provided
  if let text {
    ref.text = text
  }
  if let url {
    ref.url = url
  }
  if let relevance {
    ref.relevance = max(0, min(1, relevance))
  }

  task.references[refIndex] = ref
  task.updatedAt = Date()

  try taskManager.save(task)

  print("Replaced reference #\(refNumber) in \(task.idFile)")
}

func handleReferenceDelete(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var force = false
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-t" || arg == "--task" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      taskPrefix = args[i]
    } else if arg == "--force" {
      force = true
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  guard let refNumber = commandItem else {
    throw CliError.missingRequired("-i/--item")
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36, inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.idFile.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks
        .filter { $0.idFile.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.idFile < $1.idFile }) {
        print("  \(t.idFile) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task else {
    throw CliError.taskNotFound
  }

  // Convert 1-based reference number to 0-based index
  let refIndex = refNumber - 1
  guard refIndex >= 0, refIndex < task.references.count else {
    throw CliError.invalidActionIndex(refNumber, task.references.count)
  }

  let ref = task.references[refIndex]
  var refDesc = "[\(String(format: "%.2f", ref.relevance))]"
  if let url = ref.url {
    refDesc += " \(url.absoluteString)"
  }
  if let text = ref.text {
    refDesc += " \(text)"
  }

  // Prompt for confirmation unless --force
  if !force {
    print("Delete reference #\(refNumber) from \(task.idFile): \(refDesc)")
    print("Are you sure? (y/n): ", terminator: "")
    fflush(stdout)

    guard let response = readLine()?.lowercased(), response == "y" else {
      print("Cancelled")
      return
    }
  }

  task.references.remove(at: refIndex)
  task.updatedAt = Date()

  try taskManager.save(task)

  print("Deleted reference #\(refNumber) from \(task.idFile): \(refDesc)")
}

// MARK: - Error Types

enum CliError: LocalizedError {
  case missingValue(String)
  case unknownOption(String)
  case missingRequired(String)
  case unknownFormat(String)
  case invalidInteger(String)
  case invalidActionNumber(String)
  case invalidArgument(String)
  case noTasksFound
  case taskNotFound
  case unknownSubcommand(String)
  case invalidActionIndex(Int, Int)

  var errorDescription: String? {
    switch self {
    case let .missingValue(opt):
      "Option '\(opt)' requires a value"
    case let .unknownOption(opt):
      "Unknown option '\(opt)'"
    case let .missingRequired(opt):
      "Required option '\(opt)' not provided"
    case let .unknownFormat(fmt):
      "Unknown format '\(fmt)'. Valid formats: json, text"
    case let .invalidInteger(val):
      "Invalid integer value '\(val)'"
    case let .invalidActionNumber(val):
      "Invalid action number '\(val)'. Must be a positive integer (1-based)"
    case let .invalidArgument(msg):
      msg
    case .noTasksFound:
      "No tasks found"
    case .taskNotFound:
      "Task not found"
    case let .unknownSubcommand(sub):
      "Unknown action subcommand '\(sub)'. Valid subcommands: list, add, replace, done, delete"
    case let .invalidActionIndex(num, count):
      "Invalid action number #\(num). Valid range: 1-\(count)"
    }
  }
}

// MARK: - Helpers

func taskProjectRoot() throws -> URL {
  var currentPath = FileManager.default.currentDirectoryPath
  let fileManager = FileManager.default

  // Traverse upwards looking for .task-world.json
  while true {
    let worldPath = URL(fileURLWithPath: currentPath)
      .appendingPathComponent(".task-world.json").path
    if fileManager.fileExists(atPath: worldPath) {
      return URL(fileURLWithPath: currentPath, isDirectory: true)
    }

    let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
      .path
    if parent == currentPath {
      // Reached filesystem root without finding .task-world.json
      print(
        "Error: Task infrastructure not found in current directory or ancestors.",
      )
      print("Current path: \(currentPath)")
      print("")
      print("To initialize task infrastructure in the current directory, run:")
      print("  task init")
      print("")
      print("Or specify a project location with --world:")
      print("  task --world /path/to/project list")
      exit(1)
    }

    currentPath = parent
  }
}

func findTask(by prefix: String?, from tasks: [Task],
              rootDirectory _: URL) throws -> Task
{
  let inputPrefix = prefix ?? commandTask
  guard let inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36, inputPrefix.contains("-") {
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let fullPrefix = inputPrefix
      .hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.idFile.hasPrefix(fullPrefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks
        .filter { $0.idFile.lowercased().hasPrefix(fullPrefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(fullPrefix)':")
      for t in matchingTasks.sorted(by: { $0.idFile < $1.idFile }) {
        print("  \(t.idFile) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard let task else {
    throw CliError.taskNotFound
  }

  return task
}

// MARK: - Usage

func printHelpForCommand(_ command: String) throws {
  switch command {
  case "init":
    print("Usage: task init")
    print("")
    print("Initialize task infrastructure in the current directory.")
    print("Creates Tasks/ directory and .task-world.json file.")
    print("")
    print("Example:")
    print("  task init")
  case "list":
    print(
      "Usage: task list [-sd|--show-done|--no-show-done] [-su|--show-update|--no-show-update]",
    )
    print("")
    print("List all tasks sorted by stack status and creation date.")
    print(
      "Persistent settings stored in .task-world.json. By default, done tasks are hidden and tasks sorted by UUID.",
    )
    print("Shows emoji indicators: 🔴 blocked, 🟢 stacked, 🐢 unstacked, ☑️ done")
    print("")
    print("Options:")
    print("  -sd, --show-done        Include done tasks (persists)")
    print("  --no-show-done          Hide done tasks (persists)")
    print(
      "  -su, --show-update      Show update date and sort by update date (persists)",
    )
    print(
      "  --no-show-update        Hide update date and sort by UUID (persists)",
    )
    print("")
    print("Example:")
    print("  task list")
    print("  task list -sd")
    print("  task list -su")
    print("  task list --show-done --show-update")
    print("  task --no-show-done list  # global flag")
  case "add":
    print("Usage: task add -n NAME [-s SUMMARY]")
    print("")
    print("Create a new task.")
    print("")
    print("Options:")
    print("  -n, --name TEXT      Task name (required)")
    print("  -s, --summary TEXT   Task summary (optional)")
    print("")
    print("Example:")
    print(
      "  task add -n \"Implement feature X\" -s \"Add user authentication\"",
    )
  case "push":
    print("Usage: task push [PREFIX] [-t|--task PREFIX]")
    print("")
    print("Push a task to the stack (for prioritization).")
    print("If already stacked, moves to top.")
    print("")
    print("Options:")
    print(
      "  -t, --task PREFIX    Task prefix or full name (default: current task or most recent)",
    )
    print("")
    print("Example:")
    print("  task push                # Use current task from stack")
    print("  task push T_AZ           # Positional argument")
    print("  task push -t T_AZ        # Named argument")
  case "pop":
    print("Usage: task pop")
    print("")
    print("Remove the top task from the stack.")
    print("")
    print("Example:")
    print("  task pop")
  case "show":
    print("Usage: task show [-t|--task PREFIX] [-f|--format FORMAT]")
    print("")
    print("Display task details including actions and references.")
    print("")
    print("Options:")
    print(
      "  -t, --task PREFIX    Task prefix or full name (default: current task)",
    )
    print("  -f, --format FORMAT  Output format: json or text (default: text)")
    print("")
    print("Example:")
    print("  task show -t T_AZ")
    print("  task show -t T_AZ -f json")
  case "delete":
    print("Usage: task delete [-t|--task PREFIX] [--force]")
    print("")
    print("Delete a task (prompts for confirmation unless --force).")
    print("")
    print("Options:")
    print(
      "  -t, --task PREFIX    Task prefix or full name (default: current task)",
    )
    print("  --force              Skip confirmation prompt")
    print("")
    print("Example:")
    print("  task delete -t T_AZ")
    print("  task delete -t T_AZ --force")
  case "action":
    print("Usage: task action <subcommand> [OPTIONS]")
    print("")
    print("Manage planned and completed actions for tasks.")
    print("")
    print("Subcommands:")
    print("  list [-t|--task PREFIX]")
    print("      List actions for task")
    print("  add [-i NUMBER] [-t|--task PREFIX] DESCRIPTION")
    print("      Add action (insert at position if -i specified)")
    print("  replace -i NUMBER [-t|--task PREFIX] DESCRIPTION")
    print("      Replace action #NUMBER (1-based)")
    print("  done [-i NUMBER] [-t|--task PREFIX]")
    print(
      "      Move first planned action to completed (or action #NUMBER if -i specified)",
    )
    print("  delete -i NUMBER [-t|--task PREFIX] [--force]")
    print("      Delete action #NUMBER")
    print("")
    print("Example:")
    print("  task action list")
    print("  task action add -t T_AZ \"New action\"")
    print("  task action add -i 1 \"Insert at position 1\"")
    print(
      "  task action done  # move first planned action to completed actions",
    )
  case "ref", "reference":
    print("Usage: task ref <subcommand> [OPTIONS]")
    print("")
    print("Manage references (URLs, text, relevance scores) for tasks.")
    print("Synonyms: ref, reference")
    print("")
    print("Subcommands:")
    print("  list [-t|--task PREFIX]")
    print("      List references for task")
    print(
      "  add [URL|TEXT] [-t|--task PREFIX] [-u|--url URL] [-x|--text TEXT] [-r|--relevance REL]",
    )
    print("      Add reference (positional: URL or text, or use -u/-x flags)")
    print(
      "  replace -i NUMBER [-t|--task PREFIX] [-u|--url URL] [-x|--text TEXT] [-r|--relevance REL]",
    )
    print("      Replace reference #NUMBER")
    print("  delete -i NUMBER [-t|--task PREFIX] [--force]")
    print("      Delete reference #NUMBER")
    print("")
    print("Example:")
    print("  task ref list -t T_AZ")
    print("  task ref add https://example.com")
    print(
      "  task reference add -t T_AZ https://example.com -x \"Example\" -r 0.8",
    )
  default:
    throw CliError.unknownSubcommand(command)
  }
}

func printUsage() {
  let usage = """
  Usage: task [OPTIONS] <command> [ARGS]

  Options:
    -w, --world DIR     Project root directory (default: current directory)
    -v, --verbosity LVL Set verbosity level (0: terse, 1: normal, 2: verbose)
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
                        Add action to task (insert at position if -i specified)
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
  """
  print(usage)
}
