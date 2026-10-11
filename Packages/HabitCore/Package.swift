// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HabitCore",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15) // lets `swift test` run on the Mac
    ],
    products: [
        .library(name: "HabitCore", targets: ["HabitCore"]),
        .library(name: "FledgeUI", targets: ["FledgeUI"])
    ],
    targets: [
        .target(
            name: "HabitCore",
            resources: [.process("Resources")]
        ),
        .target(
            name: "FledgeUI",
            dependencies: ["HabitCore"]
        ),
        .testTarget(
            name: "HabitCoreTests",
            dependencies: ["HabitCore"]
        ),
        .testTarget(
            name: "FledgeUITests",
            dependencies: ["FledgeUI"]
        )
    ]
)
