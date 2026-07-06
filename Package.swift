// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Carl",
    products: [
        .library(name: "CRaylib", targets: ["CRaylib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
        .package(path: "tracy"),
    ],
    targets: [
        .target(
            name: "CRaylib",
            path: "Sources/CRaylib",
            sources: [
                "rcore.c",
                "rshapes.c",
                "rtextures.c",
                "rtext.c",
                "rmodels.c",
                "raygui.c"
            ],
            publicHeadersPath: ".",
            cSettings: [
                .define("PLATFORM_DESKTOP_RGFW"),
                .define("GRAPHICS_API_OPENGL_33"),
                .define("_CRT_SECURE_NO_WARNINGS"),
            ],
            linkerSettings: [
                .linkedLibrary("winmm", .when(platforms: [.windows])),
                .linkedLibrary("gdi32", .when(platforms: [.windows])),
                .linkedLibrary("opengl32", .when(platforms: [.windows])),

                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("OpenGL", .when(platforms: [.macOS])),
                .linkedFramework("IOKit", .when(platforms: [.macOS])),
                .linkedFramework("CoreVideo", .when(platforms: [.macOS])),

                .linkedLibrary("X11", .when(platforms: [.linux])),
                .linkedLibrary("Xrandr", .when(platforms: [.linux])),
                .linkedLibrary("Xcursor", .when(platforms: [.linux])),
                .linkedLibrary("Xi", .when(platforms: [.linux])),
                .linkedLibrary("Xinerama", .when(platforms: [.linux])),
                .linkedLibrary("GL", .when(platforms: [.linux])),
            ]
        ),
        .executableTarget(
            name: "Carl",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "CRaylib",
                .product(name: "TracyC", package: "tracy"),
            ]
        ),
        .testTarget(
            name: "CarlTests",
            dependencies: ["Carl"],
            exclude: ["CompilerTests/negative", "CompilerTests/positive"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
