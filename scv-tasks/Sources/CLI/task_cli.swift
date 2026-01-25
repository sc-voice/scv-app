import Foundation
import UUIDV7
import scvTasks
import scvCore

let DBG_TASK = 2

// Global state
nonisolated(unsafe) var commandTask: String?

// Parse command line arguments and initialize
do {
  let (rootDirectory, command, commandArgs) = try parseArgs()

  switch command {
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
  case "help", "-h", "--help":
    printUsage()
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

func parseArgs() throws -> (rootDirectory: URL, command: String, commandArgs: [String]) {
  var rootDirectory = projectRoot()
  var verbosityOverride: Int?
  var commandIndex = 0
  let args = Array(CommandLine.arguments.dropFirst())

  // Parse global options
  while commandIndex < args.count {
    let arg = args[commandIndex]

    if arg == "-w" || arg == "--world" {
      commandIndex += 1
      guard commandIndex < args.count else {
        print("Error: -w/--world requires a directory path argument")
        exit(1)
      }
      rootDirectory = URL(fileURLWithPath: args[commandIndex])
      commandIndex += 1
    } else if arg == "-v" || arg == "--verbosity" {
      commandIndex += 1
      guard commandIndex < args.count else {
        print("Error: -v/--verbosity requires a value (0: terse, 1: normal, 2: verbose)")
        exit(1)
      }
      if let verbosity = Int(args[commandIndex]), verbosity >= 0 && verbosity <= 2 {
        verbosityOverride = verbosity
      } else {
        print("Error: -v/--verbosity requires value 0, 1, or 2")
        exit(1)
      }
      commandIndex += 1
    } else {
      break
    }
  }

  // Load or initialize WorldModel
  let worldPath = rootDirectory.appendingPathComponent(".world.json")
  if FileManager.default.fileExists(atPath: worldPath.path) {
    do {
      let loadedWorld = try WorldModel.load(from: worldPath)
      // Replace shared instance with loaded one
      WorldModel.shared.taskStack = loadedWorld.taskStack
      WorldModel.shared.limit = loadedWorld.limit
      WorldModel.shared.verbosity = loadedWorld.verbosity
    } catch {
      let cc = ColorConsole(#file, #function, DBG_TASK)
      cc.bad1(#line, "cannot load \(worldPath)")
      throw error
    }
  }

  // Apply verbosity override if specified
  if let verbosity = verbosityOverride {
    WorldModel.shared.verbosity = verbosity
    try WorldModel.shared.save(to: worldPath)
  }

  // Set commandTask from current top of stack
  if let taskId = WorldModel.shared.currentTask() {
    commandTask = taskId.uuidString
  }

  // Get command
  guard commandIndex < args.count else {
    printUsage()
    exit(1)
  }

  let command = args[commandIndex]
  let commandArgs = Array(args.dropFirst(commandIndex + 1))

  return (rootDirectory, command, commandArgs)
}

// MARK: - Command Handlers

func handleList(args: [String], rootDirectory: URL) throws {
  var limit: Int?
  var i = 0

  while i < args.count {
    let arg = args[i]

    if arg == "-l" || arg == "--limit" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      guard let parsedLimit = Int(args[i]) else {
        throw CliError.invalidInteger(args[i])
      }
      limit = parsedLimit
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()
  let sortedTasks = tasks.sorted { $0.id > $1.id }

  // Update WorldModel limit if specified
  if let limit = limit {
    WorldModel.shared.limit = limit
    let worldPath = rootDirectory.appendingPathComponent(".world.json")
    try WorldModel.shared.save(to: worldPath)
  }

  let effectiveLimit = limit ?? WorldModel.shared.limit
  var count = 0

  for task in sortedTasks {
    if effectiveLimit > 0 && count >= effectiveLimit {
      break
    }

    let emoji: String
    switch task.state {
    case .blocked:
      emoji = "🚫"
    case .active:
      emoji = "🟢"
    case .done:
      emoji = "☑️"
    }

    print("\(task.fileName) \(emoji) \(task.name)")
    count += 1
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

  guard let name = name else {
    throw CliError.missingRequired("-n/--name")
  }

  let task = Task(
    name: name,
    summary: summary ?? ""
  )

  let taskManager = TaskManager(basePath: rootDirectory)
  try taskManager.save(task)

  print("Created task: \(task.fileName) - \(task.name)")
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
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  // Determine which task to push
  let inputPrefix = taskPrefix ?? commandTask

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  guard !tasks.isEmpty else {
    throw CliError.noTasksFound
  }

  let sortedTasks = tasks.sorted { $0.id > $1.id }
  var taskToPush: Task?

  if let prefix = inputPrefix {
    // Find task by prefix
    let fullPrefix = prefix.hasPrefix("T_") ? prefix : "T_" + prefix

    for task in sortedTasks {
      if task.fileName.hasPrefix(fullPrefix) {
        taskToPush = task
        break
      }
    }

    guard taskToPush != nil else {
      throw CliError.taskNotFound
    }
  } else {
    // No prefix specified and no commandTask - use most recently created
    taskToPush = sortedTasks[0]
  }

  guard let task = taskToPush else {
    throw CliError.noTasksFound
  }

  // Remove from stack if present, then push to top
  if let index = WorldModel.shared.taskStack.firstIndex(of: task.id) {
    WorldModel.shared.taskStack.remove(at: index)
  }
  WorldModel.shared.pushTask(task.id)
  print("Pushed \(task.fileName) to stack")

  // Serialize WorldModel
  let worldPath = rootDirectory.appendingPathComponent(".world.json")
  try WorldModel.shared.save(to: worldPath)
}

func handlePop(args: [String], rootDirectory: URL) throws {
  var i = 0

  while i < args.count {
    let arg = args[i]
    throw CliError.unknownOption(arg)
  }

  guard !WorldModel.shared.taskStack.isEmpty else {
    throw CliError.missingRequired("task stack is empty")
  }

  let poppedTaskId = WorldModel.shared.taskStack.removeLast()

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  if let task = tasks.first(where: { $0.id == poppedTaskId }) {
    print("Popped \(task.fileName) from stack")
  } else {
    print("Popped task \(poppedTaskId.uuidString) from stack")
  }

  // Serialize WorldModel
  let worldPath = rootDirectory.appendingPathComponent(".world.json")
  try WorldModel.shared.save(to: worldPath)
}

func handleShow(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var format: String = "text"
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
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  // Use commandTask if -t not specified
  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix = inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36 && inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix

    // Try case-sensitive match first
    var matchingTasks = tasks.filter { $0.fileName.hasPrefix(prefix) }

    // If no match, try case-insensitive
    if matchingTasks.isEmpty {
      matchingTasks = tasks.filter { $0.fileName.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      print("Error: No task found with prefix '\(prefix)'")
      exit(1)
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.fileName < $1.fileName }) {
        print("  \(t.fileName) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard let task = task else {
    print("Error: Task not found")
    exit(1)
  }

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
    print("Task: \(task.fileName)")
    print("Name: \(task.name)")
    print("Summary: \(task.summary)")
    print("State: \(task.state.rawValue)")
    print("Created: \(task.createdAt)")
    print("Updated: \(task.updatedAt)")
    if !task.plannedActions.isEmpty {
      print("\nPlanned Actions:")
      for (index, action) in task.plannedActions.enumerated() {
        print("  #\(index + 1) \(action.description)")
      }
    }
    if !task.completedActions.isEmpty {
      print("\nCompleted Actions:")
      for (index, action) in task.completedActions.enumerated() {
        print("  #\(index + 1) \(action.description)")
      }
    }
    if !task.references.isEmpty {
      print("\nReferences:")
      for (index, ref) in task.references.enumerated() {
        switch WorldModel.shared.verbosity {
        case 0:  // Terse: index only
          print("  [\(index)]")
        case 1:  // Normal: 2 lines max
          var firstLine = "  \(index). [\(String(format: "%.2f", ref.relevance))]"
          if let url = ref.url {
            firstLine += " \(url.absoluteString)"
            print(firstLine)
            if let text = ref.text {
              print("     \(text)")
            }
          } else if let text = ref.text {
            firstLine += " \(text)"
            print(firstLine)
          } else {
            print(firstLine)
          }
        case 2:  // Verbose: all fields
          print("  [\(index)]")
          print("    id: \(ref.id)")
          if let text = ref.text {
            print("    text: \(text)")
          }
          if let url = ref.url {
            print("    url: \(url.absoluteString)")
          }
          print("    relevance: \(String(format: "%.2f", ref.relevance))")
        default:
          break
        }
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

  // Use commandTask if -t not specified
  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix = inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36 && inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix

    // Try case-sensitive match first
    var matchingTasks = tasks.filter { $0.fileName.hasPrefix(prefix) }

    // If no match, try case-insensitive
    if matchingTasks.isEmpty {
      matchingTasks = tasks.filter { $0.fileName.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      print("Error: No task found with prefix '\(prefix)'")
      exit(1)
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.fileName < $1.fileName }) {
        print("  \(t.fileName) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard let task = task else {
    print("Error: Task not found")
    exit(1)
  }

  // Prompt for confirmation unless --force
  if !force {
    print("Delete task: \(task.fileName) - \(task.name)")
    print("Are you sure? (y/n): ", terminator: "")
    fflush(stdout)

    guard let response = readLine()?.lowercased(), response == "y" else {
      print("Cancelled")
      return
    }
  }

  // Delete the task file
  let filePath = rootDirectory.appendingPathComponent("Tasks").appendingPathComponent("\(task.fileName).json")
  try FileManager.default.removeItem(at: filePath)

  print("Deleted task: \(task.fileName) - \(task.name)")
}

func handleAction(args: [String], rootDirectory: URL) throws {
  guard !args.isEmpty else {
    throw CliError.missingRequired("action subcommand (list, add, replace, delete)")
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

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix = inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36 && inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.fileName.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks.filter { $0.fileName.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.fileName < $1.fileName }) {
        print("  \(t.fileName) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard let task = task else {
    throw CliError.taskNotFound
  }

  if task.plannedActions.isEmpty {
    print("No planned actions")
  } else {
    print("Planned Actions:")
    for (index, action) in task.plannedActions.enumerated() {
      print("  #\(index + 1) \(action.description)")
    }
  }

  if !task.completedActions.isEmpty {
    print("\nCompleted Actions:")
    for (index, action) in task.completedActions.enumerated() {
      print("  #\(index + 1) \(action.description)")
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
      break
    }

    i += 1
  }

  guard let description = description else {
    throw CliError.missingRequired("DESCRIPTION")
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix = inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36 && inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.fileName.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks.filter { $0.fileName.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.fileName < $1.fileName }) {
        print("  \(t.fileName) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task = task else {
    throw CliError.taskNotFound
  }

  // Add new action
  let newAction = Action(description: description)
  task.plannedActions.append(newAction)
  task.updatedAt = Date()

  try taskManager.save(task)

  print("Added action #\(task.plannedActions.count) to \(task.fileName): \(description)")
}

func handleActionReplace(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var actionNumber: Int?
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
    } else if arg == "-i" || arg == "--index" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      guard let num = Int(args[i]), num > 0 else {
        throw CliError.invalidActionNumber(args[i])
      }
      actionNumber = num
    } else if arg.hasPrefix("-") {
      throw CliError.unknownOption(arg)
    } else {
      // Positional argument - description
      description = arg
      break
    }

    i += 1
  }

  guard let actionNumber = actionNumber else {
    throw CliError.missingRequired("-i/--index")
  }

  guard let description = description else {
    throw CliError.missingRequired("DESCRIPTION")
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix = inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36 && inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.fileName.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks.filter { $0.fileName.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.fileName < $1.fileName }) {
        print("  \(t.fileName) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task = task else {
    throw CliError.taskNotFound
  }

  // Convert 1-based action number to 0-based index
  let actionIndex = actionNumber - 1
  guard actionIndex >= 0 && actionIndex < task.plannedActions.count else {
    throw CliError.invalidActionIndex(actionNumber, task.plannedActions.count)
  }

  let oldDescription = task.plannedActions[actionIndex].description
  task.plannedActions[actionIndex].description = description
  task.updatedAt = Date()

  try taskManager.save(task)

  print("Replaced action #\(actionNumber) in \(task.fileName)")
  print("  Old: \(oldDescription)")
  print("  New: \(description)")
}

func handleActionDelete(args: [String], rootDirectory: URL) throws {
  var taskPrefix: String?
  var actionNumber: Int?
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
    } else if arg == "-i" || arg == "--index" {
      i += 1
      guard i < args.count else {
        throw CliError.missingValue(arg)
      }
      guard let num = Int(args[i]), num > 0 else {
        throw CliError.invalidActionNumber(args[i])
      }
      actionNumber = num
    } else if arg == "--force" {
      force = true
    } else {
      throw CliError.unknownOption(arg)
    }

    i += 1
  }

  guard let actionNumber = actionNumber else {
    throw CliError.missingRequired("-i/--index")
  }

  let inputPrefix = taskPrefix ?? commandTask
  guard let inputPrefix = inputPrefix else {
    throw CliError.missingRequired("-t/--task (or set via task stack)")
  }

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

  var task: Task?

  // If inputPrefix looks like a UUID, find by ID directly
  if inputPrefix.count == 36 && inputPrefix.contains("-") {
    // Likely a UUID string
    task = tasks.first { $0.id.uuidString == inputPrefix }
  } else {
    // Treat as file prefix
    let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix
    var matchingTasks = tasks.filter { $0.fileName.hasPrefix(prefix) }

    if matchingTasks.isEmpty {
      matchingTasks = tasks.filter { $0.fileName.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw CliError.taskNotFound
    }

    guard matchingTasks.count == 1 else {
      print("Error: Multiple tasks match prefix '\(prefix)':")
      for t in matchingTasks.sorted(by: { $0.fileName < $1.fileName }) {
        print("  \(t.fileName) - \(t.name)")
      }
      exit(1)
    }

    task = matchingTasks[0]
  }

  guard var task = task else {
    throw CliError.taskNotFound
  }

  // Convert 1-based action number to 0-based index
  let actionIndex = actionNumber - 1
  guard actionIndex >= 0 && actionIndex < task.plannedActions.count else {
    throw CliError.invalidActionIndex(actionNumber, task.plannedActions.count)
  }

  let actionDescription = task.plannedActions[actionIndex].description

  // Prompt for confirmation unless --force
  if !force {
    print("Delete action #\(actionNumber) from \(task.fileName): \(actionDescription)")
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

  print("Deleted action #\(actionNumber) from \(task.fileName): \(actionDescription)")
}

// MARK: - Error Types

enum CliError: LocalizedError {
  case missingValue(String)
  case unknownOption(String)
  case missingRequired(String)
  case unknownFormat(String)
  case invalidInteger(String)
  case invalidActionNumber(String)
  case noTasksFound
  case taskNotFound
  case unknownSubcommand(String)
  case invalidActionIndex(Int, Int)

  var errorDescription: String? {
    switch self {
    case .missingValue(let opt):
      return "Option '\(opt)' requires a value"
    case .unknownOption(let opt):
      return "Unknown option '\(opt)'"
    case .missingRequired(let opt):
      return "Required option '\(opt)' not provided"
    case .unknownFormat(let fmt):
      return "Unknown format '\(fmt)'. Valid formats: json, text"
    case .invalidInteger(let val):
      return "Invalid integer value '\(val)'"
    case .invalidActionNumber(let val):
      return "Invalid action number '\(val)'. Must be a positive integer (1-based)"
    case .noTasksFound:
      return "No tasks found"
    case .taskNotFound:
      return "Task not found"
    case .unknownSubcommand(let sub):
      return "Unknown action subcommand '\(sub)'. Valid subcommands: list, add, replace, delete"
    case .invalidActionIndex(let num, let count):
      return "Invalid action number #\(num). Valid range: 1-\(count)"
    }
  }
}

// MARK: - Helpers

func projectRoot() -> URL {
  let currentPath = FileManager.default.currentDirectoryPath
  return URL(fileURLWithPath: currentPath, isDirectory: true)
}

// MARK: - Usage

func printUsage() {
  let usage = """
  Usage: task [OPTIONS] <command> [ARGS]

  Options:
    -w, --world DIR     Project root directory (default: current directory)
    -v, --verbosity LVL Set verbosity level (0: terse, 1: normal, 2: verbose)

  Commands:
    list [-l|--limit MAXROWS]
                        List tasks (default limit: 20, 0 = unlimited)
    add -n NAME [-s TEXT]
                        Create new task with optional summary
    push [-t|--task PREFIX]
                        Push task to stack (default: most recent if empty, current if set)
    pop                 Pop task from stack
    show [-t|--task PREFIX] [-f|--format FORMAT]
                        Show task details (format: json, text; default: text)
    delete [-t|--task PREFIX] [--force]
                        Delete task (prompts for confirmation unless --force)
    action <subcommand> [OPTIONS] [DESCRIPTION]
                        Manage planned actions
      list [-t|--task PREFIX]
                        List actions for task
      add [-t|--task PREFIX] DESCRIPTION
                        Add action to task
      replace -i NUMBER [-t|--task PREFIX] DESCRIPTION
                        Replace action #NUMBER (1-based)
      delete -i NUMBER [-t|--task PREFIX] [--force]
                        Delete action #NUMBER (1-based)
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
    task action add -t T_AZ "First action"
    task action add "Another action"
    task action replace -i 1 "Updated action"
    task action delete -i 1
    task action delete -i 1 --force
  """
  print(usage)
}
