import XCTest
@testable import GitVisualizerCore

final class CommitAnalyzerTests: XCTestCase {
    var analyzer: CommitAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = CommitAnalyzer()
    }

    func testIntentClassification() {
        let commits = [
            Commit(
                hash: "abc123",
                author: "Alice",
                authorEmail: "alice@example.com",
                timestamp: Date(),
                message: "feat: Add new dashboard feature"
            ),
            Commit(
                hash: "def456",
                author: "Bob",
                authorEmail: "bob@example.com",
                timestamp: Date(),
                message: "fix: Resolve login bug in auth module"
            ),
            Commit(
                hash: "ghi789",
                author: "Charlie",
                authorEmail: "charlie@example.com",
                timestamp: Date(),
                message: "refactor: Simplify user model"
            )
        ]

        let intentClassifier = IntentClassifier()
        XCTAssertEqual(intentClassifier.classify(commits[0].message), .feature)
        XCTAssertEqual(intentClassifier.classify(commits[1].message), .bugfix)
        XCTAssertEqual(intentClassifier.classify(commits[2].message), .refactor)
    }

    func testRepositoryAnalysis() {
        let commits = [
            Commit(
                hash: "abc123",
                author: "Alice",
                authorEmail: "alice@example.com",
                timestamp: Date(),
                message: "feat: Add feature A"
            ),
            Commit(
                hash: "def456",
                author: "Bob",
                authorEmail: "bob@example.com",
                timestamp: Date(),
                message: "fix: Fix bug in B"
            ),
            Commit(
                hash: "ghi789",
                author: "Alice",
                authorEmail: "alice@example.com",
                timestamp: Date(),
                message: "docs: Update README"
            )
        ]

        let analysis = analyzer.analyzeRepository(commits)

        XCTAssertEqual(analysis.totalCommits, 3)
        XCTAssertEqual(analysis.contributors.count, 2)
        XCTAssert(analysis.contributors.contains("Alice"))
        XCTAssert(analysis.contributors.contains("Bob"))
    }

    func testFileHealthTracking() {
        let fileChanges = [
            FileChange(path: "src/api.swift", status: .modified, insertions: 10, deletions: 5),
            FileChange(path: "src/models.swift", status: .modified, insertions: 3, deletions: 1)
        ]

        let commit = Commit(
            hash: "abc123",
            author: "Alice",
            authorEmail: "alice@example.com",
            timestamp: Date(),
            message: "feat: Update API",
            fileChanges: fileChanges
        )

        XCTAssertEqual(commit.linesAdded, 13)
        XCTAssertEqual(commit.linesDeleted, 6)
        XCTAssertEqual(commit.totalChanges, 2)
    }
}
