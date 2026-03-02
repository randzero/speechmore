// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeechMore",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SpeechMore",
            path: "Sources/SpeechMore"
        )
    ]
)
