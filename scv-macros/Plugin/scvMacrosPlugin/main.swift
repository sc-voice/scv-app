import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

/// Macro that expands CCOK1(level, messages...) to:
/// cc.ok1(path: #file, method: #function, line: #line, messages...)
public struct CCOK1Macro: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in _: some MacroExpansionContext,
  ) throws -> ExprSyntax {
    // Verify that at least the level argument is present
    guard node.arguments.count > 0 else {
      throw MacroError.missingArguments
    }

    // Get all arguments after the first one (the messages)
    let messageArguments = node.arguments.dropFirst()

    // Build the function call: cc.ok1(path: #file, method: #function, line:
    // #line, ...messages)
    var argumentList = "path: #file, method: #function, line: #line"

    // Add message arguments
    for arg in messageArguments {
      argumentList += ", "
      argumentList += arg.expression.description
        .trimmingCharacters(in: .whitespaces)
    }

    // Create the expanded expression
    let expansion = "cc.ok1(\(argumentList))"

    return ExprSyntax(stringLiteral: expansion)
  }
}

enum MacroError: Error {
  case missingArguments
}

@main
struct scvMacrosPluginMacros: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    CCOK1Macro.self,
  ]
}
