import Foundation

public class GitCommandRunner {
    private let repositoryPath: String

    public init(repositoryPath: String) {
        self.repositoryPath = repositoryPath
    }

    public func runCommand(_ command: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GitError.commandFailed(errorMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public enum GitError: LocalizedError {
        case commandFailed(String)

        public var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                return "Git command failed: \(message)"
            }
        }
    }
}
