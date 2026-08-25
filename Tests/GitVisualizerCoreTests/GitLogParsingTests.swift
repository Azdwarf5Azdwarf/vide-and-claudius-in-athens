import XCTest
@testable import GitVisualizerCore

/// Parser tests built from real `git log` output captured with the format in
/// `GitRepositoryManager.logFormat`.
///
/// The previous parser passed every unit test in the suite while returning
/// garbage for real repositories — the tests all constructed `Commit` values by
/// hand and never fed raw output through the parser. These tests close that gap.
final class GitLogParsingTests: XCTestCase {

    private let RS = "\u{1e}"
    private let US = "\u{1f}"

    /// Builds a record the way `git log` lays one out: the formatted fields,
    /// then the `--name-status` block.
    private func record(
        hash: String,
        author: String = "Ada",
        email: String = "ada@example.com",
        date: String = "2026-08-25T09:52:23+00:00",
        parents: String = "aaa111",
        subject: String,
        body: String = "",
        files: String = ""
    ) -> String {
        RS + [hash, author, email, date, parents, subject, body].joined(separator: US)
            + US + files
    }

    // MARK: - The bugs that shipped

    func testFileChangesAttachToTheCommitTheyBelongTo() {
        let output = record(
            hash: "78bfd28",
            subject: "fix: add missing public initializers",
            files: "\nM\tSources/A.swift\nM\tSources/B.swift\nA\tSources/C.swift\n"
        )

        let commits = GitRepositoryManager.parseCommits(output)
        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits[0].fileChanges.count, 3)
        XCTAssertEqual(commits[0].fileChanges.map(\.path),
                       ["Sources/A.swift", "Sources/B.swift", "Sources/C.swift"])
        XCTAssertEqual(commits[0].fileChanges.map(\.status), [.modified, .modified, .added])
    }

    func testBlankLinesInABodyDoNotTruncateTheMessage() {
        // The old parser treated the first blank line as "files start here" and
        // dropped everything after it — including trailers.
        let body = """
        First paragraph explaining the change.

        Second paragraph after a blank line.

        Co-Authored-By: Someone <someone@example.com>
        """
        let output = record(hash: "abc1234", subject: "feat: a thing", body: body)

        let commits = GitRepositoryManager.parseCommits(output)
        XCTAssertEqual(commits.count, 1)
        XCTAssertTrue(commits[0].message.contains("Second paragraph"))
        XCTAssertTrue(commits[0].message.contains("Co-Authored-By"))
    }

    func testEveryCommitInAMultiCommitLogIsParsed() {
        let output = [
            record(hash: "aaa1111", subject: "feat: one", files: "\nM\ta.swift\n"),
            record(hash: "bbb2222", subject: "fix: two", files: "\nA\tb.swift\n"),
            record(hash: "ccc3333", subject: "docs: three", files: "\nD\tc.swift\n"),
        ].joined()

        let commits = GitRepositoryManager.parseCommits(output)
        XCTAssertEqual(commits.map(\.hash), ["aaa1111", "bbb2222", "ccc3333"])
        XCTAssertEqual(commits.map { $0.fileChanges.count }, [1, 1, 1])
    }

    func testAFileStatusLineIsNeverMistakenForACommitHash() {
        // The old parser produced a commit whose hash was literally "M\tREADME".
        let output = [
            record(hash: "aaa1111", subject: "feat: one", files: "\nM\tREADME\nM\tb.swift\n"),
            record(hash: "bbb2222", subject: "fix: two", files: "\nA\tc.swift\n"),
        ].joined()

        let commits = GitRepositoryManager.parseCommits(output)
        XCTAssertEqual(commits.count, 2)
        for commit in commits {
            XCTAssertFalse(commit.hash.contains("\t"), "hash absorbed a file line: \(commit.hash)")
            XCTAssertFalse(commit.hash.contains("README"))
        }
    }

    // MARK: - Field handling

    func testParentsComeFromTheLogRatherThanASeparateCall() {
        let merge = record(hash: "m111", parents: "p111 p222", subject: "Merge branch 'x'")
        XCTAssertEqual(GitRepositoryManager.parseCommits(merge).first?.parentHashes, ["p111", "p222"])
    }

    func testInitialCommitHasNoParents() {
        let initial = record(hash: "i111", parents: "", subject: "Initial commit", files: "\nA\tLICENSE\n")
        let commits = GitRepositoryManager.parseCommits(initial)
        XCTAssertEqual(commits.first?.parentHashes, [])
        XCTAssertEqual(commits.first?.fileChanges.count, 1)
    }

    func testRenameKeepsTheNewPath() {
        // -M emits "R100\told\tnew"; the destination is the useful one.
        let output = record(hash: "r111", subject: "refactor: move it",
                            files: "\nR100\tSources/Old.swift\tSources/New.swift\n")
        let change = GitRepositoryManager.parseCommits(output).first?.fileChanges.first
        XCTAssertEqual(change?.status, .renamed)
        XCTAssertEqual(change?.path, "Sources/New.swift")
    }

    func testSubjectBecomesTheSummary() {
        let output = record(hash: "s111", subject: "feat: the summary line", body: "Body text.")
        let commit = GitRepositoryManager.parseCommits(output).first
        XCTAssertEqual(commit?.summary, "feat: the summary line")
    }

    func testGitDateFormatParses() {
        // %aI has no fractional seconds, which the strict formatter rejects.
        XCTAssertNotNil(GitRepositoryManager.parseISO8601Date("2026-08-25T09:52:23+00:00"))
        XCTAssertNotNil(GitRepositoryManager.parseISO8601Date("2026-08-25T09:52:23Z"))
    }

    func testEmptyOutputYieldsNoCommits() {
        XCTAssertTrue(GitRepositoryManager.parseCommits("").isEmpty)
        XCTAssertTrue(GitRepositoryManager.parseCommits("\n").isEmpty)
    }

    func testMalformedRecordIsSkippedRatherThanCrashing() {
        let truncated = RS + ["abc", "Ada"].joined(separator: US)
        XCTAssertTrue(GitRepositoryManager.parseCommits(truncated).isEmpty)
    }

    // MARK: - End to end against this repository

    func testParsesRealOutputFromThisRepository() throws {
        // Skips anywhere the working copy is not a git checkout (e.g. a
        // source tarball); runs for real in CI.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // GitVisualizerCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
        guard FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(".git").path) else {
            throw XCTSkip("not a git checkout")
        }

        let commits = try GitRepositoryManager(repositoryPath: repoRoot.path).fetchCommits(limit: 5)
        XCTAssertFalse(commits.isEmpty, "parsed no commits from a real repository")

        for commit in commits {
            XCTAssertEqual(commit.hash.count, 40, "not a full hash: \(commit.hash)")
            XCTAssertFalse(commit.hash.contains("\t"))
            XCTAssertFalse(commit.author.isEmpty)
            XCTAssertFalse(commit.summary.isEmpty)
        }

        // At least one commit in recent history touched a file; the old parser
        // reported zero for every commit.
        XCTAssertTrue(commits.contains { !$0.fileChanges.isEmpty },
                      "every commit reported zero file changes")
    }
}
