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
        .library(name: "HabitCore", targets: ["HabitCore"])
    ],
    targets: [
        .target(
            name: "HabitCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HabitCoreTests",
            dependencies: ["HabitCore"]
        )
    ]
)
