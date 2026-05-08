// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversoxMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ConversoxMac", targets: ["ConversoxMac"])
    ],
    targets: [
        .executableTarget(
            name: "ConversoxMac",
            path: "Sources/ConversoxMac"
        ),
        .testTarget(
            name: "ConversoxMacTests",
            dependencies: ["ConversoxMac"],
            path: "Tests/ConversoxMacTests"
        )
    ]
)
