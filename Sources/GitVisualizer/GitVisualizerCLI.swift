import Foundation
import ArgumentParser
import GitVisualizerCore

@main
struct GitVisualizerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "git-visualizer",
        abstract: "A lightweight git visualizer for macOS",
        subcommands: [Analyze.self, Status.self, Health.self, Entity.self]
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

        let fileHealthTracker = FileHealthTracker()
        let metrics = fileHealthTracker.getFileHealthMetrics(commits)
        if !metrics.isEmpty {
            print("\nTop Volatile Files:")
            for metric in metrics.prefix(5) {
                print("  \(metric.path): \(metric.changeCount) changes")
            }
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

        print("\nContributors:")
        for contributor in analysis.contributors.prefix(5) {
            let count = commits.filter { $0.author == contributor }.count
            print("  \(contributor): \(count) commits")
        }

        print("\nActivity Trends:")
        print("  Commits per week: \(String(format: "%.1f", analysis.trends.commitsPerWeek))")
        print("  Average commit size: \(analysis.trends.averageCommitSize) files")
    }
}

struct Entity: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Meet today's companion and see how it feels about your repo"
    )

    @Argument(help: "Path to the git repository")
    var path: String

    @Option(help: "Preview a different day, as yyyy-MM-dd")
    var day: String?

    mutating func run() async throws {
        let date = try resolveDate()
        let manager = GitRepositoryManager(repositoryPath: path)
        let commits = try manager.fetchCommits(limit: 200)

        let entity = DailyEntity.forDay(date, reactingTo: commits)
        let reaction = Reaction(commits: commits, now: date)

        print("")
        for line in entity.asciiSprite() {
            print("   \(line)")
        }
        print("")
        print("   \(entity.name) the \(entity.species.rawValue)")
        print("   \(entity.mood.caption)")
        print("")
        print("   day        \(entity.dayKey)")
        print("   accessory  \(entity.traits.accessory.rawValue)")
        print("   pattern    \(entity.traits.pattern.rawValue)")
        print("   energy     \(bar(entity.energy)) \(Int(entity.energy * 100))%")
        print("   commits    \(reaction.recentCommits.count) in the last 24h")
        print("")
    }

    private func resolveDate() throws -> Date {
        guard let day else { return Date() }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let parsed = formatter.date(from: day) else {
            throw ValidationError("Could not read '\(day)' as a yyyy-MM-dd date")
        }
        return parsed
    }

    private func bar(_ value: Double) -> String {
        let filled = Int((value * 10).rounded())
        return String(repeating: "#", count: filled) + String(repeating: ".", count: 10 - filled)
    }
}
