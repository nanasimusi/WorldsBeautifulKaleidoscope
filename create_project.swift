#!/usr/bin/env swift

import Foundation

// Create Xcode project using xcodeproj command line tool
let task = Process()
task.launchPath = "/usr/bin/xcrun"
task.arguments = [
    "xcodebuild", 
    "-project", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/Project Templates/iOS/Application/App.xctemplate",
    "-scheme", "KaleidoscopeApp"
]

do {
    try task.run()
    task.waitUntilExit()
} catch {
    print("Error creating project: \(error)")
}