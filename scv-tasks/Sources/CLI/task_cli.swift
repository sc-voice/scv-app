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
  case "new":
    try handleNew(args: commandArgs, rootDirectory: rootDirectory)
  case "push":
    try handlePush(args: commandArgs, rootDirectory: rootDirectory)
  case "show":
    try handleShow(args: commandArgs, rootDirectory: rootDirectory)
  case "delete":
    try handleDelete(args: commandArgs, rootDirectory: rootDirectory)
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
    } catch {
      let cc = ColorConsole(#file, #function, DBG_TASK)
      cc.bad1(#line, "cannot load \(worldPath)")
      throw error
    }
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

func handleNew(args: [String], rootDirectory: URL) throws {
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
        print("  [\(index)] \(action.description)")
      }
    }
    if !task.completedActions.isEmpty {
      print("\nCompleted Actions:")
      for (index, action) in task.completedActions.enumerated() {
        print("  [\(index)] \(action.description)")
      }
    }
    if !task.references.isEmpty {
      print("\nReferences:")
      for ref in task.references {
        switch ref {
        case .filePath(let path):
          print("  - \(path)")
        case .text(let text):
          print("  - \(text)")
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

// MARK: - Error Types

enum CliError: LocalizedError {
  case missingValue(String)
  case unknownOption(String)
  case missingRequired(String)
  case unknownFormat(String)
  case invalidInteger(String)
  case noTasksFound
  case taskNotFound

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
    case .noTasksFound:
      return "No tasks found"
    case .taskNotFound:
      return "Task not found"
    }
  }
}

// MARK: - Usage

func printUsage() {
  let usage = """
  Usage: task [OPTIONS] <command> [ARGS]

  Options:
    -w, --world DIR     Project root directory (default: current directory)

  Commands:
    list [-l|--limit MAXROWS]
                        List tasks (default limit: 20, 0 = unlimited)
    new -n NAME [-s TEXT]
                        Create new task with optional summary
    push [-t|--task PREFIX]
                        Push task to stack (default: most recent if empty, current if set)
    show [-t|--task PREFIX] [-f|--format FORMAT]
                        Show task details (format: json, text; default: text)
    delete [-t|--task PREFIX] [--force]
                        Delete task (prompts for confirmation unless --force)
    help                Show this help message

  Examples:
    task list
    task -w ~/dev/scv-app list
    task new -n "My Task"
    task show -t T_AZ
    task show -t T_AZ -f json
    task delete -t T_AZvt
    task delete -t T_AZvt --force
  """
  print(usage)
}
