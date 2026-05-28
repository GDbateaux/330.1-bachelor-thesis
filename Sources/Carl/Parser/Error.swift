import Foundation

// # Adapted from Stack Overflow, response by @Martin R, accessed on 27.05.2026
// # URL: https://stackoverflow.com/questions/39176196/how-to-provide-a-localized-description-with-an-error-type-in-swift
/// An enumration of potential compilation errors.
enum CompilerError: Error, Equatable {
    case lexerError(message: String, line: Int)
    case parserError(message: String, token: Token)
    case semanticError(message: String)
}

/// An extension providing human-readable text descriptions for each compiler error.
extension CompilerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .lexerError(let message, let line):
                return "Lexer error on line \(line): \(message)"
            case .parserError(let message, _):
                return "Parser error: \(message)"
            case .semanticError(let message):
                return "Semantic error: \(message)"
        }
    }
}
