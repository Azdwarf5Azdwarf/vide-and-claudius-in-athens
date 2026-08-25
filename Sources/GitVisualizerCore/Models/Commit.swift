import Foundation

public struct FileChange: Identifiable, Codable {
    public let id: String
    public let path: String
    public let status: FileStatus
    public let insertions: Int
    public let deletions: Int

    public enum FileStatus: String, Codable {
        case added = "A"
        case modified = "M"
        case deleted = "D"
        case renamed = "R"
        case typeChanged = "T"
    }

    public init(path: String, status: FileStatus, insertions: Int = 0, deletions: Int = 0) {
        self.id = UUID().uuidString
        self.path = path
        self.status = status
        self.insertions = insertions
        self.deletions = deletions
    }
}

public struct Commit: Identifiable, Codable {
    public let id: String
    public let hash: String
    public let shortHash: String
    public let author: String
    public let authorEmail: String
    public let timestamp: Date
    public let message: String
    public let summary: String
    public let fileChanges: [FileChange]
    public let parentHashes: [String]
    public var analysis: CommitAnalysis?

    public init(
        hash: String,
        author: String,
        authorEmail: String,
        timestamp: Date,
        message: String,
        fileChanges: [FileChange] = [],
        parentHashes: [String] = []
    ) {
        self.id = hash
        self.hash = hash
        self.shortHash = String(hash.prefix(7))
        self.author = author
        self.authorEmail = authorEmail
        self.timestamp = timestamp
        self.message = message

        let lines = message.split(separator: "\n", maxSplits: 1)
        self.summary = String(lines.first ?? "")

        self.fileChanges = fileChanges
        self.parentHashes = parentHashes
    }

    public var totalChanges: Int {
        fileChanges.count
    }

    public var linesAdded: Int {
        fileChanges.reduce(0) { $0 + $1.insertions }
    }

    public var linesDeleted: Int {
        fileChanges.reduce(0) { $0 + $1.deletions }
    }
}

public struct CommitAnalysis: Codable {
    public let intent: CommitIntent
    public let sentiment: Double
    public let collaborators: [String]
    public let tags: [String]

    public enum CommitIntent: String, Codable {
        case feature
        case bugfix
        case refactor
        case docs
        case ci
        case chore
        case test
        case unknown
    }

    public init(intent: CommitIntent = .unknown, sentiment: Double = 0.0, collaborators: [String] = [], tags: [String] = []) {
        self.intent = intent
        self.sentiment = sentiment
        self.collaborators = collaborators
        self.tags = tags
    }
}
