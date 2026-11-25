// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AlarmCore", platforms: [.macOS(.v13)], products: [.library(name: "AlarmCore", targets: ["AlarmCore"])], targets: [
    .target(name: "AlarmCore", path: "Shared", exclude: ["AlarmManager.swift", "ConnectivityManager.swift", "NotificationManager.swift"], sources: ["Alarm.swift", "AlarmRepository.swift"]),
    .testTarget(name: "AlarmCoreTests", dependencies: ["AlarmCore"], path: "Tests/AlarmCoreTests")
])
