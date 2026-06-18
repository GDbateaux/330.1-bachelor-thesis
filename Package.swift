// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Carl",
    products: [
        .library(name: "CRaylib", targets: ["CRaylib"]),
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
                .linkedLibrary("winmm"),
                .linkedLibrary("gdi32"),
                .linkedLibrary("opengl32"),
            ]
        ),
        .executableTarget(
            name: "Carl",
            dependencies: ["CRaylib"]
        ),
        .executableTarget(
            name: "Display",
            dependencies: ["CRaylib"]
        ),
        .testTarget(
            name: "CarlTests",
            dependencies: ["Carl"],
            exclude: ["CompilerTests/negative", "CompilerTests/positive"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
