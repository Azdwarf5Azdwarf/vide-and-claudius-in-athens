import Foundation

public protocol AIProvider {
    var name: String { get }
    var isConfigured: Bool { get }

    func summarizeChanges(in commit: Commit) async throws -> String
    func generateCommitMessage(for changes: [FileChange]) async throws -> String
    func analyzeCodeHealth(in commits: [Commit]) async throws -> CodeHealthAnalysis
    func suggestWorkflow(for repository: Repository) async throws -> WorkflowSuggestion
}

public struct CodeHealthAnalysis: Codable {
    public let score: Double
    public let findings: [String]
    public let recommendations: [String]

    public init(score: Double, findings: [String] = [], recommendations: [String] = []) {
        self.score = score
        self.findings = findings
        self.recommendations = recommendations
    }
}

public struct WorkflowSuggestion: Codable {
    public let recommendation: String
    public let rationale: String
    public let benefits: [String]

    public init(recommendation: String, rationale: String, benefits: [String] = []) {
        self.recommendation = recommendation
        self.rationale = rationale
        self.benefits = benefits
    }
}

public class MockAIProvider: AIProvider {
    public let name = "Mock"
    public let isConfigured = true

    public func summarizeChanges(in commit: Commit) async throws -> String {
        "Mock summary: \(commit.summary)"
    }

    public func generateCommitMessage(for changes: [FileChange]) async throws -> String {
        let files = changes.map { $0.path }.joined(separator: ", ")
        return "feat: Update \(files)"
    }

    public func analyzeCodeHealth(in commits: [Commit]) async throws -> CodeHealthAnalysis {
        CodeHealthAnalysis(
            score: 0.75,
            findings: ["Mock finding"],
            recommendations: ["Mock recommendation"]
        )
    }

    public func suggestWorkflow(for repository: Repository) async throws -> WorkflowSuggestion {
        WorkflowSuggestion(
            recommendation: "Use rebase workflow",
            rationale: "Keeps history clean",
            benefits: ["Linear history", "Easier bisect"]
        )
    }
}
