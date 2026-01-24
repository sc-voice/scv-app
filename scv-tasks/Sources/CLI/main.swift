import Foundation
import UUIDV7
import scvTasks
import scvCore

// Parse command line arguments
var rootDirectory = projectRoot()
var commandIndex = 0
var args = Array(CommandLine.arguments.dropFirst())

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

// Get command
guard commandIndex < args.count else {
  printUsage()
  exit(1)
}

let command = args[commandIndex]
let commandArgs = Array(args.dropFirst(commandIndex + 1))

do {
  switch command {
  case "list":
    try handleList(rootDirectory: rootDirectory)
  case "new":
    try handleNew(args: commandArgs, rootDirectory: rootDirectory)
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

// MARK: - Command Handlers

func handleList(rootDirectory: URL) throws {
  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()
  let sortedTasks = tasks.sorted { $0.id > $1.id }

  for task in sortedTasks {
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

  guard let inputPrefix = taskPrefix else {
    throw CliError.missingRequired("-t/--task")
  }

  // Add T_ prefix if not present
  let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

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
    for task in matchingTasks.sorted(by: { $0.fileName < $1.fileName }) {
      print("  \(task.fileName) - \(task.name)")
    }
    exit(1)
  }

  let task = matchingTasks[0]

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

  guard let inputPrefix = taskPrefix else {
    throw CliError.missingRequired("-t/--task")
  }

  // Add T_ prefix if not present
  let prefix = inputPrefix.hasPrefix("T_") ? inputPrefix : "T_" + inputPrefix

  let taskManager = TaskManager(basePath: rootDirectory)
  let tasks = try taskManager.allTasks()

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
    for task in matchingTasks.sorted(by: { $0.fileName < $1.fileName }) {
      print("  \(task.fileName) - \(task.name)")
    }
    exit(1)
  }

  let task = matchingTasks[0]

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
    list                List all tasks
    new -n NAME [-s TEXT]
                        Create new task with optional summary
    show -t PREFIX [-f|--format FORMAT]
                        Show task details (format: json, text; default: text)
    delete -t PREFIX [--force]
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
