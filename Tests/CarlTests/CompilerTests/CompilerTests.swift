import Testing
import Foundation
@testable import Carl

struct CompilerTestsRunner {
    /// Represents the target subdirectories containing the test scenarios.
    enum FolderType: String {
        case positive = "positive"
        case negative = "negative"
    }

    /// Scans the specified test directory and retrieves all files with a .carl extension.
    ///
    /// - Parameter folderType: The type of folder to scan.
    /// - Returns: An array of URLs containing the .carl files.
    static func listCarlFiles(folderType: FolderType) throws -> [URL] {
        let currentFileURL: URL = URL(fileURLWithPath: #filePath)
        let testFolder: URL = currentFileURL.deletingLastPathComponent().appendingPathComponent(folderType.rawValue)

        let fileManager: FileManager = FileManager.default
        let urls: [URL] = try fileManager.contentsOfDirectory(at: testFolder, includingPropertiesForKeys: nil)
        var carlUrls: [URL] = []

        for url: URL in urls {
            if url.pathExtension == "carl" {
                carlUrls.append(url)
            }
        }
        return carlUrls
    }

    /// Parameterized test that validates the compiler's behavior against invalid code inputs.
    ///
    /// - Parameter carlUrl: The URL of the .carl file being tested.
    @Test(arguments: try listCarlFiles(folderType: FolderType.negative))
    func testNegatives(carlUrl: URL) throws {
        let fileManager: FileManager = FileManager.default
        let expectedUrl: URL = carlUrl.deletingPathExtension().appendingPathExtension("expected")

        let fileName: String = carlUrl.deletingPathExtension().lastPathComponent

        if fileManager.fileExists(atPath: expectedUrl.path) {
            let sourceCode: String = try String(contentsOf: carlUrl, encoding: .utf8)
            let expectedOutput: String = try String(contentsOf: expectedUrl, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

            let compiler: Compiler = Compiler(source: sourceCode)

            let error = #expect(throws: CompilerError.self) {
                try compiler.compile()
            }
            #expect(error?.localizedDescription == expectedOutput, "Failed \(fileName) test")
        }
    }

    /// Parameterized test that validates the compiler's behavior against valid code inputs.
    ///
    /// - Parameter carlUrl: The URL of the .carl file being tested.
    @Test(arguments: try listCarlFiles(folderType: FolderType.positive))
    func testPositives(carlUrl: URL) throws {
        let fileName: String = carlUrl.deletingPathExtension().lastPathComponent

        let sourceCode: String = try String(contentsOf: carlUrl, encoding: .utf8)
        let compiler: Compiler = Compiler(source: sourceCode)
        #expect(throws: Never.self, "Failed \(fileName) test") {
            try compiler.compile()
        }
    }
}
