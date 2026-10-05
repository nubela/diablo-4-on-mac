// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "D4Mac",
    platforms: [.macOS("14.0")],
    products: [
        .executable(name: "D4MacApp", targets: ["D4MacApp"]),
        .executable(name: "d4mac", targets: ["d4mac-cli"]),
    ],
    targets: [
        .target(name: "D4MacCore"),
        .executableTarget(name: "D4MacApp", dependencies: ["D4MacCore"]),
        .executableTarget(name: "d4mac-cli", dependencies: ["D4MacCore"]),
        .testTarget(name: "D4MacCoreTests", dependencies: ["D4MacCore"]),
    ],
    swiftLanguageModes: [.v5]
)
