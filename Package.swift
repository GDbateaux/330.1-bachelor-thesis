// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Carl",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "Carl",
            dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")]
        ),
        .testTarget(
            name: "CarlTests",
            dependencies: ["Carl"],
            exclude: ["CompilerTests/negative", "CompilerTests/positive"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
