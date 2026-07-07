// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "tracy",
  products: [
    .library(name: "TracyC", targets: ["TracyC"]),
  ],
  targets: [
    .target(
      name: "TracyClient",
      path: "public",
      sources: ["TracyClient.cpp"],
      publicHeadersPath: ".",
      cxxSettings: [
        .define("TRACY_ENABLE", to: "1"),
        .headerSearchPath("."),
        .headerSearchPath("tracy"),
      ]
    ),
    .target(
      name: "TracyC",
      dependencies: ["TracyClient"],
      path: "swift/TracyC",
      sources: ["TracySwiftShim.c"],
      publicHeadersPath: "include",
      cSettings: [
        .define("TRACY_ENABLE", to: "1"),
      ],
      cxxSettings: [
        .define("TRACY_ENABLE", to: "1"),
        .headerSearchPath("../../public"),
        .headerSearchPath("../../public/tracy"),
      ]
    )
  ],
  cxxLanguageStandard: .cxx17
)
