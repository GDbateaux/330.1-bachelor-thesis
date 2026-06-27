import Foundation
import ArgumentParser


// Parts of this file were developed with the assistance of an LLM
@main
struct Carl: ParsableCommand {
    /// The input file passed to the command.
    @Argument(help: "Carl source file.")
    var sourceFile: String

    /// The output executable path.
    @Option(name: .shortAndLong, help: "Output executable path.")
    var output: String

    /// True if the cache directory should be deleted before building else false
    @Flag(help: "Clean the build cache and rebuild from scratch.")
    var clean: Bool = false

    /// Run the command.
    mutating func run() throws {
        let sourceCode: String = try getSourceCode(sourceFile: sourceFile)
        let compiler: Compiler = Compiler(source: sourceCode)

        let generatedCode: String = try compiler.compile()
        let buildDir: URL = carlBuildDirectory()

        do {
            // Generate folder structure
            if clean && FileManager.default.fileExists(atPath: buildDir.path) {
                try FileManager.default.removeItem(at: buildDir)
            }
            try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

            let sourcesDir: URL = buildDir.appendingPathComponent("Sources")
            let generatedDir: URL = sourcesDir.appendingPathComponent("Generated")
            try FileManager.default.createDirectory(at: generatedDir, withIntermediateDirectories: true)

            let mainSwift: URL = generatedDir.appendingPathComponent("main.swift")
            try generatedCode.write(to: mainSwift, atomically: true, encoding: .utf8)

            let cRaylibDir: URL = sourcesDir.appendingPathComponent("CRaylib")
            if !FileManager.default.fileExists(atPath: cRaylibDir.path) {
                try copyCRaylibSources(to: cRaylibDir)
            }

            let packageSwift: URL = buildDir.appendingPathComponent("Package.swift")
            if !FileManager.default.fileExists(atPath: packageSwift.path) {
                try generatePackageSwiftContents().write(to: packageSwift, atomically: true, encoding: .utf8)
            }

            // Find swift executable and build
            guard let swiftURL: URL = findSwiftExecutable() else {
                throw ValidationError("swift command not found in PATH. Install Swift: https://www.swift.org/install/")
            }
            try runSwiftBuild(swiftURL: swiftURL, packagePath: buildDir)

            // Copy the executable to the output
            let releaseDir: URL = buildDir.appendingPathComponent(".build").appendingPathComponent("release")
            let executableName: String = "Generated" + (isWindows() ? ".exe" : "")
            let builtExecutable: URL = releaseDir.appendingPathComponent(executableName)

            let outputURL: URL = URL(fileURLWithPath: output)
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.copyItem(at: builtExecutable, to: outputURL)

            print("Executable generated at: \(outputURL.path)")
        }
        catch {
            print("Error: \(error.localizedDescription)")
            print("Build directory kept at: \(buildDir.path)")
            print("Use --clean to force a full rebuild.")
            throw error
        }
    }

    /// Get the Carl build directory
    /// 
    /// - Returns: The URL of the Carl build directory
    private func carlBuildDirectory() -> URL {
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".carl").appendingPathComponent( "build")
    }

    /// Find the swift executable and return the URL
    /// 
    /// - Returns: The URL of the swift executable if exists else nil
    private func findSwiftExecutable() -> URL? {
        let candidates: [String] = isWindows() ? ["swift.exe", "swift"] : ["swift"]
        for name: String in candidates {
            if let url: URL = findInPATH(name) {
                return url
            }
        }
        return nil
    }

    /// Searches for an executable in each directory listed in the PATH
    ///
    /// - Parameter name: The executable name to search for
    /// - Returns: The full URL of the executable if found, or nil
    private func findInPATH(_ name: String) -> URL? {
        let environmentVariables: [String: String] = ProcessInfo.processInfo.environment
        let PATH: String = environmentVariables.first(where: { $0.key.lowercased() == "path" })?.value ?? ""
        let separator: Character = isWindows() ? ";" : ":"

        for dir: String.SubSequence in PATH.split(separator: separator) {
            let dir: String = dir.trimmingCharacters(in: CharacterSet.whitespaces)
            if dir.isEmpty { 
                continue
            }

            let url: URL = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// - Returns: true if the os is Windows else false
    private func isWindows() -> Bool {
        #if os(Windows)
            return true
        #else
            return false
        #endif
    }

    /// Copy the CRaylib files to the destination URL
    /// 
    /// - Parameter destination: The URL where the CRaylib is copied
    private func copyCRaylibSources(to destination: URL) throws {
        let carlSwiftURL: URL = URL(fileURLWithPath: #filePath)
        let projectSources: URL = carlSwiftURL.deletingLastPathComponent().deletingLastPathComponent()
        let cRaylibSource: URL = projectSources.appendingPathComponent("CRaylib")

        guard FileManager.default.fileExists(atPath: cRaylibSource.path) else {
            throw ValidationError("CRaylib sources not found at \(cRaylibSource.path).")
        }

        try FileManager.default.copyItem(at: cRaylibSource, to: destination)
    }

    /// Generate the package.swift contents
    /// 
    /// - Returns: The generated code
    private func generatePackageSwiftContents() -> String {
        return """
        // swift-tools-version: 6.3
        import PackageDescription

        let package = Package(
            name: "GeneratedAutomaton",
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
                        "raygui.c",
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
                    name: "Generated",
                    dependencies: ["CRaylib"]
                ),
            ],
            swiftLanguageModes: [.v6]
        )
        """
    }

    /// Builds the generated Swift package in release mode
    ///
    /// - Parameters:
    ///   - swiftURL: The URL to the swift executable.
    ///   - packagePath: The directory containing the Package.swift to build.
    private func runSwiftBuild(swiftURL: URL, packagePath: URL) throws {
        let process: Process = Process()
        process.executableURL = swiftURL
        process.currentDirectoryURL = packagePath
        process.arguments = ["build", "-c", "release"]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ValidationError("Swift build failed with exit code \(process.terminationStatus).")
        }
    }

    /// Get the source code of the carl file from the sourceFile.
    /// 
    /// - Parameter sourceFile: The source file string to be read
    /// - Returns: The source code of the file
    private func getSourceCode(sourceFile: String) throws -> String {
        let sourceURL: URL = URL(fileURLWithPath: sourceFile)
        guard sourceURL.pathExtension == "carl" else {
            throw ValidationError("Source file must have a .carl extension: \(sourceURL.path)")
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ValidationError("Source file not found: \(sourceURL.path)")
        }
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
