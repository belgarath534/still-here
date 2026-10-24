// swift-tools-version:5.9
// Builds the game's core (story, timers, sound logic) without the iPhone parts,
// so it can be compiled and play-tested on any machine, including Linux.
import PackageDescription

let package = Package(
    name: "StillHereCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(name: "StillHereCore", path: "StillHere/Core"),
        .executableTarget(name: "StillHereSim", dependencies: ["StillHereCore"], path: "Tests/StillHereSim",
                          resources: [.copy("durations.json")]),
    ]
)
