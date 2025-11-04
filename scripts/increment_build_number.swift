#!/usr/bin/env swift

import Foundation

let pbxprojPath = FileManager.default.currentDirectoryPath + "/scv-demo-iOS/scv-demo-ios.xcodeproj/project.pbxproj"

guard FileManager.default.fileExists(atPath: pbxprojPath) else {
    print("Error: project.pbxproj not found at \(pbxprojPath)")
    exit(1)
}

do {
    var content = try String(contentsOfFile: pbxprojPath, encoding: .utf8)

    // Pattern to match CURRENT_PROJECT_VERSION = N;
    let pattern = "CURRENT_PROJECT_VERSION = (\\d+);"
    let regex = try NSRegularExpression(pattern: pattern, options: [])

    var newVersion = 0
    let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

    if matches.isEmpty {
        print("Warning: No CURRENT_PROJECT_VERSION found to increment")
        exit(1)
    }

    // Increment all occurrences
    var offset = 0
    for match in matches {
        if let versionRange = Range(match.range(at: 1), in: content) {
            if let currentVersion = Int(String(content[versionRange])) {
                newVersion = currentVersion + 1
                let newVersionStr = String(newVersion)
                content.replaceSubrange(versionRange, with: newVersionStr)
                offset += newVersionStr.count - (versionRange.upperBound.utf16Offset(in: content) - versionRange.lowerBound.utf16Offset(in: content))
            }
        }
    }

    try content.write(toFile: pbxprojPath, atomically: true, encoding: .utf8)
    print("✓ Build number incremented to \(newVersion)")

} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
