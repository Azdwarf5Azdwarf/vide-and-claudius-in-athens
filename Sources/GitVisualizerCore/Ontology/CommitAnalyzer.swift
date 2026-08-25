import Foundation

public class CommitAnalyzer {
    private let intentClassifier: IntentClassifier
    private let collaborationGraph: CollaborationGraph
    private let fileHealthTracker: FileHealthTracker

    public init() {
        self.intentClassifier = IntentClassifier()
        self.collaborationGraph = CollaborationGraph()
        self.fileHealthTracker = FileHealthTracker()
    }

    public func analyzeCommit(_ commit: Commit, in repository: [Commit]) -> CommitAnalysis {
        let intent = intentClassifier.classify(commit.message)
        let sentiment = calculateSentiment(commit.message)
        let collaborators = collaborationGraph.findCollaborators(for: commit, in: repository)
        let tags = generateTags(for: commit)

        return CommitAnalysis(
            intent: intent,
            sentiment: sentiment,
            collaborators: collaborators,
            tags: tags
        )
    }

    public func analyzeRepository(_ commits: [Commit]) -> RepositoryAnalysis {
        let intents = analyzeIntents(commits)
        let volatileFiles = fileHealthTracker.findVolatileFiles(commits)
        let contributors = extractContributors(commits)
        let trends = calculateTrends(commits)

        return RepositoryAnalysis(
            totalCommits: commits.count,
            intents: intents,
            volatileFiles: volatileFiles,
            contributors: contributors,
            trends: trends
        )
    }

    private func calculateSentiment(_ message: String) -> Double {
        let positive = ["fix", "improve", "optimize", "great", "excellent", "better", "success"]
        let negative = ["bug", "issue", "broken", "fail", "error", "bad", "revert"]

        let lowerMessage = message.lowercased()
        let positivCount = positive.filter { lowerMessage.contains($0) }.count
        let negativeCount = negative.filter { lowerMessage.contains($0) }.count

        if positivCount == 0 && negativeCount == 0 {
            return 0.0
        }

        return Double(positivCount - negativeCount) / Double(positivCount + negativeCount)
    }

    private func generateTags(for commit: Commit) -> [String] {
        var tags: [String] = []

        if commit.message.lowercased().contains("breaking") {
            tags.append("breaking-change")
        }
        if commit.message.lowercased().contains("wip") {
            tags.append("wip")
        }
        if commit.fileChanges.count > 20 {
            tags.append("large-change")
        }
        if commit.fileChanges.isEmpty {
            tags.append("empty-commit")
        }

        return tags
    }

    private func analyzeIntents(_ commits: [Commit]) -> [CommitAnalysis.CommitIntent: Int] {
        var intents: [CommitAnalysis.CommitIntent: Int] = [:]

        for commit in commits {
            let intent = intentClassifier.classify(commit.message)
            intents[intent, default: 0] += 1
        }

        return intents
    }

    private func extractContributors(_ commits: [Commit]) -> [String] {
        var contributors: Set<String> = []
        for commit in commits {
            contributors.insert(commit.author)
        }
        return Array(contributors).sorted()
    }

    private func calculateTrends(_ commits: [Commit]) -> RepositoryTrends {
        guard !commits.isEmpty else {
            return RepositoryTrends(commitsPerWeek: 0, averageCommitSize: 0, activityTimeline: [:])
        }

        let commitsPerWeek = Double(commits.count) / 4
        let averageCommitSize = commits.map { $0.fileChanges.count }.reduce(0, +) / max(commits.count, 1)

        var activityTimeline: [String: Int] = [:]
        for commit in commits {
            let week = Calendar.current.dateComponents([.weekOfYear, .year], from: commit.timestamp)
            let key = "\(week.year ?? 0)-W\(week.weekOfYear ?? 0)"
            activityTimeline[key, default: 0] += 1
        }

        return RepositoryTrends(
            commitsPerWeek: commitsPerWeek,
            averageCommitSize: averageCommitSize,
            activityTimeline: activityTimeline
        )
    }
}

public struct RepositoryAnalysis: Codable {
    public let totalCommits: Int
    public let intents: [CommitAnalysis.CommitIntent: Int]
    public let volatileFiles: [String]
    public let contributors: [String]
    public let trends: RepositoryTrends

    public init(
        totalCommits: Int,
        intents: [CommitAnalysis.CommitIntent: Int],
        volatileFiles: [String],
        contributors: [String],
        trends: RepositoryTrends
    ) {
        self.totalCommits = totalCommits
        self.intents = intents
        self.volatileFiles = volatileFiles
        self.contributors = contributors
        self.trends = trends
    }
}

public struct RepositoryTrends: Codable {
    public let commitsPerWeek: Double
    public let averageCommitSize: Int
    public let activityTimeline: [String: Int]

    public init(commitsPerWeek: Double, averageCommitSize: Int, activityTimeline: [String: Int]) {
        self.commitsPerWeek = commitsPerWeek
        self.averageCommitSize = averageCommitSize
        self.activityTimeline = activityTimeline
    }
}
