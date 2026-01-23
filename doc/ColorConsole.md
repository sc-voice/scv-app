# ColorConsole API Documentation

ColorConsole outputs colored diagnostic messages to Xcode console using ANSI escape codes with context-aware verbosity control.

See: scv-core/Sources/ColorConsole.swift

## Initialization

```swift
let cc = ColorConsole(#file, #function, dbg.MyModule.other)
```

Parameters: file path, method name, verbosity level (0=silent, 1=minimal, 2=verbose).

## Module Verbosity Constants

Module verbosity levels defined in `scv-core/Sources/Debug.swift`:

```swift
public struct dbg: Sendable {
  public struct MyModule: Sendable {
    public static let other: Int = 1
  }
}
```

To add new module: add nested struct to `dbg` with name matching module, define `public static let other: Int = <0|1|2>`, use in ColorConsole init.

Example: AudioStore added in Phase 3 with verbosity=2.

## Output Methods

All return `String?` (use `@discardableResult` to suppress warnings).

| Method | Threshold | Icon | Purpose |
|--------|-----------|------|---------|
| `ok1(#line, #function, ...)` | >= 1 | ✅ | Success summary, once before method exit |
| `bad1(#line, #function, ...)` | >= 1 | ❌ | Error summary, before throw/failure |
| `ok2(#line, #function, ...)` | >= 2 | ↓🍀 | Intermediate success, tracing |
| `bad2(#line, #function, ...)` | >= 2 | ↓🌶️ | Non-fatal errors, diagnostics |

## Verbosity Levels

- **0 - Silent:** No output
- **1 - Minimal (default):** Only ok1/bad1
- **2 - Verbose:** All methods output

## Best Practices

1. Always pass `#line` and `#function` as first two arguments
2. Don't use conditionals — ColorConsole checks verbosity: just call `cc.ok2(...)`
3. Use ok1/bad1 for summaries, ok2/bad2 for diagnostics only
4. Keep messages concise: `cc.ok1(#line, #function, "Loaded", count, "items")`
5. Pass error objects directly to bad1/bad2 — they're self-descriptive

## Example

```swift
func loadConfiguration(from path: String) throws -> Config {
  let cc = ColorConsole(#file, #function, dbg.ConfigManager.other)

  cc.ok2(#line, #function, "Loading from:", path)

  guard FileManager.default.fileExists(atPath: path) else {
    cc.bad1(#line, #function, path)
    throw ConfigError.missingFile(path)
  }

  guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
    cc.bad1(#line, #function, path)
    throw ConfigError.readFailed(path)
  }

  do {
    let config = try JSONDecoder().decode(Config.self, from: data)
    cc.ok1(#line, #function, "Loaded config:", config.name)
    return config
  } catch {
    cc.bad1(#line, #function, error)
    throw ConfigError.invalidFormat(error)
  }
}
```

## Output Format

All output: emoji + `filename:method:` + `elapsed` + message

Example: `✅AudioStore:storeAudio:1234.567s+0.002 Cached 87KB`

## Thread Safety

ColorConsole is `Sendable` and thread-safe via `NSLock`. Safe from any thread.

## Limitations

1. ANSI codes may not render in all console environments
2. No per-module filtering (global verbosity affects all modules)

