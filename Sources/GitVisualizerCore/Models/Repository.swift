import Foundation

public struct Repository: Identifiable {
    public let id: String
    public let path: String
    public let name: String
    public var commits: [Commit]
    public var branches: [Branch]
    public var remotes: [Remote]
    public var currentBranch: Branch?

    public init(path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard url.lastPathComponent != ".git" else {
            throw RepositoryError.invalidPath
        }

        self.id = UUID().uuidString
        self.path = path
        self.name = url.lastPathComponent
        self.commits = []
        self.branches = []
        self.remotes = []

        try validate()
    }

    private func validate() throws {
        let gitDir = URL(fileURLWithPath: path).appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            throw RepositoryError.notARepository
        }
    }

    public mutating func addCommit(_ commit: Commit) {
        if !commits.contains(where: { $0.hash == commit.hash }) {
            commits.append(commit)
        }
    }

    public mutating func setBranches(_ branches: [Branch]) {
        self.branches = branches
        self.currentBranch = branches.first(where: { $0.isHead })
    }

    public func getCommit(hash: String) -> Commit? {
        commits.first(where: { $0.hash == hash })
    }

    public func getCommitPath(from: String, to: String) -> [Commit]? {
        guard let startCommit = getCommit(hash: from) else { return nil }
        var path: [Commit] = [startCommit]
        var current = startCommit

        while current.hash != to && !current.parentHashes.isEmpty {
            if let parent = getCommit(hash: current.parentHashes[0]) {
                path.append(parent)
                current = parent
            } else {
                return nil
            }
        }

        return current.hash == to ? path : nil
    }

    public enum RepositoryError: LocalizedError {
        case notARepository
        case invalidPath

        public var errorDescription: String? {
            switch self {
            case .notARepository:
                return "Directory is not a git repository"
            case .invalidPath:
                return "Invalid repository path"
            }
        }
    }
}

public struct Remote: Identifiable, Codable {
    public let id: String
    public let name: String
    public let url: String
    // Populated in two passes while parsing `git remote -v`, which lists the
    // fetch and push URLs on separate lines.
    public var fetchUrl: String
    public var pushUrl: String

    public init(name: String, url: String, fetchUrl: String? = nil, pushUrl: String? = nil) {
        self.id = name
        self.name = name
        self.url = url
        self.fetchUrl = fetchUrl ?? url
        self.pushUrl = pushUrl ?? url
    }
}
