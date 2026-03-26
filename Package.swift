// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "StatBar",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "StatBar",
            targets: ["StatBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "StatBar",
            path: "Sources"
        )
    ]
)
