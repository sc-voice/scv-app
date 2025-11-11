#!/usr/bin/env swift

import Foundation

enum VersionBumpType: String {
    case major, minor, patch

    func bump(version: String) -> String {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false).map { String($0) }
        var major = Int(parts.first ?? "0") ?? 0
        var minor = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        var patch = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0

        switch self {
        case .major:
            major += 1
            minor = 0
            patch = 0
        case .minor:
            minor += 1
            patch = 0
        case .patch:
            patch += 1
        }

        return "\(major).\(minor).\(patch)"
    }
}

let pbxprojPath = FileManager.default.currentDirectoryPath + "/scv-demo-iOS/scv-demo-ios.xcodeproj/project.pbxproj"

guard FileManager.default.fileExists(atPath: pbxprojPath) else {
    print("Error: project.pbxproj not found at \(pbxprojPath)")
    exit(1)
}

// Parse arguments
let args = Array(CommandLine.arguments.dropFirst())
guard args.count > 0 else {
    print("Usage: version.swift [major|minor|patch]")
    exit(1)
}

guard let bumpType = VersionBumpType(rawValue: args[0]) else {
    print("Error: invalid version type '\(args[0])'. Use 'major', 'minor', or 'patch'")
    exit(1)
}

do {
    var content = try String(contentsOfFile: pbxprojPath, encoding: .utf8)

    // Pattern to match CURRENT_PROJECT_VERSION = N.M.P;
    let pattern = "CURRENT_PROJECT_VERSION = ([\\d.]+);"
    let regex = try NSRegularExpression(pattern: pattern, options: [])

    let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

    if matches.isEmpty {
        print("Warning: No CURRENT_PROJECT_VERSION found to update")
        exit(1)
    }

    // Process matches in reverse order to avoid index shifting
    var newVersion = "0.0.0"
    for match in matches.reversed() {
        if let versionRange = Range(match.range(at: 1), in: content) {
            let currentVersion = String(content[versionRange])
            newVersion = bumpType.bump(version: currentVersion)
            content.replaceSubrange(versionRange, with: newVersion)
        }
    }

    try content.write(toFile: pbxprojPath, atomically: true, encoding: .utf8)
    print("✓ Version bumped to \(newVersion)")

} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
