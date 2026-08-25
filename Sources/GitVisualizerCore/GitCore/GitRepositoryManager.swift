import Foundation

public class GitRepositoryManager {
    private let runner: GitCommandRunner
    private let repositoryPath: String

    public init(repositoryPath: String) {
        self.runner = GitCommandRunner(repositoryPath: repositoryPath)
        self.repositoryPath = repositoryPath
    }

    public func fetchCommits(limit: Int = 100) throws -> [Commit] {
        let format = "%H%n%an%n%ae%n%aI%n%s%n%b%n--COMMIT_END--"
        let output = try runner.runCommand("git", arguments: [
            "log",
            "-\(limit)",
            "--pretty=format:\(format)",
            "--name-status",
            "-M"
        ])

        return parseCommits(output)
    }

    public func fetchBranches() throws -> [Branch] {
        let headOutput = try runner.runCommand("git", arguments: ["rev-parse", "--abbrev-ref", "HEAD"])
        let currentBranch = headOutput

        let localOutput = try runner.runCommand("git", arguments: [
            "for-each-ref",
            "--format=%(refname:short)%09%(objectname:short)",
            "refs/heads/"
        ])

        var branches: [Branch] = []
        for line in localOutput.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let name = parts[0]
            let tipHash = parts[1]
            let isHead = name == currentBranch

            branches.append(Branch(
                name: name,
                tipHash: tipHash,
                isLocal: true,
                isHead: isHead
            ))
        }

        return branches.sorted { $0.isHead ? true : $1.isHead ? false : $0.name < $1.name }
    }

    public func fetchRemotes() throws -> [Remote] {
        let output = try runner.runCommand("git", arguments: ["remote", "-v"])

        var remotes: [String: Remote] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let name = parts[0]
            let urlAndType = parts[1].split(separator: " ", maxSplits: 1).map(String.init)
            guard urlAndType.count == 2 else { continue }

            let url = urlAndType[0]
            let type = urlAndType[1]

            if remotes[name] == nil {
                remotes[name] = Remote(name: name, url: url)
            }

            if type == "(fetch)" {
                remotes[name]?.fetchUrl = url
            } else if type == "(push)" {
                remotes[name]?.pushUrl = url
            }
        }

        return Array(remotes.values)
    }

    public func getDiff(commit: String) throws -> String {
        try runner.runCommand("git", arguments: ["show", commit])
    }

    private func parseCommits(_ output: String) -> [Commit] {
        var commits: [Commit] = []
        var currentCommitLines: [String] = []
        var fileChanges: [FileChange] = []
        var isParsingFiles = false

        for line in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line == "--COMMIT_END--" {
                if currentCommitLines.count >= 5 {
                    if let commit = parseCommit(lines: currentCommitLines, fileChanges: fileChanges) {
                        commits.append(commit)
                    }
                }
                currentCommitLines = []
                fileChanges = []
                isParsingFiles = false
            } else if line.isEmpty {
                isParsingFiles = true
            } else if isParsingFiles && !line.contains("\t") && !currentCommitLines.isEmpty {
                if let fileChange = parseFileChange(line) {
                    fileChanges.append(fileChange)
                }
            } else if !isParsingFiles {
                currentCommitLines.append(line)
            }
        }

        return commits
    }

    private func parseCommit(lines: [String], fileChanges: [FileChange]) -> Commit? {
        guard lines.count >= 5 else { return nil }

        let hash = lines[0]
        let author = lines[1]
        let authorEmail = lines[2]
        let timestamp = parseISO8601Date(lines[3]) ?? Date()
        let message = lines[4...].joined(separator: "\n")

        let parents = parseParents(hash: hash)

        return Commit(
            hash: hash,
            author: author,
            authorEmail: authorEmail,
            timestamp: timestamp,
            message: message,
            fileChanges: fileChanges,
            parentHashes: parents
        )
    }

    private func parseParents(hash: String) -> [String] {
        do {
            let output = try runner.runCommand("git", arguments: ["rev-parse", "\(hash)^@"])
            return output.split(separator: "\n").map(String.init)
        } catch {
            return []
        }
    }

    private func parseFileChange(_ line: String) -> FileChange? {
        let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
        guard parts.count >= 2 else { return nil }

        let statusChar = parts[0]
        let path = parts[1]

        guard let status = parseFileStatus(statusChar) else { return nil }
        return FileChange(path: path, status: status)
    }

    private func parseFileStatus(_ statusChar: String) -> FileChange.FileStatus? {
        switch statusChar.first {
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case "T": return .typeChanged
        default: return nil
        }
    }

    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }
}
