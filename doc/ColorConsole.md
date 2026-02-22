# ColorConsole API Documentation

ColorConsole logs path tracing messages to Xcode console 
using green for normal execution paths and 
red for abnormal execution paths.
Logging is enabled at different verbosity levels for individual modules.

See: scv-core/Sources/ColorConsole.swift

## Initialization

```swift
let cc = ColorConsole(#file, #function, dbg.MyModule.other)
```

Parameters: file path, method name, verbosity level (0=silent, 1=minimal, 2=verbose).

## Module Verbosity Constants

All module verbosity levels are defined in `scv-core/Sources/Debug.swift`,
which makes it easy to specify verbosity levels across modules:

```swift
public struct dbg: Sendable {
  public struct MyModule: Sendable {
    public static let other: Int = max(1, MODULE_GROUP_VERBOSITY)
  }
}
```

To add new module: add nested struct to `dbg` with name matching module, define `public static let other: Int = <0|1|2>`, use in ColorConsole init.

## Best Practices

1. Always pass `#line` and `#function` as first two arguments
2. Omit labels when values are obvious: `cc.ok1(#line, #function, filepath)`
2. Prefer one-word labels: `cc.ok1(#line, #function, count, "segments")`
3. Pass error objects directly to bad1/bad2 — they're self-descriptive

## Example

```swift
class ConfigManager {
  let cc = ColorConsole(#file, #function, dbg.ConfigManager.other)

  func loadConfiguration(from path: String) throws -> Config {
    cc.ok2(#line, #function, path)
    ...
    do {
      let config = try JSONDecoder().decode(Config.self, from: data)
      cc.ok1(#line, #function, "Loaded config:", config.name)
      return config
    } catch {
      cc.bad1(#line, #function, error)
      throw ConfigError.invalidFormat(error)
    }
  }
}
```

## Thread Safety

ColorConsole is `Sendable` and thread-safe for concurrent logging from multiple threads.

