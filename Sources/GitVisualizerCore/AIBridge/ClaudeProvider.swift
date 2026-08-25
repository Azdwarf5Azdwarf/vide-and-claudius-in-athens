import Foundation

public class ClaudeProvider: AIProvider {
    public let name = "Claude"
    private let apiKey: String?
    private let model: String = "claude-3-5-sonnet-20241022"
    private let baseURL = "https://api.anthropic.com/v1"

    public var isConfigured: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    public init(apiKey: String?) {
        self.apiKey = apiKey
    }

    public func summarizeChanges(in commit: Commit) async throws -> String {
        guard isConfigured else { return "Claude API not configured" }

        let prompt = """
        Summarize the following git commit in 1-2 sentences:

        Message: \(commit.message)
        Files changed: \(commit.fileChanges.count)
        Lines added: \(commit.linesAdded)
        Lines deleted: \(commit.linesDeleted)
        """

        return try await callClaudeAPI(prompt: prompt)
    }

    public func generateCommitMessage(for changes: [FileChange]) async throws -> String {
        guard isConfigured else { return "" }

        let fileList = changes.map { "\($0.path) (\($0.status.rawValue))" }.joined(separator: "\n")
        let prompt = """
        Generate a concise, conventional commit message for these changes:

        \(fileList)

        Format: type(scope): description
        """

        return try await callClaudeAPI(prompt: prompt)
    }

    public func analyzeCodeHealth(in commits: [Commit]) async throws -> CodeHealthAnalysis {
        guard isConfigured else {
            return CodeHealthAnalysis(score: 0.0)
        }

        let commitCount = commits.count
        let fileChangesPerCommit = commits.map { $0.fileChanges.count }.reduce(0, +) / max(commits.count, 1)
        let avgCommitSize = commits.map { $0.linesAdded + $0.linesDeleted }.reduce(0, +) / max(commits.count, 1)

        let prompt = """
        Analyze the code health based on these metrics:
        - Total commits: \(commitCount)
        - Average files per commit: \(fileChangesPerCommit)
        - Average lines changed: \(avgCommitSize)

        Provide a score (0-1), findings, and recommendations.
        """

        let response = try await callClaudeAPI(prompt: prompt)

        return CodeHealthAnalysis(
            score: Double(min(max(commitCount, 1) / 100, 1)),
            findings: ["Analysis based on commit history"],
            recommendations: ["Continue monitoring code quality"]
        )
    }

    public func suggestWorkflow(for repository: Repository) async throws -> WorkflowSuggestion {
        guard isConfigured else {
            return WorkflowSuggestion(
                recommendation: "Unable to connect",
                rationale: "Claude API not configured"
            )
        }

        let branchCount = repository.branches.count
        let commitCount = repository.commits.count

        let prompt = """
        Based on this repository profile:
        - Branches: \(branchCount)
        - Commits: \(commitCount)
        - Current branch: \(repository.currentBranch?.name ?? "unknown")

        Suggest the best git workflow strategy.
        """

        let response = try await callClaudeAPI(prompt: prompt)

        return WorkflowSuggestion(
            recommendation: response,
            rationale: "Based on repository structure analysis"
        )
    }

    private func callClaudeAPI(prompt: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw ClaudeError.notConfigured
        }

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ClaudeError.apiError("API request failed")
        }

        if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = jsonResponse["content"] as? [[String: Any]],
           let firstContent = content.first,
           let text = firstContent["text"] as? String {
            return text
        }

        throw ClaudeError.invalidResponse
    }

    public enum ClaudeError: LocalizedError {
        case notConfigured
        case apiError(String)
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Claude API key not configured"
            case .apiError(let message):
                return message
            case .invalidResponse:
                return "Invalid API response"
            }
        }
    }
}
