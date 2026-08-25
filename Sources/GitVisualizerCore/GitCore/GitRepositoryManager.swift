import Foundation

public class GitRepositoryManager {
    private let runner: GitCommandRunner
    private let repositoryPath: String

    public init(repositoryPath: String) {
        self.runner = GitCommandRunner(repositoryPath: repositoryPath)
        self.repositoryPath = repositoryPath
    }

    /// ASCII record separator. Starts each commit; cannot occur in commit text.
    static let recordSeparator = "\u{1e}"
    /// ASCII unit separator, between fields within one commit.
    static let fieldSeparator = "\u{1f}"

    /// Field order inside one record. `%P` is included so parents come from the
    /// same `git log` call rather than a `rev-parse` per commit.
    static let logFormat = [
        "%x1e%H", "%an", "%ae", "%aI", "%P", "%s", "%b%x1f"
    ].joined(separator: "%x1f")

    public func fetchCommits(limit: Int = 100) throws -> [Commit] {
        let output = try runner.runCommand("git", arguments: [
            "log",
            "-\(limit)",
            "--pretty=format:\(GitRepositoryManager.logFormat)",
            "--name-status",
            "-M"
        ])

        return GitRepositoryManager.parseCommits(output)
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

    /// Splits `git log` output into commits.
    ///
    /// Records are delimited by ASCII RS/US rather than a text sentinel, so a
    /// commit message can contain blank lines, tabs, or any word without
    /// confusing the parser. Pure and static so it can be tested against
    /// captured fixture output with no repository present.
    static func parseCommits(_ output: String) -> [Commit] {
        output
            .components(separatedBy: recordSeparator)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .compactMap(parseRecord)
    }

    /// One record: seven `%`-fields, then the `--name-status` block that
    /// `git log` prints after the formatted portion.
    static func parseRecord(_ record: String) -> Commit? {
        let fields = record.components(separatedBy: fieldSeparator)
        guard fields.count >= 7 else { return nil }

        let hash = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hash.isEmpty else { return nil }

        let parents = fields[4]
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        let subject = fields[5]
        let body = fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
        let message = body.isEmpty ? subject : "\(subject)\n\n\(body)"

        let fileChanges = fields.count > 7 ? parseFileChanges(fields[7]) : []

        return Commit(
            hash: hash,
            author: fields[1],
            authorEmail: fields[2],
            timestamp: parseISO8601Date(fields[3]) ?? Date(),
            message: message,
            fileChanges: fileChanges,
            parentHashes: parents
        )
    }

    static func parseFileChanges(_ block: String) -> [FileChange] {
        block.split(separator: "\n").compactMap { line in
            let columns = line.split(separator: "\t").map(String.init)
            // "M\tpath", or "R100\told\tnew" once -M detects a rename.
            guard columns.count >= 2,
                  let status = parseFileStatus(columns[0]),
                  let path = columns.last,
                  !path.isEmpty
            else { return nil }
            return FileChange(path: path, status: status)
        }
    }

    static func parseFileStatus(_ statusChar: String) -> FileChange.FileStatus? {
        switch statusChar.first {
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case "T": return .typeChanged
        default: return nil
        }
    }

    static func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }
}
