import Foundation
import ArgumentParser
import GitVisualizerCore

@main
struct GitVisualizer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A lightweight git visualizer for macOS",
        subcommands: [Analyze.self, Status.self, Health.self]
    )
}

struct Analyze: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze a git repository"
    )

    @Argument(help: "Path to the git repository")
    var path: String

    @Option(name: .shortAndLong, help: "Number of commits to analyze")
    var limit: Int = 100

    mutating func run() async throws {
        let repo = try Repository(path: path)
        print("Repository: \(repo.name)")
        print("Path: \(repo.path)")

        let manager = GitRepositoryManager(repositoryPath: path)
        let commits = try manager.fetchCommits(limit: limit)
        let branches = try manager.fetchBranches()

        print("Commits: \(commits.count)")
        print("Branches: \(branches.count)")

        let analyzer = CommitAnalyzer()
        let analysis = analyzer.analyzeRepository(commits)

        print("\nRepository Analysis:")
        print("- Total commits: \(analysis.totalCommits)")
        print("- Contributors: \(analysis.contributors.count)")
        print("- Volatile files: \(analysis.volatileFiles.prefix(5).joined(separator: ", "))")

        let fileHealthTracker = FileHealthTracker()
        let metrics = fileHealthTracker.getFileHealthMetrics(commits)
        print("\nTop Volatile Files:")
        for metric in metrics.prefix(5) {
            print("  \(metric.path): \(metric.changeCount) changes")
        }
    }
}

struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show repository status"
    )

    @Argument(help: "Path to the git repository")
    var path: String

    mutating func run() async throws {
        let repo = try Repository(path: path)
        let manager = GitRepositoryManager(repositoryPath: path)
        let branches = try manager.fetchBranches()
        let remotes = try manager.fetchRemotes()

        print("Repository: \(repo.name)")
        if let current = branches.first(where: { $0.isHead }) {
            print("Current branch: \(current.name)")
            if let tracking = current.trackingStatus {
                print("Tracking status: \(tracking)")
            }
        }

        print("\nBranches (\(branches.count)):")
        for branch in branches.prefix(10) {
            print("  \(branch.displayName)")
        }

        print("\nRemotes (\(remotes.count)):")
        for remote in remotes {
            print("  \(remote.name): \(remote.url)")
        }
    }
}

struct Health: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze repository health"
    )

    @Argument(help: "Path to the git repository")
    var path: String

    mutating func run() async throws {
        let repo = try Repository(path: path)
        let manager = GitRepositoryManager(repositoryPath: path)
        let commits = try manager.fetchCommits(limit: 50)

        let analyzer = CommitAnalyzer()
        let analysis = analyzer.analyzeRepository(commits)

        print("Repository Health Report: \(repo.name)")
        print(String(repeating: "=", count: 40))

        print("\nCommit Distribution by Intent:")
        for (intent, count) in analysis.intents.sorted(by: { $0.value > $1.value }) {
            print("  \(intent.rawValue): \(count)")
        }

        print("\nTop Contributors:")
        for contributor in analysis.contributors.prefix(5) {
            let commits = analysis.totalCommits
            let userCommits = commits / max(analysis.contributors.count, 1)
            print("  \(contributor): ~\(userCommits) commits")
        }

        print("\nActivity Trends:")
        print("  Commits per week: \(String(format: "%.1f", analysis.trends.commitsPerWeek))")
        print("  Average commit size: \(analysis.trends.averageCommitSize) files")
    }
}
