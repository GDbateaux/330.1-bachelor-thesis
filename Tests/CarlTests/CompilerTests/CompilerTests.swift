import Testing
import Foundation
@testable import Carl

struct CompilerTestsRunner {
    enum FolderType: String {
        case positive = "positive"
        case negative = "negative"
    }

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

    @Test(arguments: try listCarlFiles(folderType: FolderType.negative))
    func testNegatives(carlUrl: URL) throws {
        let fileManager: FileManager = FileManager.default
        let expectedUrl: URL = carlUrl.deletingPathExtension().appendingPathExtension("expected")

        let fileName: String = carlUrl.deletingPathExtension().lastPathComponent

        if fileManager.fileExists(atPath: expectedUrl.path) {
            let sourceCode: String = try String(contentsOf: carlUrl, encoding: .utf8)
            let expectedOutput: String = try String(contentsOf: expectedUrl, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

            let compiler: Compiler = Compiler(source: sourceCode)
            let observedOutput: String = compiler.compileAndCaptureError()
            #expect(observedOutput == expectedOutput, "Failed \(fileName) test")
        }
    }

    @Test(arguments: try listCarlFiles(folderType: FolderType.positive))
    func testPositives(carlUrl: URL) throws {
        let fileName: String = carlUrl.deletingPathExtension().lastPathComponent

        let sourceCode: String = try String(contentsOf: carlUrl, encoding: .utf8)
        let compiler: Compiler = Compiler(source: sourceCode)
        let observedOutput: String = compiler.compileAndCaptureError()
        #expect(observedOutput == "", "Failed \(fileName) test")
    }
}
